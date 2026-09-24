:hide-toc:

.. _maglo_qemu_home:

.. raw:: html

   <div class="qemu-hero">
     <h1>maglo.qemu</h1>
     <p class="qemu-hero-tagline">
       QEMU/KVM hosts and virtual machines on Enterprise Linux, driven by
       Ansible and systemd &mdash; no libvirtd, no XML, no virsh.
     </p>
     <div class="qemu-hero-badges">
       <span>Libvirt-free</span>
       <span>systemd-native</span>
       <span>UEFI &amp; Secure Boot</span>
       <span>TPM 2.0</span>
       <span>cloud-init</span>
       <span>console service</span>
     </div>
     <div class="qemu-install">ansible-galaxy collection install maglo.qemu</div>
     <div class="qemu-hero-actions">
       <a class="qemu-btn-primary" href="collection/docsite/guide_installation.html">Get started</a>
       <a class="qemu-btn-secondary" href="collection/vms_role.html">Role reference</a>
       <a class="qemu-btn-secondary" href="https://github.com/maglo/ansible-collection-qemu">GitHub</a>
     </div>
   </div>

A hypervisor without the stack
------------------------------

This collection is for developers who want repeatable, idempotent QEMU/KVM
virtual machines on an Enterprise Linux box — and nothing more than that. Each
VM is one ``qemu-system-*`` process, described in a playbook and supervised by
a systemd template unit. There is no management daemon to keep alive, no XML
to hand-edit and no second source of truth on the host.

.. grid:: 1 2 2 2
   :gutter: 3

   .. grid-item-card:: :octicon:`server` Libvirt-free
      :class-card: sd-shadow-none

      VMs are driven directly by ``qemu-system-*``. Nothing to install beyond
      QEMU and ``swtpm``.

   .. grid-item-card:: :octicon:`gear` systemd-native
      :class-card: sd-shadow-none

      A VM is a ``qemu-vm@<name>.service`` instance, so ``systemctl`` and
      ``journalctl`` work the way your operators already expect.

   .. grid-item-card:: :octicon:`shield-check` Firmware you can trust
      :class-card: sd-shadow-none

      UEFI by default, per-VM NVRAM, Secure Boot with pre-enrolled keys, an
      emulated TPM 2.0, and an offline check of the variable store.

   .. grid-item-card:: :octicon:`checklist` Fails before it writes
      :class-card: sd-shadow-none

      The ``vms`` role validates the whole VM list first, so a run that cannot
      finish leaves the host exactly as it was.

Quick start
-----------

Point the two roles at a host and describe the VMs you want:

.. code-block:: yaml

   - hosts: hypervisors
     become: true
     roles:
       - maglo.qemu.host
       - role: maglo.qemu.vms
         vars:
           vms_list:
             - name: web01
               disk_size: 40G
               memory: 4G
               cpus: 4
               state: started
             - name: db01
               disk_size: 100G
               disk_bus: virtio-scsi
               memory: 8G
               cpus: 8
               state: started

The ``host`` role installs the QEMU/KVM packages and the ``qemu-vm@.service``
and ``swtpm@.service`` template units. The ``vms`` role
creates each disk image, writes ``/etc/qemu/vms/<name>.conf`` and manages the
``qemu-vm@<name>.service`` instance of every VM.

.. code-block:: console

   $ systemctl status qemu-vm@web01
   $ journalctl -u qemu-vm@web01

Read on in :ref:`ansible_collections.maglo.qemu.docsite.guide_installation`.

Documentation
-------------

.. grid:: 1 2 2 3
   :gutter: 3

   .. grid-item-card:: Installation
      :link: collection/docsite/guide_installation
      :link-type: doc

      Requirements, EPEL, hardware virtualization and the supported platforms.

   .. grid-item-card:: Host setup
      :link: collection/docsite/guide_host
      :link-type: doc

      Prepare a hypervisor: packages, directories, systemd units, SELinux.

   .. grid-item-card:: VM management
      :link: collection/docsite/guide_vm_management
      :link-type: doc

      Create, start, restart and destroy VMs, and apply a config change.

   .. grid-item-card:: Feature guide
      :link: collection/docsite/guide_features
      :link-type: doc

      Disks, UEFI and Secure Boot, TPM, networking, consoles, cloud-init.

   .. grid-item-card:: Example playbooks
      :link: collection/docsite/guide_examples
      :link-type: doc

      Ready-to-run playbooks for the common shapes of a deployment.

   .. grid-item-card:: Role reference
      :link: collection/vms_role
      :link-type: doc

      Every variable of both roles, generated from the role argument specs.

Supported platforms
-------------------

.. list-table::
   :header-rows: 1
   :widths: 55 15 30

   * - Host platform
     - Version
     - Status
   * - Enterprise Linux (RHEL, Rocky, Alma, CentOS)
     - 10
     - Supported

**ansible-core:** 2.15 or newer. CI runs the sanity tests against
``stable-2.16`` and ``stable-2.17``.

This covers the *host* only. A VM may run any guest image, including an EL9
one — the guest OS is not the collection's concern.

.. toctree::
   :caption: Guides
   :maxdepth: 1
   :hidden:

   collection/docsite/guide_installation
   collection/docsite/guide_host
   collection/docsite/guide_vm_management
   collection/docsite/guide_features
   collection/docsite/guide_console_service
   collection/docsite/guide_examples

.. toctree::
   :caption: Reference
   :maxdepth: 1
   :hidden:

   host role <collection/host_role>
   vms role <collection/vms_role>

.. toctree::
   :caption: Project
   :maxdepth: 1
   :hidden:

   collection/docsite/guide_manual_testing
   Changelog <https://github.com/maglo/ansible-collection-qemu/blob/main/CHANGELOG.rst>
   Contributing <https://github.com/maglo/ansible-collection-qemu/blob/main/CONTRIBUTING.md>
   Source on GitHub <https://github.com/maglo/ansible-collection-qemu>
   Ansible Galaxy <https://galaxy.ansible.com/ui/repo/published/maglo/qemu/>
