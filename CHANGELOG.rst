===========================
basalt.qemu Release Notes
===========================

.. contents:: Topics

Unreleased
==========

New Roles
---------
- ``create_vm`` role for declarative VM creation with qcow2 disk support (PR #24).

Minor Changes
-------------
- create_vm — UEFI firmware (OVMF) boot support (PR #35).
- qemu_host — Per-VM ``novnc@.service`` systemd template replacing shared service (PR #38).
- Example playbooks and sample inventory (PR #13).
- ``meta/argument_specs.yml`` and role-level READMEs (PR #33).
- ``CONTRIBUTING.md`` and collection docsite (PR #34).

Bugfixes
--------
- create_vm — Fix argument validation for ``create_vm_vms`` items (PR #39).

v0.1.0
======

Release Summary
---------------
Initial release of the ``basalt.qemu`` collection.

Major Changes
-------------
- Added ``qemu_host`` role for managing QEMU/KVM hosts on Enterprise Linux.
