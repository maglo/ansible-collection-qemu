.. _ansible_collections.maglo.qemu.docsite.guide_examples:

Example playbooks
=================

The repository ships runnable playbooks under `playbooks/
<https://github.com/maglo/ansible-collection-qemu/tree/main/playbooks/>`_.
Copy one, point it at your own inventory and adjust ``vms_list``.

.. list-table::
   :header-rows: 1
   :widths: 32 68

   * - Playbook
     - What it does
   * - `basic_host.yml <https://github.com/maglo/ansible-collection-qemu/blob/main/playbooks/basic_host.yml>`_
     - Minimal host setup: packages and the systemd template units.
   * - `vms.yml <https://github.com/maglo/ansible-collection-qemu/blob/main/playbooks/vms.yml>`_
     - Host setup plus a couple of VMs.
   * - `labview.yml <https://github.com/maglo/ansible-collection-qemu/blob/main/playbooks/labview.yml>`_
     - Host and VMs with every console served by one console service.

`inventory.example.yml
<https://github.com/maglo/ansible-collection-qemu/blob/main/playbooks/inventory.example.yml>`_
shows the inventory groups the playbooks expect:

.. code-block:: yaml

   all:
     children:
       qemu_hosts:
         hosts:
           kvm1.example.com:
           kvm2.example.com:

.. code-block:: bash

   ansible-playbook -i inventory.yml vms.yml

A host and two VMs
------------------

.. code-block:: yaml

   - name: Set up a QEMU host and create VMs
     hosts: qemu_hosts
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
               disk_format: raw
               disk_bus: virtio-scsi
               memory: 8G
               cpus: 8
               state: started

A cloud image with cloud-init
-----------------------------

Two VMs share one downloaded base image; each gets a copy-on-write overlay and
its own seed ISO.

.. code-block:: yaml

   - name: Provision VMs from a cloud image
     hosts: qemu_hosts
     become: true
     roles:
       - maglo.qemu.host
       - role: maglo.qemu.vms
         vars:
           vms_list:
             - name: app01
               disk_image_url: &image https://example.com/centos-10-cloud.qcow2
               disk_image_checksum: &checksum sha256:0123456789abcdef...
               disk_size: 40G
               state: started
               cloud_init_user_data: |
                 #cloud-config
                 hostname: app01
                 users:
                   - name: admin
                     sudo: ALL=(ALL) NOPASSWD:ALL
                     ssh_authorized_keys:
                       - ssh-ed25519 AAAA... admin@workstation
             - name: app02
               disk_image_url: *image
               disk_image_checksum: *checksum
               disk_size: 40G
               state: started

A Secure Boot VM with a TPM
---------------------------

.. code-block:: yaml

   - name: Provision a VM that can measure its own boot
     hosts: qemu_hosts
     become: true
     roles:
       - maglo.qemu.host
       - role: maglo.qemu.vms
         vars:
           vms_nvram_verify: true
           vms_list:
             - name: secure01
               disk_size: 40G
               secure_boot: true
               tpm: true
               state: started

An attended installation from an ISO
------------------------------------

The ISO has to be on the host already; the role does not fetch it.

.. code-block:: yaml

   - name: Boot an installer ISO
     hosts: qemu_hosts
     become: true
     roles:
       - maglo.qemu.host
       - role: maglo.qemu.vms
         vars:
           vms_list:
             - name: installer
               disk_size: 40G
               usb_disk_image: /var/lib/qemu/images/installer.iso
               usb_boot_priority: true
               state: started

Tearing a VM down
-----------------

``state: absent`` destroys the VM and every artifact of it — disk image, UEFI
variable store, TPM state, seed ISO and systemd drop-ins — so it needs
``force_destroy: true`` on the same entry.

.. code-block:: yaml

   - name: Destroy a VM
     hosts: qemu_hosts
     become: true
     roles:
       - role: maglo.qemu.vms
         vars:
           vms_list:
             - name: web01
               state: absent
               force_destroy: true

Every console through one service
---------------------------------

``playbooks/labview.yml`` deploys the labview console service beside the VMs,
so every machine's framebuffer, serial line and control channel is reachable
behind one port, which is how a console reaches a machine.

.. code-block:: yaml

   - hosts: qemu_hosts
     become: true
     roles:
       - role: maglo.qemu.host

       - role: maglo.qemu.vms
         vars:
           vms_labview_inventory_dir: /etc/labview/inventory.d
           vms_list:
             - name: web01
               disk_size: 20G
               vnc_address: 127.0.0.1
               state: started

       - role: maglo.qemu.labview

The two directories must match: the ``vms`` role writes one inventory file per
VM, and the ``labview`` role serves what it finds there. labview listens on
loopback, so put a reverse proxy in front of it to terminate TLS and
authenticate — :ref:`ansible_collections.maglo.qemu.docsite.guide_console_service`
states what any proxy has to do.

See also
--------

- :ref:`ansible_collections.maglo.qemu.docsite.guide_features` — what each key does
- :ref:`ansible_collections.maglo.qemu.docsite.guide_vm_management` — the day-to-day workflow
