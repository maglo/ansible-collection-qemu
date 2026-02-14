.. _ansible_collections.basalt.qemu.docsite.guide_vm_management:

VM management
=============

This guide covers creating and managing QEMU/KVM virtual machines with the ``basalt.qemu`` collection.

Creating disk images
--------------------

Use the ``basalt.qemu.create_vm`` role to create disk images for your VMs:

.. code-block:: yaml

   - hosts: hypervisors
     roles:
       - basalt.qemu.qemu_host
       - role: basalt.qemu.create_vm
         vars:
           create_vm_vms:
             - name: web01
               disk_size: 40G
             - name: db01
               disk_size: 100G
               disk_format: raw
             - name: worker01

Each VM entry requires a ``name`` key. Optional keys:

- ``disk_size`` — overrides ``create_vm_default_disk_size`` (default ``20G``)
- ``disk_format`` — overrides ``create_vm_default_disk_format`` (default ``qcow2``)

The role is idempotent — existing images are not recreated.

Starting a VM
-------------

After the roles have run, each VM is controlled through the ``qemu-vm@.service`` systemd template unit.

First, create a configuration file for the VM. The instance name (after ``@``) corresponds to the ``.conf`` filename without the extension:

.. code-block:: bash

   cat > /etc/qemu/vms/web01.conf <<'EOF'
   QEMU_ARGS="-m 2048 -smp 2 -drive file=/var/lib/qemu/images/web01.qcow2,format=qcow2 -vnc :1"
   EOF

Then start and enable the VM:

.. code-block:: bash

   systemctl start qemu-vm@web01
   systemctl enable qemu-vm@web01

Managing VMs
------------

Standard ``systemctl`` commands apply:

.. code-block:: bash

   # Check status
   systemctl status qemu-vm@web01

   # Stop a VM (graceful, 120s timeout)
   systemctl stop qemu-vm@web01

   # Restart a VM
   systemctl restart qemu-vm@web01

   # Disable auto-start
   systemctl disable qemu-vm@web01
