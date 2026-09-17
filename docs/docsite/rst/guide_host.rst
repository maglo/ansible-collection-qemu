.. _ansible_collections.maglo.qemu.docsite.guide_host:

Host setup
==========

This guide walks through setting up a QEMU/KVM hypervisor host using the ``maglo.qemu.host`` role.

Prerequisites
-------------

- A target host running Enterprise Linux 10 (RHEL, Rocky, Alma, CentOS), with
  hardware virtualization enabled and the EPEL repository available
- ``ansible-core`` >= 2.15 on the control node, and the ``maglo.qemu``
  collection installed

:ref:`ansible_collections.maglo.qemu.docsite.guide_installation` covers all of
these, including how to check for KVM support and why the collection does not
enable EPEL itself.

Basic setup
-----------

The simplest playbook installs the QEMU/KVM packages and deploys the systemd template units that manage VMs:

.. code-block:: yaml

   - hosts: hypervisors
     roles:
       - maglo.qemu.host

The role then:

1. Installs the packages in ``host_packages``: ``qemu-kvm``, ``qemu-img``,
   ``swtpm``, ``swtpm-tools``, ``socat``, ``genisoimage`` and ``edk2-ovmf``.
2. Creates the VM configuration directory (``host_vm_config_dir``, default
   ``/etc/qemu/vms``).
3. Creates the VM image directory (``host_vm_image_dir``, default
   ``/var/lib/qemu/images``).
4. Deploys the ``qemu-vm@.service`` systemd template unit, which runs one VM
   per instance.
5. Deploys the ``swtpm@.service`` systemd template unit. The ``vms`` role
   starts one instance of it for each VM that sets ``tpm: true``, and it fails
   when this unit is missing.
6. Installs the ``novnc`` package and deploys the ``novnc@.service`` systemd
   template unit, when ``host_novnc_enabled`` is true.
7. Compiles and installs an SELinux policy module, when ``getenforce`` reports
   ``Enforcing``. The module lets ``qemu-vm@.service`` run
   ``/usr/libexec/qemu-kvm``. The role installs ``checkpolicy`` and
   ``policycoreutils`` to build it. The role skips this step when SELinux is
   permissive or disabled.

Customising packages
--------------------

``host_packages`` holds the list of packages the role installs. Override it to
add a package, and keep the default entries in the list:

.. code-block:: yaml

   - hosts: hypervisors
     roles:
       - role: maglo.qemu.host
         vars:
           host_packages:
             - qemu-kvm
             - qemu-img
             - swtpm
             - swtpm-tools
             - socat
             - genisoimage
             - edk2-ovmf
             - virt-install

.. warning::

   Dropping a default package breaks a feature of the ``vms`` role. Each
   package carries one:

   - ``qemu-kvm`` runs the VM, ``qemu-img`` creates its disk image.
   - ``edk2-ovmf`` ships the UEFI firmware files. ``vms_default_uefi`` is
     true, so every VM needs it unless you set ``uefi: false``.
   - ``swtpm`` and ``swtpm-tools`` run the emulated TPM of a VM with
     ``tpm: true``.
   - ``socat`` sends ``system_powerdown`` over the QMP socket of a VM. Without
     it, ``state: restarted`` and ``state: absent`` cannot shut the guest down
     cleanly.
   - ``genisoimage`` builds the cloud-init seed ISO of a VM that sets a
     ``cloud_init_*`` key.

Socket permissions
------------------

QEMU creates the serial and QMP sockets of a VM itself, at start, and never
chmods them. Their mode is ``0777`` minus the umask of the unit, and systemd
defaults that umask to ``0022``, which leaves every socket at ``0755``.

``0755`` is usable by the ``qemu`` user and by nothing else. Connecting to a
UNIX socket needs the *write* bit, so a ``0755`` socket refuses even an account
that is a member of ``host_service_group``:

.. code-block:: console

   $ sudo -u labview socat - UNIX-CONNECT:/var/lib/qemu/web01/serial.sock
   socat: E connect(...): Permission denied

``host_vm_umask`` is therefore ``0007``, which leaves the sockets at ``0770``.
A console service that runs under its own account in the ``qemu`` group can
attach to the serial line and drive the guest over QMP, and nothing outside
that group can reach either — narrower than the ``0755`` of earlier releases,
not wider.

.. code-block:: yaml

   - hosts: hypervisors
     roles:
       - role: maglo.qemu.host
         vars:
           host_vm_umask: "0022"   # the mode of releases before this one

Quote the value. An unquoted ``0022`` is the integer 18 in YAML, and the unit
needs the digits.

.. note::

   The mode is fixed when QEMU creates the socket, so a VM that is already
   running keeps the socket it started with. Restart the VMs with
   ``state: restarted`` in the ``vms`` role to pick the new mode up.

noVNC web console
-----------------

Set ``host_novnc_enabled`` to true to install the ``novnc`` package from EPEL
and deploy the ``novnc@.service`` systemd template unit:

.. code-block:: yaml

   - hosts: hypervisors
     roles:
       - role: maglo.qemu.host
         vars:
           host_novnc_enabled: true

The host role only prepares the unit. The ``vms`` role starts one
``novnc@<name>.service`` per VM that sets ``novnc_enabled: true``. See the
``maglo.qemu.host`` and ``maglo.qemu.vms`` role READMEs for the port
assignment and the console URL.

Customising directories
-----------------------

The VM configuration and image directories can be changed. The ``vms`` role
has its own variables for the same two paths, so change both roles together.
Otherwise the host role creates the new directories and the ``vms`` role
writes to the old ones:

.. code-block:: yaml

   - hosts: hypervisors
     roles:
       - role: maglo.qemu.host
         vars:
           host_vm_config_dir: /opt/qemu/config
           host_vm_image_dir: /opt/qemu/images
       - role: maglo.qemu.vms
         vars:
           vms_vm_config_dir: /opt/qemu/config
           vms_image_dir: /opt/qemu/images
           vms_list:
             - name: web01

The same rule applies to the swtpm state directory: ``host_swtpm_state_dir``
goes into the ``swtpm@.service`` unit, and ``vms_swtpm_state_dir`` tells the
``vms`` role where that state lives. Set both to the same path.

Next steps
----------

- :ref:`ansible_collections.maglo.qemu.docsite.guide_vm_management` — create and manage VMs
- :ref:`ansible_collections.maglo.qemu.docsite.guide_features` — every VM feature and the variables behind it
