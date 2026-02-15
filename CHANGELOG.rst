===========================
basalt.qemu Release Notes
===========================

.. contents:: Topics

Unreleased
==========

New Roles
---------
- ``create_vm`` role for declarative VM creation with qcow2 disk support (PR #24).

Breaking Changes
----------------
- **noVNC configuration refactored** (Issue #50): Per-VM noVNC configuration moved from ``qemu_host`` role to ``create_vm`` role for better separation of concerns.

  - **Removed variables** from ``qemu_host`` role:

    - ``qemu_host_novnc_vms`` (list of VMs)
    - ``qemu_host_novnc_install_dir`` (installation directory)
    - ``qemu_host_novnc_version`` (version tag)

  - **New behavior**: ``qemu_host_novnc_enabled`` now only installs the ``novnc`` package from EPEL (no longer manages per-VM services).

  - **Migration path**: Enable noVNC per-VM in the ``create_vm`` role using ``novnc_enabled: true`` on individual VM definitions.

  - **Installation method changed**: noVNC is now installed via RPM package (``novnc`` from EPEL 9/10) instead of git clone to ``/opt/noVNC``.

  - **Example migration**:

    **Before** (qemu_host role)::

        - role: basalt.qemu.qemu_host
          vars:
            qemu_host_novnc_enabled: true
            qemu_host_novnc_vms:
              - name: web01
                novnc_port: 6080
                vnc_target: localhost:5900

    **After** (create_vm role)::

        - role: basalt.qemu.qemu_host
          vars:
            qemu_host_novnc_enabled: true  # Install package only

        - role: basalt.qemu.create_vm
          vars:
            create_vm_vms:
              - name: web01
                novnc_enabled: true
                novnc_port: 6080  # Optional, auto-assigned if omitted

  See ``roles/create_vm/README.md`` for full noVNC documentation.

Minor Changes
-------------
- create_vm — UEFI firmware (OVMF) boot support (PR #35).
- create_vm — Per-VM noVNC web console configuration (Issue #50).
- create_vm — Auto-port assignment for noVNC (defaults to ``6080 + VNC display number``).
- qemu_host — Simplified noVNC handling: package installation only, per-VM config moved to ``create_vm`` (Issue #50).
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
