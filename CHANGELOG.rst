========================
maglo.qemu Release Notes
========================

.. contents:: Topics

v0.4.0
======

Release Summary
---------------

Feature release for the ``vms`` role. It adds control over the UEFI variable store of a VM (per-VM template, forced reset, rewrite on a template change and an optional Secure Boot verification), a way to reset the swtpm state of a VM, per-VM SMBIOS type 11 OEM strings, and the ``virtio-scsi`` disk bus.

Minor Changes
-------------

- vms role - add the ``vms_nvram_verify`` variable and the per-VM ``nvram_expected_db_cn`` key. When the verification is on, the role asserts that the UEFI variable store of each Secure Boot VM holds a PK, a KEK and a db, and that ``SecureBootEnable`` is on. A store without a PK is in Setup Mode, and a VM with such a store boots an unsigned artifact without a complaint. The check needs ``virt-fw-vars`` from the package ``python3-virt-firmware``, and the role reports a skip when the command is absent (https://github.com/maglo/ansible-collection-qemu/issues/143).
- vms role - add the per-VM ``disk_bus`` key and the ``vms_default_disk_bus`` variable. The value ``virtio-scsi`` attaches the system disk through a ``virtio-scsi-pci`` controller and an ``scsi-hd`` device. The default stays ``virtio-blk``, so the QEMU arguments of an existing VM do not change (https://github.com/maglo/ansible-collection-qemu/issues/140).
- vms role - add the per-VM ``nvram_generation`` key and the ``vms_nvram_force_reset`` variable. Increase the generation to write the UEFI NVRAM file again from its template (https://github.com/maglo/ansible-collection-qemu/issues/139).
- vms role - add the per-VM ``nvram_template`` key. It selects the UEFI variable store template for one VM and overrides ``vms_ovmf_vars_template`` and ``vms_ovmf_vars_secboot_template`` for that VM only (https://github.com/maglo/ansible-collection-qemu/issues/139).
- vms role - add the per-VM ``smbios_oem_strings`` key. The role passes each string to QEMU as an SMBIOS type 11 OEM string, which ``systemd-stub`` reads. This adds to the command line of a UKI without a rebuild and a new signature (https://github.com/maglo/ansible-collection-qemu/issues/141).
- vms role - add the per-VM ``tpm_generation`` key and the ``vms_tpm_force_reset`` variable. Increase the generation to clear the swtpm state directory of a VM. The role stops the VM and swtpm before it clears the directory, and starts them again afterwards. A VM that has no TPM state file yet keeps its state, so an upgrade of the collection does not clear the TPM of a VM that exists (https://github.com/maglo/ansible-collection-qemu/issues/142).
- vms role - replace the ``<name>_VARS.fd.secboot`` marker file with the ``<name>_VARS.fd.state`` state file. The role adopts an existing marker without a rewrite of the NVRAM file, so an upgrade keeps the UEFI boot entries of each VM that exists (https://github.com/maglo/ansible-collection-qemu/issues/139).
- vms role - stop a VM before the role writes its UEFI NVRAM file, and start the VM again afterwards. QEMU maps the file as pflash while the VM runs (https://github.com/maglo/ansible-collection-qemu/issues/139).
- vms role - write the UEFI NVRAM file again when the template path or the content of the template changes. Earlier versions wrote the file only when the ``secure_boot`` flag changed (https://github.com/maglo/ansible-collection-qemu/issues/139).

v0.3.1
======

Minor Changes
-------------

- vms - Add C(vms_default_cpu) role variable and per-VM C(cpu_model) key to make the QEMU C(-cpu) model configurable (closes #107).
- vms - include VM name in per-VM loop task names for clearer playbook output when managing multiple VMs (closes #128).

Bugfixes
--------

- host - install edk2-ovmf package for UEFI firmware support; it was incorrectly installed by the vms role instead of the host role (closes #126).
- vms - fix default cloud-init meta-data producing literal ``\n`` instead of newlines, which prevented cloud-init from setting the VM hostname (closes #129).
- vms - remove host role dependency to prevent double-application when following documented playbook patterns (closes #125).
- vms - stop VM service before verifying shutdown during destroy to prevent failure when Restart=on-failure is set in the QEMU systemd service (closes #127).

v0.3.0
======

Minor Changes
-------------

- host - add genisoimage to default host_packages for cloud-init seed ISO support.
- vms - add idempotent cloud-init seed ISO generation from per-VM inline variables (closes #120).

v0.2.2
======

Bugfixes
--------

- host - Add ``become: true`` to SELinux policy compile and package tasks to prevent ``Permission denied`` errors when ``/tmp/qemu_vm.mod`` or ``/tmp/qemu_vm.pp`` are root-owned from a previous run (https://github.com/maglo/ansible-collection-qemu/issues/118).
- host - Extend SELinux policy (v1.2) to grant ``init_t`` permission to create the QEMU monitor unix socket and access ``/dev/kvm``; fixes VM startup ``Permission denied`` errors on EL9/EL10 with SELinux enforcing (https://github.com/maglo/ansible-collection-qemu/issues/119).

v0.2.1
======

Bugfixes
--------

- Replace relative README links with absolute GitHub URLs so they resolve correctly on Ansible Galaxy (closes #101).
- host - Fix SELinux policy to target ``init_t`` instead of ``unconfined_service_t`` and add ``swtpm_exec_t`` execute rule, resolving VMs failing to start with SELinux enforcing on EL9 (closes #99).
- host - Move SELinux policy installation from ``vms`` role to ``host`` role where it architecturally belongs (closes #98).
- host, vms - Add ``become: true`` to ``Reload systemd`` handlers so ``daemon_reload`` reaches the system D-Bus socket and does not time out when the play runs without top-level ``become`` (closes #104).
- vms - Add ``-cpu host`` flag to QEMU args so guests expose the host CPU feature set; without it QEMU defaults to ``qemu64``, causing a fatal glibc error on EL9 (closes #106).
- vms - Create per-VM runtime directory for the monitor socket when ``state: present``, not only for started/stopped/restarted, so ``systemctl start qemu-vm@<name>`` works without a second playbook run (closes #105).
- vms - Fail early when ``novnc_enabled`` is set but the ``novnc@.service`` template is absent, and add a systemd drop-in so the VM unit depends on its noVNC service (closes #100).
- vms - Replace Jinja2 loop variable in TPM drop-in task ``name:`` field with a static string to avoid literal ``{{ item.name }}`` appearing in loop output (closes #103).

v0.2.0
======

Release Summary
---------------

Add UEFI Secure Boot support, fix Galaxy documentation, and remove the
legacy libvirtd management from the host role.

Minor Changes
-------------

- vms role - Add UEFI Secure Boot support via ``secure_boot`` per-VM key and ``vms_default_secure_boot`` global default. When enabled, the role uses OVMF Secure Boot firmware with pre-enrolled keys, adds ``smm=on`` to the QEMU machine line, and sets the ``cfi.pflash01`` secure property (https://github.com/maglo/ansible-collection-qemu/issues/90).

Breaking Changes / Porting Guide
--------------------------------

- host - Remove ``host_libvirtd_enabled`` variable and ``libvirt`` from default packages. The collection's libvirt-free design means libvirtd was never needed for VM management. Users who need libvirt can add it to ``host_packages`` (closes #91).

Bugfixes
--------

- collection - Add ``documentation``, ``homepage``, and ``issues`` URLs to ``galaxy.yml`` metadata (https://github.com/maglo/ansible-collection-qemu/issues/88).
- collection - Include playbooks in the collection tarball so README links resolve on Galaxy (https://github.com/maglo/ansible-collection-qemu/issues/88).

v0.1.1
======

Release Summary
---------------

Bug-fix release addressing 10 issues found during manual testing of v0.1.0 on AlmaLinux 8 and EL9 with SELinux enforcing. See `#84 <https://github.com/maglo/ansible-collection-qemu/issues/84>`_ for the full test report.

Bugfixes
--------

- docs - Add EPEL to the Prerequisites section of ``README.md`` and ``roles/host/README.md``; note that the collection intentionally does not manage EPEL to support airgapped deployments (`#80 <https://github.com/maglo/ansible-collection-qemu/issues/80>`_).
- host role - Add ``become: true`` to all privileged tasks so the role can be used without ``become: true`` at playbook level (`#74 <https://github.com/maglo/ansible-collection-qemu/issues/74>`_).
- host role - Change ``host_libvirtd_enabled`` default from ``true`` to ``false`` to honour the Libvirt-free design principle and prevent libvirtd from blocking plays when it fails to start (`#75 <https://github.com/maglo/ansible-collection-qemu/issues/75>`_).
- host role - Remove dead ``"Remove legacy single-instance noVNC service"`` task; v0.1.0 is the first release and has no legacy service to clean up (`#77 <https://github.com/maglo/ansible-collection-qemu/issues/77>`_).
- host role - Rename task ``"Enable and start libvirtd"`` to ``"Manage state of libvirtd service"`` to accurately reflect its conditional behaviour (`#76 <https://github.com/maglo/ansible-collection-qemu/issues/76>`_).
- vms role - Add ``"Verify VM service is running"`` task after starting ``qemu-vm@<name>.service``; the play now fails with a clear error if the service does not reach active state (`#79 <https://github.com/maglo/ansible-collection-qemu/issues/79>`_).
- vms role - Make OVMF firmware paths configurable with per-OS defaults using ``ansible_distribution_major_version``; fixes hardcoded path that does not exist on EL8 (`#78 <https://github.com/maglo/ansible-collection-qemu/issues/78>`_).
- vms role - Rename task ``"Enable and start VM service"`` to ``"Manage VM service state"`` to accurately reflect its conditional behaviour (`#83 <https://github.com/maglo/ansible-collection-qemu/issues/83>`_).
- vms role - Replace Jinja2-interpolated task names with static names to comply with Ansible best practices (`#82 <https://github.com/maglo/ansible-collection-qemu/issues/82>`_).
- vms role - Ship a minimal SELinux policy module (``qemu_vm.te``) and tasks to compile and install it on EL9/EL10 hosts with SELinux enforcing; fixes ``"Permission denied"`` when executing ``/usr/libexec/qemu-kvm`` (`#81 <https://github.com/maglo/ansible-collection-qemu/issues/81>`_).

v0.1.0
======

Release Summary
---------------

Initial release of the ``maglo.qemu`` collection.

Major Changes
-------------

- host - Add ``host`` role for managing QEMU/KVM hosts on Enterprise Linux.
- host - noVNC configuration refactored (issue #50). Per-VM noVNC configuration moved from ``host`` role to ``vms`` role for better separation of concerns. Removed variables: ``host_novnc_vms``, ``host_novnc_install_dir``, ``host_novnc_version``. ``host_novnc_enabled`` now only installs the ``novnc`` package from EPEL. noVNC is installed via RPM package instead of git clone. Migrate by enabling noVNC per-VM via ``novnc_enabled: true`` on individual VM definitions in the ``vms`` role.

Minor Changes
-------------

- Add Enterprise Linux 10 support; drop EL 8 (PR #53).
- Add ``CONTRIBUTING.md`` and collection docsite (PR #34).
- Add ``meta/argument_specs.yml`` and role-level READMEs for all roles (PR #33).
- Add example playbooks and sample inventory (PR #13).
- Added ``vms`` role for declarative VM creation with qcow2 disk support (PR #24).
- README: add AI Assistance disclosure for Grok, OpenAI Codex, and Claude (https://github.com/maglo/ansible-collection-qemu/issues/68)
- README: add Prerequisites section with hardware virtualization verification steps (https://github.com/maglo/ansible-collection-qemu/issues/68)
- README: add Use Case and design philosophy section targeting developers needing repeatable VM provisioning (https://github.com/maglo/ansible-collection-qemu/issues/68)
- host - Add per-VM ``novnc@.service`` systemd template, replacing the previous shared service (PR #38).
- host - Refactor ``swtpm@.service`` template deployment to ``host`` role.
- host - Simplify noVNC handling to package installation only; per-VM config moved to ``vms`` (issue #50).
- vms - Add UEFI firmware (OVMF) boot support (PR #35).
- vms - Add URL-based disk image provisioning with backing file support.
- vms - Add USB disk image attachment support via ``usb_disk_image`` and ``usb_boot_priority`` parameters (closes #47, PR #59).
- vms - Add VM lifecycle management (start, stop, restart) support (PR #56).
- vms - Add VM networking configuration supporting bridge/tap and user-mode (NAT) networking (PR #43).
- vms - Add argument validation for ``vms_list`` items (PR #39).
- vms - Add per-VM ``swtpm`` service for TPM 2.0 emulation (PR #41).
- vms - Add per-VM noVNC web console configuration (issue #50).
- vms - Add systemd dependency between ``qemu-vm@`` and ``swtpm@`` services for TPM-enabled VMs.
- vms - Auto-assign noVNC port (defaults to ``6080 + VNC display number``) when not specified (issue #50).
- vms - Generate full VM configuration and manage ``qemu-vm@`` systemd service lifecycle (PR #44).
