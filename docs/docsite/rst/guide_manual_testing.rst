.. _ansible_collections.maglo.qemu.docsite.guide_manual_testing:

Manual Testing Guide (Release Candidate)
=========================================

This guide describes how to manually test the ``maglo.qemu`` collection before a release.
It is intended for maintainers and contributors validating a Release Candidate (RC).

Automated Molecule tests cover unit-level role behaviour; this guide focuses on
end-to-end testing on a real hypervisor host with actual QEMU/KVM acceleration.

Prerequisites
-------------

**Host requirements:**

- A bare-metal machine or a VM with nested virtualisation enabled (``/dev/kvm`` must exist)
- Enterprise Linux 9 or 10 (RHEL, Rocky, Alma, or CentOS Stream)
- At least 8 GB RAM and 50 GB free disk space
- Internet access (for downloading cloud images in URL provisioning tests)

**Workstation requirements:**

- Python >= 3.9
- Ansible >= 2.15
- Git

Setup
-----

1. **Install the collection from the build tarball:**

   .. code-block:: bash

      # Build from source
      cd /path/to/ansible-collection-qemu
      make build

      # Install the tarball
      ansible-galaxy collection install maglo-qemu-*.tar.gz --force

2. **Create an inventory file** (``inventory.yml``):

   .. code-block:: yaml

      all:
        hosts:
          hypervisor:
            ansible_host: <IP or hostname>
            ansible_user: root   # or a user with sudo

3. **Verify connectivity:**

   .. code-block:: bash

      ansible -i inventory.yml all -m ping

Test 1: Host role — basic setup
---------------------------------

Verify that the ``host`` role installs packages and deploys systemd template units.

**Playbook** (``test_host.yml``):

.. code-block:: yaml

   - hosts: all
     become: true
     roles:
       - maglo.qemu.host

**Run:**

.. code-block:: bash

   ansible-playbook -i inventory.yml test_host.yml

**Verify on the target host:**

.. code-block:: bash

   # Packages installed
   rpm -q qemu-kvm qemu-img swtpm swtpm-tools socat

   # Systemd units deployed
   systemctl cat qemu-vm@.service
   systemctl cat swtpm@.service

   # Directories created
   ls -la /etc/qemu/vms /var/lib/qemu/images

Test 2: Host role — noVNC
--------------------------

.. code-block:: yaml

   - hosts: all
     become: true
     roles:
       - role: maglo.qemu.host
         vars:
           host_novnc_enabled: true

**Verify:**

.. code-block:: bash

   rpm -q novnc
   systemctl cat novnc@.service

Test 3: VMs role — basic VM creation
--------------------------------------

**Playbook** (``test_vms_basic.yml``):

.. code-block:: yaml

   - hosts: all
     become: true
     roles:
       - maglo.qemu.host
       - role: maglo.qemu.vms
         vars:
           vms_list:
             - name: test-vm
               disk_size: 5G
               state: present

**Verify:**

.. code-block:: bash

   # Disk image exists with correct format and ownership
   ls -lh /var/lib/qemu/images/test-vm.qcow2
   qemu-img info /var/lib/qemu/images/test-vm.qcow2

   # Per-VM UEFI NVRAM file (UEFI is on by default)
   ls -lh /var/lib/qemu/images/test-vm_VARS.fd

   # Config file written
   cat /etc/qemu/vms/test-vm.conf

   # Idempotency: re-run should produce no changes
   ansible-playbook -i inventory.yml test_vms_basic.yml

Test 4: UEFI firmware
-----------------------

Verify UEFI boot is configured correctly (enabled by default, disable explicitly):

.. code-block:: yaml

   vms_list:
     - name: uefi-on
       disk_size: 5G
       uefi: true
       state: present
     - name: uefi-off
       disk_size: 5G
       uefi: false
       state: present

**Verify:**

.. code-block:: bash

   # UEFI VM: config contains pflash drives
   grep pflash /etc/qemu/vms/uefi-on.conf

   # Non-UEFI VM: no pflash in config
   grep -c pflash /etc/qemu/vms/uefi-off.conf || echo "OK: no pflash"

   # UEFI NVRAM present for uefi-on, absent for uefi-off
   ls /var/lib/qemu/images/uefi-on_VARS.fd
   ls /var/lib/qemu/images/uefi-off_VARS.fd 2>&1 | grep "No such file"

Test 5: UEFI Secure Boot
--------------------------

.. code-block:: yaml

   vms_list:
     - name: secboot-vm
       disk_size: 5G
       secure_boot: true
       state: present

**Verify:**

.. code-block:: bash

   # Config contains SMM and secure pflash args
   grep "smm=on" /etc/qemu/vms/secboot-vm.conf
   grep "OVMF_CODE.secboot.fd" /etc/qemu/vms/secboot-vm.conf
   grep "cfi.pflash01" /etc/qemu/vms/secboot-vm.conf

   # Secure boot marker exists
   ls /var/lib/qemu/images/secboot-vm_VARS.fd.secboot

Test 6: TPM 2.0 emulation
---------------------------

.. code-block:: yaml

   vms_list:
     - name: tpm-vm
       disk_size: 5G
       tpm: true
       state: present

**Verify:**

.. code-block:: bash

   # swtpm state directory created
   ls -la /var/lib/swtpm/tpm-vm/

   # swtpm service running
   systemctl status swtpm@tpm-vm

   # swtpm socket exists
   ls /var/lib/swtpm/tpm-vm/swtpm.sock

   # Systemd drop-in dependency
   cat /etc/systemd/system/qemu-vm@tpm-vm.service.d/tpm-dependency.conf

   # VM config contains TPM args
   grep chardev /etc/qemu/vms/tpm-vm.conf

Test 7: Networking
-------------------

**User-mode (default):**

.. code-block:: yaml

   - name: user-net-vm
     disk_size: 5G
     net_mode: user
     state: present

**Verify:**

.. code-block:: bash

   grep "nic user" /etc/qemu/vms/user-net-vm.conf

**Bridge mode** (requires a bridge ``br0`` to already exist on the host):

.. code-block:: yaml

   - name: bridge-vm
     disk_size: 5G
     net_mode: bridge
     net_bridge: br0
     state: present

**Verify:**

.. code-block:: bash

   # bridge.conf written
   cat /etc/qemu/bridge.conf   # should contain "allow br0"

   # VM config uses bridge netdev
   grep "netdev bridge" /etc/qemu/vms/bridge-vm.conf

Test 8: noVNC web console
--------------------------

.. code-block:: yaml

   - hosts: all
     become: true
     roles:
       - role: maglo.qemu.host
         vars:
           host_novnc_enabled: true
       - role: maglo.qemu.vms
         vars:
           vms_list:
             - name: novnc-vm
               disk_size: 5G
               novnc_enabled: true
               novnc_port: 6080
               vnc: 0
               state: present

**Verify:**

.. code-block:: bash

   # noVNC env file written
   cat /etc/qemu/vms/novnc-novnc-vm.conf

   # noVNC service enabled
   systemctl is-enabled novnc@novnc-vm

   # Connect browser to http://<host>:6080/vnc.html

Test 9: URL-based disk image provisioning
------------------------------------------

.. code-block:: yaml

   - name: cloud-vm
     disk_image_url: "https://repo.almalinux.org/almalinux/9/cloud/x86_64/images/AlmaLinux-9-GenericCloud-latest.x86_64.qcow2"
     disk_size: 10G
     state: present

**Verify:**

.. code-block:: bash

   # Cached base image
   ls -lh /var/lib/qemu/images/cache/AlmaLinux-9-GenericCloud-latest.x86_64.qcow2

   # Overlay image with backing file
   qemu-img info /var/lib/qemu/images/cloud-vm.qcow2
   # Should show: backing file: ...AlmaLinux-9-GenericCloud...

   # Re-run: cached image must NOT be re-downloaded
   ansible-playbook -i inventory.yml test_url.yml
   # Verify mtime of cache file is unchanged

Test 10: USB disk attachment
-----------------------------

.. code-block:: bash

   # Create a test ISO (or use a real installer)
   dd if=/dev/zero bs=1M count=10 | gzip > /tmp/test.iso
   # For a real test, use an actual ISO

.. code-block:: yaml

   - name: usb-vm
     disk_size: 5G
     usb_disk_image: /tmp/test.iso
     usb_boot_priority: true
     state: present

**Verify:**

.. code-block:: bash

   grep "qemu-xhci" /etc/qemu/vms/usb-vm.conf
   grep "usb-storage,drive=usb0,bootindex=1" /etc/qemu/vms/usb-vm.conf

Test 11: VM lifecycle
----------------------

Run all lifecycle states on a test VM (requires KVM to be available for ``started``/``stopped``/``restarted``):

.. code-block:: yaml

   vms_list:
     - name: lifecycle-vm
       disk_size: 2G
       state: started

**Start:**

.. code-block:: bash

   ansible-playbook -i inventory.yml test_lifecycle.yml
   systemctl status qemu-vm@lifecycle-vm   # should be active

**Stop:**

Change state to ``stopped`` and re-run. Verify ``systemctl status qemu-vm@lifecycle-vm`` shows inactive.

**Restart:**

Change state to ``restarted`` and re-run. Monitor system journal for graceful shutdown:

.. code-block:: bash

   journalctl -u qemu-vm@lifecycle-vm -f

**Destroy:**

.. code-block:: yaml

   vms_list:
     - name: lifecycle-vm
       state: absent
       force_destroy: true

**Verify destruction:**

.. code-block:: bash

   # All artifacts removed
   ls /var/lib/qemu/images/lifecycle-vm.qcow2 2>&1 | grep "No such file"
   ls /etc/qemu/vms/lifecycle-vm.conf 2>&1 | grep "No such file"
   systemctl status qemu-vm@lifecycle-vm   # should be unknown/not-found

**Safety check (no force_destroy):**

.. code-block:: yaml

   vms_list:
     - name: lifecycle-vm
       state: absent
       # force_destroy NOT set

Verify this **fails** with a clear error message.

Known RC limitations
---------------------

- Molecule tests run with ``state: present`` only (no live KVM in containers);
  lifecycle tests (``started``, ``restarted``, ``absent``) require a real KVM host
- noVNC serves unencrypted WebSocket by default; add a TLS reverse proxy for production
- Bridge mode requires the bridge device to already exist on the host; this collection
  does not create bridges
- Only QCOW2 format is supported for URL-based image provisioning; the role validates
  this and fails if a non-QCOW2 image is downloaded
- ``vms_verify_checksums`` is declared but currently unused (checksums are validated
  by Ansible's ``get_url`` module when ``disk_image_checksum`` is specified)
