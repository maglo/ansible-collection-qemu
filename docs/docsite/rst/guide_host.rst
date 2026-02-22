.. _ansible_collections.maglo.qemu.docsite.guide_host:

Getting started with host
=========================

This guide walks through setting up a QEMU/KVM hypervisor host using the ``maglo.qemu.host`` role.

Prerequisites
-------------

- A target host running Enterprise Linux 9 or 10 (RHEL, Rocky, Alma, CentOS)
- Ansible >= 2.15
- The ``maglo.qemu`` collection installed

Installation
------------

.. code-block:: bash

   ansible-galaxy collection install maglo.qemu

Basic setup
-----------

The simplest playbook installs QEMU/KVM packages and deploys a systemd template unit for managing VMs:

.. code-block:: yaml

   - hosts: hypervisors
     roles:
       - maglo.qemu.host

This will:

1. Install ``qemu-kvm``, ``qemu-img``, ``swtpm``, ``swtpm-tools``, and ``socat``.
2. Create the VM configuration directory (``/etc/qemu/vms``).
3. Create the VM image directory (``/var/lib/qemu/images``).
4. Deploy the ``qemu-vm@.service`` systemd template unit.

Customising packages
--------------------

Override ``host_packages`` to control which packages are installed:

.. code-block:: yaml

   - hosts: hypervisors
     roles:
       - role: maglo.qemu.host
         vars:
           host_packages:
             - qemu-kvm
             - qemu-img

Customising directories
-----------------------

The VM configuration and image directories can be changed:

.. code-block:: yaml

   - hosts: hypervisors
     roles:
       - role: maglo.qemu.host
         vars:
           host_vm_config_dir: /opt/qemu/config
           host_vm_image_dir: /opt/qemu/images

Next steps
----------

- :ref:`ansible_collections.maglo.qemu.docsite.guide_vm_management` — create and manage VMs
