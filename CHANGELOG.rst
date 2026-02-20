========================
maglo.qemu Release Notes
========================

.. contents:: Topics

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
