===========================
basalt.qemu Release Notes
===========================

.. contents:: Topics

Upcoming
========

Release Summary
---------------

Initial release of the ``basalt.qemu`` collection.

Major Changes
-------------

- qemu_host - Add ``qemu_host`` role for managing QEMU/KVM hosts on Enterprise Linux.
- qemu_host - noVNC configuration refactored (issue #50). Per-VM noVNC configuration
  moved from ``qemu_host`` role to ``create_vm`` role for better separation of concerns.
  Removed variables: ``qemu_host_novnc_vms``, ``qemu_host_novnc_install_dir``,
  ``qemu_host_novnc_version``. ``qemu_host_novnc_enabled`` now only installs the
  ``novnc`` package from EPEL. noVNC is installed via RPM package instead of git clone.
  Migrate by enabling noVNC per-VM via ``novnc_enabled: true`` on individual VM
  definitions in the ``create_vm`` role.

Minor Changes
-------------

- Add ``CONTRIBUTING.md`` and collection docsite (PR #34).
- Add ``meta/argument_specs.yml`` and role-level READMEs for all roles (PR #33).
- Add Enterprise Linux 10 support; drop EL 8 (PR #53).
- Add example playbooks and sample inventory (PR #13).
- Added ``create_vm`` role for declarative VM creation with qcow2 disk support (PR #24).
- create_vm - Add UEFI firmware (OVMF) boot support (PR #35).
- create_vm - Add USB disk image attachment support via ``usb_disk_image`` and
  ``usb_boot_priority`` parameters (closes #47, PR #59).
- create_vm - Add URL-based disk image provisioning with backing file support.
- create_vm - Add VM lifecycle management (start, stop, restart) support (PR #56).
- create_vm - Add VM networking configuration supporting bridge/tap and user-mode (NAT)
  networking (PR #43).
- create_vm - Add per-VM ``swtpm`` service for TPM 2.0 emulation (PR #41).
- create_vm - Add per-VM noVNC web console configuration (issue #50).
- create_vm - Add systemd dependency between ``qemu-vm@`` and ``swtpm@`` services for
  TPM-enabled VMs.
- create_vm - Auto-assign noVNC port (defaults to ``6080 + VNC display number``) when
  not specified (issue #50).
- create_vm - Generate full VM configuration and manage ``qemu-vm@`` systemd service
  lifecycle (PR #44).
- qemu_host - Add per-VM ``novnc@.service`` systemd template, replacing the previous
  shared service (PR #38).
- qemu_host - Refactor ``swtpm@.service`` template deployment to ``qemu_host`` role.
- qemu_host - Simplify noVNC handling to package installation only; per-VM config moved
  to ``create_vm`` (issue #50).

Bugfixes
--------

- create_vm - Fix argument validation for ``create_vm_vms`` items (PR #39).
