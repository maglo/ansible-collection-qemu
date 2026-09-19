.. _ansible_collections.maglo.qemu.docsite.guide_features:

Feature guide
=============

What a VM of this collection can do, one feature per section. Each section
names the variables involved; the ``maglo.qemu.vms`` role reference documents
every one of them with its type and default, and
``ansible-doc -t role maglo.qemu.vms`` prints the same list on the command
line.

Disk images
-----------

- **Blank disks** — qcow2 (the default) or raw, at ``disk_size``.
- **Cloud images** — set ``disk_image_url`` to a QCOW2 image. The role
  downloads it once into ``vms_image_cache_dir`` and gives each VM a
  copy-on-write overlay on top of it, so ten VMs off one base image cost one
  download and one copy of the base.
- **Checksums** — ``disk_image_checksum`` takes a ``sha256:...`` value and the
  role compares it against the downloaded file. ``vms_verify_checksums: false``
  skips the comparison for every VM.
- **Idempotent** — an image that exists is never recreated, so a converge
  never destroys guest data.
- **Disk bus** — ``virtio-blk`` by default. ``disk_bus: virtio-scsi`` attaches
  the system disk through a ``virtio-scsi-pci`` controller, which is the bus
  most production images expect. The cloud-init seed ISO stays on virtio-blk.

.. code-block:: yaml

   vms_list:
     - name: web01
       disk_image_url: https://cloud.centos.org/centos/10-stream/x86_64/images/CentOS-Stream-GenericCloud-10-latest.x86_64.qcow2
       disk_image_checksum: sha256:0123456789abcdef...
       disk_size: 40G
       disk_bus: virtio-scsi

UEFI firmware and Secure Boot
-----------------------------

UEFI boot with OVMF firmware is on by default (``vms_default_uefi``), and each
VM gets its own writable NVRAM copy of ``OVMF_VARS.fd``.

- **Secure Boot** — ``secure_boot: true`` uses ``OVMF_CODE.secboot.fd`` with
  pre-enrolled Microsoft/OVMF keys and SMM.
- **Custom variable store** — ``nvram_template: /path/to/OVMF_VARS.fd`` gives
  one VM a store of your own, for example one that holds your PK, KEK and db.
  The other VMs on the host keep the global template.
- **NVRAM reset** — raise ``nvram_generation`` to write the NVRAM file from the
  template again. The role also rewrites it when ``secure_boot``, the template
  path or the content of the template changes, and never otherwise — so the
  UEFI boot entries a guest writes survive a converge.
- **Verification** — ``vms_nvram_verify: true`` asserts that the store of each
  Secure Boot VM holds a PK, a KEK and a db, and that Secure Boot is enabled.
  Add ``nvram_expected_db_cn`` to a VM to also assert a certificate in the db.
  The check needs ``virt-fw-vars`` from ``python3-virt-firmware``; the role
  reports a skip when the command is absent.

.. note::

   A store without a PK is in Setup Mode, and a VM with such a store boots an
   unsigned artifact without a complaint. ``SecureBoot`` and ``SetupMode`` are
   volatile variables that the firmware creates at boot, so an offline check
   cannot read them — an enrolled PK is the offline equivalent of
   ``SetupMode=0``.

Set ``uefi: false`` on a VM that should boot the legacy BIOS path instead.

TPM 2.0 emulation
-----------------

``tpm: true`` starts a software TPM for the VM via `swtpm
<https://github.com/stefanberger/swtpm>`_, managed as
``swtpm@<name>.service`` with per-VM state under ``/var/lib/swtpm/``. A
systemd dependency orders it before the VM, so the TPM is ready when the
firmware looks for it.

TPM state is persistent: sealed key slots, persistent handles and the PCR
history survive a rebuild of the VM. Raise ``tpm_generation`` to clear
``/var/lib/swtpm/<name>``; the role stops the VM and swtpm first and starts
them again afterwards. Only an *increase* resets — lowering the value, or
removing the key, leaves the TPM alone.

SMBIOS type 11 OEM strings
--------------------------

``smbios_oem_strings`` passes a list of SMBIOS type 11 OEM strings to a VM.
``systemd-stub`` reads these, so they extend the command line of a unified
kernel image without a rebuild and a new signature:

.. code-block:: yaml

   vms_list:
     - name: debug01
       smbios_oem_strings:
         - "io.systemd.stub.kernel-cmdline-extra=rd.debug systemd.log_level=debug"

The role writes each string to its own file and passes it as
``-smbios type=11,path=...``, so a string may contain spaces. The files are
mode ``0600`` and owned by the QEMU user: an OEM string can hold a secret, and
the ``path=`` form keeps it out of the command line, where ``ps`` would show it
to every user on the host. Removing the key from ``vms_list`` removes the
files.

.. warning::

   A change takes effect at the **next boot** of the VM. The firmware reads the
   strings once, and the role does not restart a running VM, so use
   ``state: restarted`` to pick up a new string.

``systemd-stub`` ignores these strings under confidential computing, and they
measure into PCR 12. OpenStack Nova has no equivalent knob; this is a
convenience of this collection only.

Networking
----------

- **User mode** (``net_mode: user``, the default) gives the guest outbound NAT
  through SLIRP and needs nothing on the host.
- **Bridge mode** (``net_mode: bridge``) attaches the guest to a host bridge —
  ``br0`` unless ``net_bridge`` says otherwise — through
  ``qemu-bridge-helper``. The bridge itself is yours to create.
- **MAC addresses** are derived from the VM name under the QEMU OUI
  ``52:54:00``, so they are stable across a rebuild. ``mac_address`` overrides
  one. The role fails the run when two names collide.

Consoles
--------

Every VM gets two consoles and one control channel: a serial console on a UNIX
socket, a VNC console on a TCP port, and a QMP socket.

The serial console is at ``/var/lib/qemu/<name>/serial.sock``, and
``serial_socket`` moves it. Beside it sits the QMP socket at
``/var/lib/qemu/<name>/qmp.sock``, which ``qmp_socket`` moves. QMP is the
machine readable control channel: it carries typed commands such as
``send-key`` and ``screendump``, with structured errors, and the role sends
``system_powerdown`` over it on a graceful shutdown.

A VM has no ``-monitor`` socket. QMP carries every human monitor command, so
nothing is lost:

.. code-block:: json

   {"execute": "human-monitor-command", "arguments": {"command-line": "info block"}}

QEMU creates every socket at start and does not wait for a client, so a VM
boots with nothing attached. Read the guest console with any socket client:

.. code-block:: console

   $ socat - UNIX-CONNECT:/var/lib/qemu/web01/serial.sock

Both sockets belong to the QEMU service user and group, at mode ``0770``:
``host_vm_umask`` in the ``host`` role sets it, so a console service running
under its own account in that group can attach, and nothing else can. See
:ref:`ansible_collections.maglo.qemu.docsite.guide_host`.

The role creates ``/var/lib/qemu/<name>/`` only. A socket path anywhere else
needs a directory that you create. No path may hold a space, because systemd
splits ``$QEMU_ARGS`` at each space. The role fails the run when two VMs would
open one socket.

.. note::

   The guest serial console is no longer in the journal. A VM starts with
   ``-display none`` and an explicit ``-serial``, so the console goes to its
   socket instead of stdout. The unit journal of a VM now holds the stderr of
   QEMU and the start and stop lines of systemd.

Every VM gets a VNC console. The display number is the MD5 hash of the VM name
modulo 100, which keeps it stable across a rebuild; ``vnc: N`` overrides it and
the port is ``5900 + N``. The role fails the run when two names collide.

``vnc_address`` sets the address that the console binds. It defaults to
``127.0.0.1``, which reaches the console through the host only. An
empty value binds every interface, on both ``0.0.0.0`` and ``::``. Wrap an
IPv6 address in brackets, for example ``[::1]``.

.. warning::

   VNC is unauthenticated. An empty ``vnc_address`` puts the raw RFB port of a
   VM in reach of anything that can route to the host, with no password in the
   way. Prefer the default, and reach the console through a console service or
   an SSH tunnel.

For a browser console, deploy the ``maglo.qemu.labview`` role. It serves the
framebuffer, serial line and control channel of every machine behind one
port, reading the inventory the ``vms`` role writes — see
:ref:`ansible_collections.maglo.qemu.docsite.guide_console_service`.

Console service inventory
-------------------------

A console service such as `labview <https://github.com/maglo/qemu-lab-manager>`_
reads a directory of per-machine YAML files and serves every machine's
framebuffer, serial line and details behind one port. The ``vms`` role is the
only thing that knows a VM's VNC display, its socket paths and its unit name,
so it writes those files itself rather than leaving a consumer to derive the
same facts a second time and drift from them.

``vms_labview_inventory_dir`` turns it on:

.. code-block:: yaml

   - role: maglo.qemu.vms
     vars:
       vms_labview_inventory_dir: /etc/labview/inventory.d
       vms_list:
         - name: web01
           disk_size: 40G
           vnc_address: 127.0.0.1
           state: started

The role creates the directory and writes one file per VM, named after the VM:

.. code-block:: yaml

   # /etc/labview/inventory.d/web01.yml
   name: "web01"
   host: "hypervisor01"
   vnc: "127.0.0.1:5986"
   serial: "/var/lib/qemu/web01/serial.sock"
   control: "/var/lib/qemu/web01/qmp.sock"
   unit: "qemu-vm@web01.service"

The console service takes the machine id from the file name, so ``name`` is the
display name only. ``host`` is ``inventory_hostname``, the name the playbook
knows the hypervisor by. ``vnc`` is the bind address with port
``5900 + <display>``, and it names ``127.0.0.1`` when ``vnc_address`` is empty:
an empty address binds every interface, and the console service sits on the
hypervisor beside QEMU. ``control`` is the QMP socket — a VM has no
``-monitor`` socket, so no monitor path belongs in the file. ``unit`` is what
lets the service power the machine through systemd. Every value is quoted, so
that a bracketed IPv6 address such as ``vnc: "[::1]:5907"`` stays a string
instead of opening a YAML flow sequence.

One VM is one file, so there is no shared file for two runs to serialise on,
and ``state: absent`` removes an entry along with the rest of the VM.

.. note::

   A teardown run has to set ``vms_labview_inventory_dir`` too. The removal
   cannot know the directory otherwise, so a ``state: absent`` run that leaves
   the variable unset destroys the VM and leaves its inventory file behind.

With the variable unset the role writes nothing at all, which is how it behaved
before the feature existed.

USB disks and ISOs
------------------

``usb_disk_image`` attaches one pre-provisioned image (``.iso``, ``.raw``,
``.img`` or ``.qcow2``) to the VM behind an emulated USB 3.0 XHCI controller.
``usb_boot_priority: true`` boots it first, which is how you drive an
attended installation. The image must already exist on the host — the role
does not create it, and fails the run when the path is missing.

Cloud-init
----------

``cloud_init_user_data`` turns on generation of a NoCloud seed ISO, which the
role writes to ``<vms_image_dir>/<name>-seed.iso`` and attaches as a virtio
CD-ROM. ``cloud_init_meta_data`` and ``cloud_init_network_config`` fill in the
other two files; ``meta-data`` is generated from the VM name when it is
omitted.

.. code-block:: yaml

   vms_list:
     - name: web01
       disk_image_url: https://example.com/centos-10-cloud.qcow2
       cloud_init_user_data: |
         #cloud-config
         users:
           - name: admin
             sudo: ALL=(ALL) NOPASSWD:ALL
             ssh_authorized_keys:
               - ssh-ed25519 AAAA... admin@workstation

This needs ``genisoimage`` on the host, which the ``host`` role installs, and
a guest image with ``cloud-init`` in it.

VM lifecycle
------------

.. list-table::
   :header-rows: 1
   :widths: 18 82

   * - ``state``
     - Behaviour
   * - ``present``
     - Write the configuration; leave the ``qemu-vm@`` unit alone. The swtpm
       instance of the VM is still started.
   * - ``started``
     - Enable and start the unit, then check that it is active.
   * - ``stopped``
     - Enable the unit but stop it.
   * - ``restarted``
     - Shut the guest down, then start the VM again.
   * - ``absent``
     - Destroy the VM and every artifact of it. Needs ``force_destroy: true``.

A graceful shutdown sends ``system_powerdown`` over the QMP socket, which the
guest sees as an ACPI power button press, and waits up to ``shutdown_timeout``
seconds (default 120). QMP answers each command, so the role waits only when
QEMU accepted it. The role then stops the unit either way, because a guest may
ignore the request.

A configuration change is written to the ``.conf`` file but does not restart a
running VM. Use ``state: restarted`` to apply it.

SELinux
-------

The VM unit runs as ``init_t``, which may not execute
``/usr/libexec/qemu-kvm`` or ``/usr/bin/swtpm``. When ``getenforce`` reports
``Enforcing``, the ``host`` role compiles and loads a small policy module that
allows exactly that. The step is skipped when SELinux is permissive or
disabled.

Input validation
----------------

The ``vms`` role checks the whole list before it writes anything to the host,
so a run that cannot finish leaves the host as it was. It fails on a duplicate
VM name, a name that cannot be a systemd instance name, ``secure_boot``
without ``uefi``, a ``disk_image_url`` with a non-qcow2 ``disk_format``, two
VMs that would share a VNC display, a MAC address, a serial
socket or a QMP socket, and ``state: absent`` without ``force_destroy``.

See also
--------

- :ref:`ansible_collections.maglo.qemu.docsite.guide_vm_management` — the day-to-day workflow
- :ref:`ansible_collections.maglo.qemu.docsite.guide_examples` — ready-to-run playbooks
