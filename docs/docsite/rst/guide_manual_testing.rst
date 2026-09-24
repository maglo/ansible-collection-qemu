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
- Enterprise Linux 10 (RHEL, Rocky, Alma, or CentOS Stream)
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
   rpm -q qemu-kvm qemu-img swtpm swtpm-tools socat genisoimage edk2-ovmf

   # Systemd units deployed
   systemctl cat qemu-vm@.service
   systemctl cat swtpm@.service

   # Directories created
   ls -la /etc/qemu/vms /var/lib/qemu/images

Test 2: Host role — the console service
----------------------------------------

The ``host`` role installs and runs labview as part of preparing a hypervisor,
so a bare application of the role is the whole playbook.

.. code-block:: yaml

   - hosts: all
     become: true
     roles:
       - role: maglo.qemu.host

**Verify:**

.. code-block:: bash

   # The binary is the pinned release, and the service is up on loopback
   /usr/local/bin/labview -version
   systemctl is-active labview.service
   curl -sS -o /dev/null -w '%{http_code}\n' http://127.0.0.1:8080/

   # The account is its own, in the qemu group, and the polkit rule is in place
   id labview
   cat /etc/polkit-1/rules.d/50-labview-units.rules

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

   # NVRAM state file written next to the variable store
   cat /var/lib/qemu/images/secboot-vm_VARS.fd.state
   # Expected keys: fingerprint, secure_boot (true), template,
   # template_checksum (sha256 of the template) and generation (1)

   # The marker file of collection versions before 0.4.0 is removed on every run
   ls /var/lib/qemu/images/secboot-vm_VARS.fd.secboot 2>&1 | grep "No such file"

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

Test 8: the console of a VM in a browser
-----------------------------------------

.. code-block:: yaml

   - hosts: all
     become: true
     roles:
       - role: maglo.qemu.host
       - role: maglo.qemu.vms
         vars:
           vms_labview_inventory_dir: /etc/labview/inventory.d
           vms_list:
             - name: console-vm
               disk_size: 5G
               vnc: 0
               state: started

**Verify:**

.. code-block:: bash

   # The vms role wrote the machine, and the service serves it
   cat /etc/labview/inventory.d/console-vm.yml
   curl -sS http://127.0.0.1:8080/api/machines

   # Connect a browser through the reverse proxy in front of labview.
   # The framebuffer, the serial line and the details of console-vm are
   # all on one page.

Test 9: URL-based disk image provisioning
------------------------------------------

**Playbook** (``test_url.yml``):

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

   # Create a 10 MiB raw test image (or use a real installer ISO)
   truncate -s 10M /tmp/test.iso
   # The role checks the file name extension only, and vm.conf.j2 attaches
   # anything that is not .qcow2 as format=raw. Use a real ISO to test a boot.

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

Run all lifecycle states on a test VM (requires KVM to be available for ``started``/``stopped``/``restarted``).

**Playbook** (``test_lifecycle.yml``):

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

Test 12: Cloud-init seed ISO
-----------------------------

Verify that cloud-init configuration is written to a seed ISO and attached to the VM,
and that re-running the playbook with unchanged variables produces no changes.

**Playbook** (``test_cloud_init.yml``):

.. code-block:: yaml

   - hosts: all
     become: true
     roles:
       - maglo.qemu.host
       - role: maglo.qemu.vms
         vars:
           vms_list:
             - name: cloud-init-vm
               disk_size: 5G
               state: present
               cloud_init_user_data: |
                 #cloud-config
                 hostname: cloud-init-vm
                 users:
                   - name: ansible
                     sudo: ALL=(ALL) NOPASSWD:ALL
                     ssh_authorized_keys:
                       - ssh-ed25519 AAAA... your-key-here

**Run:**

.. code-block:: bash

   ansible-playbook -i inventory.yml test_cloud_init.yml

**Verify:**

.. code-block:: bash

   # Staging directory and source files written
   ls -la /var/lib/qemu/images/.cloud-init-staging/cloud-init-vm/
   cat /var/lib/qemu/images/.cloud-init-staging/cloud-init-vm/meta-data
   cat /var/lib/qemu/images/.cloud-init-staging/cloud-init-vm/user-data

   # Seed ISO created with CIDATA volume label
   ls -lh /var/lib/qemu/images/cloud-init-vm-seed.iso
   isoinfo -d -i /var/lib/qemu/images/cloud-init-vm-seed.iso | grep "Volume id"
   # Expected: Volume id: CIDATA

   # VM config references the seed ISO
   grep "seed.iso" /etc/qemu/vms/cloud-init-vm.conf

**Idempotency:**

.. code-block:: bash

   # Re-run with identical variables — must report zero changed tasks
   ansible-playbook -i inventory.yml test_cloud_init.yml

**Cleanup (state: absent removes ISO and staging directory):**

.. code-block:: yaml

   vms_list:
     - name: cloud-init-vm
       state: absent
       force_destroy: true

.. code-block:: bash

   ansible-playbook -i inventory.yml test_cloud_init.yml

   # Both the ISO and staging dir must be gone
   ls /var/lib/qemu/images/cloud-init-vm-seed.iso 2>&1 | grep "No such file"
   ls /var/lib/qemu/images/.cloud-init-staging/cloud-init-vm 2>&1 | grep "No such file"

Test 13: Disk bus
------------------

Verify that ``disk_bus`` selects how the system disk is attached.

**Playbook** (``test_disk_bus.yml``):

.. code-block:: yaml

   - hosts: all
     become: true
     roles:
       - maglo.qemu.host
       - role: maglo.qemu.vms
         vars:
           vms_list:
             - name: scsi-vm
               disk_size: 5G
               disk_bus: virtio-scsi
               state: present
             - name: blk-vm
               disk_size: 5G
               state: present

**Run:**

.. code-block:: bash

   ansible-playbook -i inventory.yml test_disk_bus.yml

**Verify:**

.. code-block:: bash

   # virtio-scsi: a controller plus an scsi-hd device
   grep "virtio-scsi-pci,id=scsi0" /etc/qemu/vms/scsi-vm.conf
   grep "scsi-hd,drive=disk0,bus=scsi0.0,bootindex=2" /etc/qemu/vms/scsi-vm.conf

   # virtio-blk (the default): a single -drive if=virtio
   grep "drive if=virtio" /etc/qemu/vms/blk-vm.conf

Test 14: SMBIOS type 11 OEM strings
------------------------------------

Verify that each OEM string is written to its own file and passed to QEMU by path.

**Playbook** (``test_smbios.yml``):

.. code-block:: yaml

   - hosts: all
     become: true
     roles:
       - maglo.qemu.host
       - role: maglo.qemu.vms
         vars:
           vms_list:
             - name: smbios-vm
               disk_size: 5G
               state: present
               smbios_oem_strings:
                 - "io.systemd.stub.kernel-cmdline-extra=rd.debug systemd.log_level=debug"
                 - "io.systemd.credential:mycred=abc"

**Run:**

.. code-block:: bash

   ansible-playbook -i inventory.yml test_smbios.yml

**Verify:**

.. code-block:: bash

   # One file per string, mode 0600, owned by the QEMU user
   ls -l /var/lib/qemu/smbios-vm/smbios/
   cat /var/lib/qemu/smbios-vm/smbios/00
   cat /var/lib/qemu/smbios-vm/smbios/01

   # The config passes the paths, so a string may contain spaces
   grep "smbios type=11,path=/var/lib/qemu/smbios-vm/smbios/00" /etc/qemu/vms/smbios-vm.conf

   # Remove the second string from the playbook and re-run:
   # the file of the deleted string must be gone
   ls /var/lib/qemu/smbios-vm/smbios/01 2>&1 | grep "No such file"

Test 15: NVRAM template and NVRAM reset
----------------------------------------

Verify that ``nvram_template`` selects the variable store template, and that
``nvram_generation`` and ``vms_nvram_force_reset`` rewrite the store.

**Playbook** (``test_nvram.yml``):

.. code-block:: yaml

   - hosts: all
     become: true
     roles:
       - maglo.qemu.host
       - role: maglo.qemu.vms
         vars:
           vms_list:
             - name: nvram-vm
               disk_size: 5G
               nvram_template: /usr/share/edk2/ovmf/OVMF_VARS.fd
               nvram_generation: 1
               state: present

**Run:**

.. code-block:: bash

   ansible-playbook -i inventory.yml test_nvram.yml

**Verify the template choice:**

.. code-block:: bash

   cat /var/lib/qemu/images/nvram-vm_VARS.fd.state
   # template: /usr/share/edk2/ovmf/OVMF_VARS.fd, generation: 1
   # template_checksum: sha256 of that file

**Verify the generation reset:**

.. code-block:: bash

   # Mark the current store, so a rewrite is visible
   printf 'X' | dd of=/var/lib/qemu/images/nvram-vm_VARS.fd bs=1 seek=0 conv=notrunc

Set ``nvram_generation: 2`` and re-run the playbook.

.. code-block:: bash

   # The store matches the template again, and the state file records generation 2
   cmp /var/lib/qemu/images/nvram-vm_VARS.fd /usr/share/edk2/ovmf/OVMF_VARS.fd
   grep generation /var/lib/qemu/images/nvram-vm_VARS.fd.state

**Verify the one-shot reset:**

.. code-block:: bash

   printf 'X' | dd of=/var/lib/qemu/images/nvram-vm_VARS.fd bs=1 seek=0 conv=notrunc
   ansible-playbook -i inventory.yml test_nvram.yml -e vms_nvram_force_reset=true
   cmp /var/lib/qemu/images/nvram-vm_VARS.fd /usr/share/edk2/ovmf/OVMF_VARS.fd

An unchanged re-run without either flag must report zero changed tasks and
must leave the store alone.

Test 16: Secure Boot variable store verification
-------------------------------------------------

Verify that ``vms_nvram_verify`` asserts the keys of a Secure Boot store, and
that ``nvram_expected_db_cn`` asserts a certificate in the db.

The check needs ``virt-fw-vars`` from the package ``python3-virt-firmware``:

.. code-block:: bash

   dnf install python3-virt-firmware

**Playbook** (``test_nvram_verify.yml``):

.. code-block:: yaml

   - hosts: all
     become: true
     roles:
       - maglo.qemu.host
       - role: maglo.qemu.vms
         vars:
           vms_nvram_verify: true
           vms_list:
             - name: secboot-vm
               disk_size: 5G
               secure_boot: true
               nvram_expected_db_cn: "Microsoft Corporation UEFI CA 2011"
               state: present

**Run:**

.. code-block:: bash

   ansible-playbook -i inventory.yml test_nvram_verify.yml

**Expected result:**

- The task ``Assert the Secure Boot keys of secboot-vm`` passes: the store
  holds PK, KEK and db, and ``SecureBootEnable`` is ON.
- The task ``Assert the expected db certificate of secboot-vm`` passes.
- Change ``nvram_expected_db_cn`` to a CN that the db does not hold. The run
  must fail and name the VM.
- Remove ``python3-virt-firmware`` and re-run. The role must print a skip
  message instead of failing.

Test 17: TPM reset
-------------------

Verify that ``tpm_generation`` and ``vms_tpm_force_reset`` clear the swtpm state.

**Playbook** (``test_tpm_reset.yml``):

.. code-block:: yaml

   - hosts: all
     become: true
     roles:
       - maglo.qemu.host
       - role: maglo.qemu.vms
         vars:
           vms_list:
             - name: tpm-vm
               disk_size: 5G
               tpm: true
               tpm_generation: 1
               state: present

**Run and mark the state:**

.. code-block:: bash

   ansible-playbook -i inventory.yml test_tpm_reset.yml
   cat /var/lib/swtpm/tpm-vm.state          # {"generation": 1}
   touch /var/lib/swtpm/tpm-vm/marker

Set ``tpm_generation: 2`` and re-run the playbook.

**Verify:**

.. code-block:: bash

   # The state directory was cleared and recreated
   ls /var/lib/swtpm/tpm-vm/marker 2>&1 | grep "No such file"
   cat /var/lib/swtpm/tpm-vm.state          # {"generation": 2}
   systemctl status swtpm@tpm-vm            # running again

**One-shot reset:**

.. code-block:: bash

   touch /var/lib/swtpm/tpm-vm/marker
   ansible-playbook -i inventory.yml test_tpm_reset.yml -e vms_tpm_force_reset=true
   ls /var/lib/swtpm/tpm-vm/marker 2>&1 | grep "No such file"

Test 18: CPU model
-------------------

Verify that ``cpu_model`` reaches the QEMU command line.

**Playbook** (``test_cpu_model.yml``):

.. code-block:: yaml

   - hosts: all
     become: true
     roles:
       - maglo.qemu.host
       - role: maglo.qemu.vms
         vars:
           vms_list:
             - name: cpu-vm
               disk_size: 5G
               cpu_model: Nehalem
               state: present
             - name: cpu-default-vm
               disk_size: 5G
               state: present

**Verify:**

.. code-block:: bash

   grep -- "-cpu Nehalem" /etc/qemu/vms/cpu-vm.conf

   # vms_default_cpu is `host`
   grep -- "-cpu host" /etc/qemu/vms/cpu-default-vm.conf

Test 19: Upgrade from a version before 0.4.0
---------------------------------------------

A VM created by an earlier version has an NVRAM file and a
``<name>_VARS.fd.secboot`` marker, and no ``.state`` file. The role must adopt
that VM: keep the NVRAM file with its UEFI boot entries, write a state file,
and remove the marker.

**Set up the old layout on the host:**

.. code-block:: bash

   install -d -o qemu -g qemu /var/lib/qemu/images
   printf 'legacy-boot-entries\n' > /var/lib/qemu/images/legacyvm_VARS.fd
   touch /var/lib/qemu/images/legacyvm_VARS.fd.secboot
   chown qemu:qemu /var/lib/qemu/images/legacyvm_VARS.fd /var/lib/qemu/images/legacyvm_VARS.fd.secboot

The marker means the VM ran with Secure Boot, so declare it the same way.

**Playbook** (``test_upgrade.yml``):

.. code-block:: yaml

   - hosts: all
     become: true
     roles:
       - maglo.qemu.host
       - role: maglo.qemu.vms
         vars:
           vms_list:
             - name: legacyvm
               disk_size: 5G
               secure_boot: true
               state: present

**Run:**

.. code-block:: bash

   ansible-playbook -i inventory.yml test_upgrade.yml

**Verify:**

.. code-block:: bash

   # The NVRAM file is untouched
   cat /var/lib/qemu/images/legacyvm_VARS.fd    # legacy-boot-entries

   # A state file replaced the marker
   cat /var/lib/qemu/images/legacyvm_VARS.fd.state
   ls /var/lib/qemu/images/legacyvm_VARS.fd.secboot 2>&1 | grep "No such file"

Declaring the same VM with ``secure_boot: false`` instead is the opposite
case: the marker disagrees with the flag, so the role rewrites the NVRAM file
from the plain template.

Test 20: VM list validation
----------------------------

The role validates the whole list before it touches the host. Each playbook
below must fail, and it must fail before any file is written.

**Duplicate VM name:**

.. code-block:: yaml

   vms_list:
     - name: dup-vm
       disk_size: 5G
     - name: dup-vm
       disk_size: 5G

**Two VMs on one VNC display:**

.. code-block:: yaml

   vms_list:
     - name: vnc-a
       disk_size: 5G
       vnc: 5
     - name: vnc-b
       disk_size: 5G
       vnc: 5

**Two VMs on one serial socket:**

.. code-block:: yaml

   vms_list:
     - name: sock-a
       disk_size: 5G
       serial_socket: /var/lib/qemu/shared/serial.sock
     - name: sock-b
       disk_size: 5G
       serial_socket: /var/lib/qemu/shared/serial.sock

**Secure Boot without UEFI:**

.. code-block:: yaml

   vms_list:
     - name: bad-secboot
       disk_size: 5G
       uefi: false
       secure_boot: true

**Expected result:**

- Each run fails in the ``Validate the VM list`` block, and the message names
  the VMs at fault.
- No disk image, no ``.conf`` file and no NVRAM file is created:

  .. code-block:: bash

     ls /etc/qemu/vms/
     ls /var/lib/qemu/images/

Two more cases behave the same way: a name that systemd cannot use as an
instance name (for example ``web/01``), and ``state: absent`` without
``force_destroy`` (see Test 11).

Test 21: Consoles and control sockets
--------------------------------------

Verify the serial socket, the QMP socket and the VNC bind address on a running
guest. This test needs a real KVM host: Molecule cannot boot a guest, so it
asserts the rendered arguments only.

**Playbook** (``test_consoles.yml``):

.. code-block:: yaml

   - hosts: all
     become: true
     roles:
       - maglo.qemu.host
       - role: maglo.qemu.vms
         vars:
           vms_list:
             - name: console-vm
               disk_size: 5G
               disk_image_url: <a bootable cloud image>
               vnc_address: 127.0.0.1
               state: started
             - name: console-open-vm
               disk_size: 5G
               vnc_address: ""          # every interface, the pre-0.6.0 default
               state: started

**Verify:**

.. code-block:: bash

   # Both sockets exist and QEMU did not block waiting for a client
   ls -l /var/lib/qemu/console-vm/serial.sock /var/lib/qemu/console-vm/qmp.sock
   systemctl is-active qemu-vm@console-vm

   # The serial socket reaches the guest console
   socat - UNIX-CONNECT:/var/lib/qemu/console-vm/serial.sock
   # Press Enter. The guest login prompt appears.

   # QMP answers, and screendump writes a file
   socat - UNIX-CONNECT:/var/lib/qemu/console-vm/qmp.sock
   {"execute": "qmp_capabilities"}
   {"execute": "query-status"}
   {"execute": "screendump", "arguments": {"filename": "/tmp/console-vm.ppm"}}

   # The human monitor vocabulary still works, over QMP
   {"execute": "human-monitor-command", "arguments": {"command-line": "info block"}}

   # The VNC console binds loopback only
   ss -ltnp | grep 5900

   # `-nographic` is gone, the short-form booleans are gone, and so is
   # `-monitor`
   grep -- "-display none" /etc/qemu/vms/console-vm.conf
   ! grep -- "server,nowait" /etc/qemu/vms/console-vm.conf
   ! grep -- "-monitor" /etc/qemu/vms/console-vm.conf

   # A graceful shutdown goes over QMP. Set `state: restarted` and re-run,
   # then confirm the guest powered down rather than being killed.
   journalctl -u qemu-vm@console-vm | grep -i "power\|shutdown"

**Expected result:**

- ``console-vm`` binds its VNC port on ``127.0.0.1`` only, which is also what
  it would do with ``vnc_address`` unset. ``console-open-vm`` asks for an
  empty ``vnc_address``, so it binds ``0.0.0.0`` and ``::``.
- ``journalctl -u qemu-vm@console-vm`` holds the messages of QEMU and the
  start line of systemd, and no guest console output.

Known RC limitations
---------------------

- Molecule cannot boot a guest, because a container has no KVM. The
  ``started``, ``stopped`` and ``restarted`` states therefore need a real KVM
  host. ``state: present`` and ``state: absent`` do run in Molecule: the
  ``lifecycle`` scenario of the ``vms`` role exercises ``state: absent`` with
  and without ``force_destroy``, and CI runs that scenario
- labview listens on loopback and authenticates nobody; put a reverse proxy that
  terminates TLS and authenticates in front of it for anything but a workstation
- Bridge mode requires the bridge device to already exist on the host; this collection
  does not create bridges
- Only QCOW2 format is supported for URL-based image provisioning; the role validates
  this and fails if a non-QCOW2 image is downloaded
- ``vms_verify_checksums`` controls whether the per-VM ``disk_image_checksum``
  is compared against the download. A VM that sets no ``disk_image_checksum``
  is not verified either way
