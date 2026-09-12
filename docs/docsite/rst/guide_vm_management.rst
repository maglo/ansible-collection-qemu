.. _ansible_collections.maglo.qemu.docsite.guide_vm_management:

VM management
=============

This guide covers creating and managing QEMU/KVM virtual machines with the ``maglo.qemu`` collection.

Creating disk images
--------------------

Use the ``maglo.qemu.vms`` role to create disk images for your VMs:

.. code-block:: yaml

   - hosts: hypervisors
     roles:
       - maglo.qemu.host
       - role: maglo.qemu.vms
         vars:
           vms_list:
             - name: web01
               disk_size: 40G
             - name: db01
               disk_size: 100G
               disk_format: raw
             - name: worker01

Each VM entry needs a ``name`` key. The two keys used above are:

- ``disk_size`` — overrides ``vms_default_disk_size`` (default ``20G``)
- ``disk_format`` — overrides ``vms_default_disk_format`` (default ``qcow2``)

A VM entry takes about 30 more keys, one per VM setting. The
``maglo.qemu.vms`` role README lists them all with their defaults, and
``ansible-doc -t role maglo.qemu.vms`` prints the same list from the role
argument spec. See `See also`_ below for the ones this guide does not cover.

One key matters for the rest of this guide: ``state`` controls the
``qemu-vm@<name>.service`` unit of the VM. ``present`` is the default. It
writes the configuration and leaves the unit alone. ``started`` enables and
starts the unit, ``stopped`` enables and stops it, ``restarted`` shuts the
guest down and starts it again, and ``absent`` destroys the VM.

The role is idempotent — existing images are not recreated.

The role checks the whole list before it changes anything on the host. It
rejects a duplicate VM name, a name that systemd cannot use as an instance
name, ``secure_boot`` without ``uefi``, a ``disk_image_url`` with a disk
format other than qcow2, two VMs that would share a VNC display, a MAC
address or a noVNC port, and ``state: absent`` without ``force_destroy``. A
run that cannot finish therefore fails before it writes the first file.

TPM 2.0 emulation
------------------

VMs that need a Trusted Platform Module can use software TPM emulation via
`swtpm <https://github.com/stefanberger/swtpm>`_. Set ``tpm: true`` on a VM
entry to start a dedicated ``swtpm`` process:

.. code-block:: yaml

   - hosts: hypervisors
     roles:
       - maglo.qemu.host
       - role: maglo.qemu.vms
         vars:
           vms_list:
             - name: secure-vm
               disk_size: 40G
               tpm: true

The ``host`` role deploys the ``swtpm@.service`` systemd template unit. The
``vms`` role checks that the unit is there and fails when it is missing, so
run the ``host`` role first. For each TPM-enabled VM, the ``vms`` role:

1. Creates a per-VM state directory under ``vms_swtpm_state_dir``
   (default ``/var/lib/swtpm``).
2. Enables and starts ``swtpm@<vmname>.service``, which listens on a Unix
   socket at ``/var/lib/swtpm/<vmname>/swtpm.sock``.
3. Writes a systemd drop-in that makes ``qemu-vm@<vmname>.service`` require
   its swtpm instance.

The ``swtpm@.service`` unit is ordered ``Before=qemu-vm@%i.service``, so the
TPM is ready before the VM starts.

To enable TPM for all VMs by default, set ``vms_default_tpm: true``.
Individual VMs can still opt out with ``tpm: false``.

Starting a VM
-------------

Each VM runs as an instance of the ``qemu-vm@.service`` systemd template unit.
The instance name after ``@`` is the VM name.

Set ``state: started`` on the VM entry. The role writes
``/etc/qemu/vms/web01.conf``, then enables and starts ``qemu-vm@web01``:

.. code-block:: yaml

   - hosts: hypervisors
     roles:
       - maglo.qemu.host
       - role: maglo.qemu.vms
         vars:
           vms_list:
             - name: web01
               disk_size: 40G
               state: started

Check the result on the host:

.. code-block:: bash

   systemctl status qemu-vm@web01
   cat /etc/qemu/vms/web01.conf

The role writes that ``.conf`` file from a template and overwrites it on the
next run, so do not edit it by hand. The generated file holds every argument
the VM needs: the pflash drives of the UEFI firmware (``vms_default_uefi`` is
true), the ``-monitor`` socket that the shutdown path writes to, the VNC
display, the MAC address, and the disk, TPM, cloud-init, USB and SMBIOS
arguments of that VM.

.. note::

   A VM that the role does not manage can still use the unit. Write your own
   ``EnvironmentFile`` with a ``QEMU_ARGS`` line into ``vms_vm_config_dir``
   and start ``qemu-vm@<name>``. Such a file gets none of the arguments above;
   you write each one yourself, including the pflash drives of a UEFI VM and
   the ``-monitor`` socket that a graceful shutdown needs. Give the file a
   name that no entry in ``vms_list`` uses, or the next run of the role
   overwrites it.

Managing VMs
------------

Change ``state`` in ``vms_list`` and run the play again:

- ``state: stopped`` stops the unit and leaves it enabled. This is a plain
  ``systemctl stop``, so read the warning below: it does not ask the guest to
  power down.
- ``state: restarted`` writes ``system_powerdown`` to the QEMU monitor socket
  of the VM, waits up to ``shutdown_timeout`` seconds (default 120) for QEMU
  to exit, stops the unit either way, cycles the swtpm and noVNC instances of
  the VM, and starts the VM again.
- ``state: absent`` shuts the guest down the same way and then removes every
  artifact of the VM: the configuration file, the disk image, the UEFI
  variable store, the TPM state, the cloud-init seed ISO and the systemd
  drop-ins. It needs ``force_destroy: true`` on the same entry.

``systemctl`` remains useful for a look at a running VM:

.. code-block:: bash

   # Check status
   systemctl status qemu-vm@web01

   # Read the console output
   journalctl -u qemu-vm@web01

   # Disable auto-start
   systemctl disable qemu-vm@web01

.. warning::

   ``systemctl stop qemu-vm@web01`` is not a guest shutdown. The unit runs
   ``ExecStop=/bin/kill -SIGTERM $MAINPID`` with ``TimeoutStopSec=120``, so
   systemd sends SIGTERM to QEMU. QEMU exits without telling the guest, which
   leaves the guest file systems dirty. Use ``state: restarted`` or
   ``state: absent`` to power the guest down over the QEMU monitor first.

Applying a configuration change
-------------------------------

QEMU reads its arguments once, at start. The role writes a changed ``.conf``
file, but it does not restart a running VM, because a restart interrupts the
guest. The change therefore takes effect the next time the VM starts. Set
``state: restarted`` on the VM to apply it now.

See also
--------

This guide covers the basics. The ``maglo.qemu.vms`` role README documents the
rest:

- ``secure_boot``, ``nvram_template``, ``nvram_generation``,
  ``vms_nvram_verify`` and ``nvram_expected_db_cn`` — UEFI Secure Boot and the
  contents of the variable store.
- ``tpm_generation`` and ``vms_tpm_force_reset`` — resetting the emulated TPM.
- ``disk_bus`` — ``virtio-blk`` or ``virtio-scsi`` for the system disk.
- ``disk_image_url`` and ``disk_image_checksum`` — a VM built as an overlay on
  a downloaded cloud image.
- ``cloud_init_user_data``, ``cloud_init_meta_data`` and
  ``cloud_init_network_config`` — the cloud-init seed ISO.
- ``smbios_oem_strings`` — SMBIOS type 11 OEM strings, which ``systemd-stub``
  reads.
- ``novnc_enabled`` and ``novnc_port`` — the noVNC web console.
- ``cpu_model``, ``memory``, ``cpus``, ``vnc`` and ``mac_address`` — the
  emulated hardware.
- ``state`` and ``force_destroy`` — the VM lifecycle.

``ansible-doc -t role maglo.qemu.vms`` prints the same variables from the role
argument spec.

- :ref:`ansible_collections.maglo.qemu.docsite.guide_host` — set up the hypervisor host
- :ref:`ansible_collections.maglo.qemu.docsite.guide_manual_testing` — validate a release candidate
