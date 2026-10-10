========================
maglo.qemu Release Notes
========================

.. contents:: Topics

v0.6.0
======

Release Summary
---------------

The console release. One labview console service on each hypervisor replaces the noVNC proxy of every VM: it serves the framebuffer, the serial line and a QMP control channel of every machine behind one port, with the keyboard held by one client at a time. Each VM therefore gets a serial socket and a QMP socket, its VNC console binds loopback by default, and the human monitor is gone. Enterprise Linux 10 is now the only supported host. After the upgrade, restart each running VM once with ``state: restarted``: until then it runs a command line without a QMP socket, and the role names every such VM on each run.

Major Changes
-------------

- the browser console of a VM is now the labview console service. Where each VM had its own ``novnc_proxy`` on ``6080 + <vnc display>``, one service serves every machine behind one port, and it carries two channels a browser never had: the guest serial line, and a control channel that sends a key chord, takes a frame of the screen or powers the machine. One client holds the keyboard at a time, as a write lease, and the rest watch. The ``host`` role installs and runs the service as part of preparing a hypervisor; set ``vms_labview_inventory_dir`` on the ``vms`` role so that it writes the per-machine inventory the service reads, and put a reverse proxy in front of labview to terminate TLS and authenticate. The console service guide covers the deployment, and ``playbooks/labview.yml`` is a runnable example (https://github.com/maglo/ansible-collection-qemu/issues/166).

Minor Changes
-------------

- Molecule - the scenarios default to a Rocky Linux 10 container. ``EL_VERSION`` still overrides the major version, but an unset ``EL_VERSION`` no longer tests a platform the collection does not support (https://github.com/maglo/ansible-collection-qemu/issues/168).
- docs - add a console service guide covering the deployment, the socket permissions it depends on, why the polkit rule is mandatory, the reverse proxy contract, and where guest boot output went now that the serial console is a socket rather than stdout (https://github.com/maglo/ansible-collection-qemu/issues/165).
- host role - ``host_labview_version`` defaults to ``0.3.0``, where it was ``0.2.0``. labview 0.2.1 fixes the browser console: a key press no longer closes the connection and freezes the picture, the console dials again after a machine restarts, and a machine that labview restarts reads as starting rather than failed. labview 0.3.0 plays a serial capture in the browser and fits the serial terminal to its pane. Neither release changes a flag or the inventory format, so the role changes nothing else. A host that sets ``host_labview_version`` keeps the version it sets (https://github.com/maglo/ansible-collection-qemu/issues/190).
- host role - add ``host_vm_umask``, the umask of the ``qemu-vm@.service`` units, defaulting to ``0007``. QEMU creates the serial and QMP sockets of a VM itself and never chmods them, so their mode is 0777 minus this value. Under systemd's own default of 0022 each socket was left at 0755, and connecting to a UNIX socket needs the write bit, so no account but the QEMU service user could open one -- not even a member of the service group. At 0770 a console service running under its own account in that group attaches to the serial line and drives the guest over QMP, and everything outside the group is shut out more firmly than 0755 shut it out. The mode is fixed when QEMU creates the socket, so a running VM keeps the socket it started with until it is restarted (https://github.com/maglo/ansible-collection-qemu/issues/178).
- host role - install and run the labview console service (https://github.com/maglo/qemu-lab-manager). Preparing a hypervisor now includes the console: the role installs the release binary, verified against the ``SHA256SUMS`` published beside it, creates the service account and the directories, installs the polkit rule that lets the service start, stop and restart the VM units, and runs it as ``labview.service``. The service serves every machine's framebuffer, serial line and details behind one port, reading the per-machine inventory the ``vms`` role writes through ``vms_labview_inventory_dir``, so one port replaces one noVNC instance per VM and a consumer gains a serial console and a control channel that no browser had before. Set ``host_labview_enabled`` to ``false`` on a host that should not run it, for example one with no outbound network for the download (https://github.com/maglo/ansible-collection-qemu/issues/165).
- host role - the role deploys no reverse proxy and manages no TLS material. ``host_labview_listen`` is ``127.0.0.1:8080`` and the role warns when it is set to anything that is not loopback: labview authenticates nobody, so whoever reaches it holds the write lease of every machine. Terminating TLS and authenticating belongs to a proxy in front of it, and which proxy is site policy. The role README and the new console service guide state the three things any proxy has to do -- forward the original ``Host`` header, set the identity header on the websocket upgrade as well as on ordinary requests, and discard any client-supplied identity header -- because each one fails in a way that looks like a console service bug (https://github.com/maglo/ansible-collection-qemu/issues/165).
- vms role - ``roles/vms/tasks/monitor.yml`` is renamed to ``runtime_dir.yml``. It creates the per-VM runtime directory and no longer has anything to do with a monitor socket (https://github.com/maglo/ansible-collection-qemu/issues/173).
- vms role - ``state: absent`` removes the console service inventory entry of the VM along with its other artifacts, so a teardown leaves no stale machine behind. The teardown run has to set ``vms_labview_inventory_dir`` as well; the removal cannot know the directory otherwise (https://github.com/maglo/ansible-collection-qemu/issues/164).
- vms role - add ``vms_labview_inventory_dir``. When it is set, the role writes the per-machine inventory file that a console service such as labview (https://github.com/maglo/qemu-lab-manager) reads: one file per VM at ``<dir>/<name>.yml``, holding the ``name``, ``host``, ``vnc``, ``serial``, ``control`` and ``unit`` of the VM. The role is the only thing that knows a VM's VNC display, its socket paths and its unit name, so writing the file here keeps a consumer from deriving the same facts a second time and drifting from them. When the variable is unset the role writes nothing, as before (https://github.com/maglo/ansible-collection-qemu/issues/164).
- vms role - add the per-VM ``vnc_address`` key and the ``vms_default_vnc_address`` variable. They set the address that the VNC console binds. ``127.0.0.1`` reaches the console through the host only. (https://github.com/maglo/ansible-collection-qemu/issues/163).
- vms role - each VM gets a QMP socket. QEMU opens it at ``/var/lib/qemu/<name>/qmp.sock``, and the new per-VM ``qmp_socket`` key and the ``vms_default_qmp_socket`` variable move it. QMP carries typed commands such as ``send-key`` and ``screendump`` (https://github.com/maglo/ansible-collection-qemu/issues/162).
- vms role - each VM gets a serial console socket. QEMU opens it at ``/var/lib/qemu/<name>/serial.sock``, and the new per-VM ``serial_socket`` key and the ``vms_default_serial_socket`` variable move it. A console client attaches there to read and to drive the guest serial console (https://github.com/maglo/ansible-collection-qemu/issues/161).
- vms role - report each VM that runs an outdated command line. The role does not restart a running VM to apply a config change, so a VM started by a release before 0.6.0 keeps a process with no QMP socket, and its next graceful shutdown ends in SIGTERM. Before it starts anything, the role now reads the unit of each VM and prints a ``NOTICE`` naming every VM whose unit is running but whose QMP socket is missing, with the fix: set ``state: restarted`` on it once. The notice fails nothing, and it names no VM that is stopped, that the run starts, or that the run restarts or stops (https://github.com/maglo/ansible-collection-qemu/issues/175).
- vms role - the graceful shutdown path sends ``system_powerdown`` over QMP instead of the human monitor, and it reads the answer. QMP replies ``{"return": {}}`` or an ``{"error": ...}`` object, so the role waits for the guest only when QEMU accepted the command; the human monitor answered in prose, so the old path could read nothing but the exit code of ``socat`` (https://github.com/maglo/ansible-collection-qemu/issues/173).
- vms role - the role no longer gathers facts. ``ansible_distribution_major_version`` was read only by the EL9 deprecation notice, so the ``setup`` task at the top of the role goes with it (https://github.com/maglo/ansible-collection-qemu/issues/168).
- vms role - the role removes what per-VM noVNC left on a host that ran an earlier release: the ``novnc-dependency.conf`` drop-in of each VM, its ``/etc/qemu/vms/novnc-<name>.conf``, and the enablement of its ``novnc@<name>.service``. The drop-in is why this is not left to the operator. It makes the unit of a VM ``Requires=novnc@<name>.service``, and this release no longer ships that template unit, so systemd would refuse to start the VM with an error naming a service the collection no longer has. The cleanup runs before any VM is started, removes only the one drop-in file so that a drop-in the deployer added survives, and does nothing at all on a host that never used noVNC (https://github.com/maglo/ansible-collection-qemu/issues/166).
- vms role - the run fails when two VMs would open one serial socket or one QMP socket. The check runs with the other whole-list checks, before the role writes anything to the host (https://github.com/maglo/ansible-collection-qemu/issues/161).

Breaking Changes / Porting Guide
--------------------------------

- Both roles now support Enterprise Linux 10 only. A play that targets an EL9 host is no longer tested and no longer supported. Upgrade the host to Enterprise Linux 10, or pin the collection to 0.5.x (https://github.com/maglo/ansible-collection-qemu/issues/168).
- host role - ``host_novnc_enabled`` and the ``novnc@.service`` template unit are gone, and the role no longer installs the ``novnc`` package. A playbook that passes the variable as a role parameter fails argument validation; one that sets it as a play or inventory variable is unaffected, because the variable is simply no longer read. Delete the line either way. EPEL is now needed only for ``swtpm``, ``socat`` and ``genisoimage`` (https://github.com/maglo/ansible-collection-qemu/issues/166).
- host role - the ``host_el9_deprecation_warning`` variable is removed. A playbook that passes it as a role parameter now fails argument validation with ``Supported parameters include: ...``; one that sets it as a play or inventory variable is unaffected, because the variable is simply no longer read. Delete the line either way (https://github.com/maglo/ansible-collection-qemu/issues/168).
- vms role - ``vms_default_vnc_address`` is now ``127.0.0.1``, where it was an empty string. The VNC console of a VM that leaves ``vnc_address`` unset therefore binds loopback, and is reachable through the host only, where it bound every interface on both ``0.0.0.0`` and ``::`` before. The raw RFB port of a VM is no longer in reach of anything that can route to the host, which is what makes the write lease of a console service mean anything. A VNC client on another host stops reaching a VM: set ``vnc_address: ""`` on that VM, or ``vms_default_vnc_address: ""`` for every VM, to keep the previous behaviour. (https://github.com/maglo/ansible-collection-qemu/issues/174).
- vms role - a VM has no ``-monitor`` socket. QMP is the whole control channel, and ``/var/lib/qemu/<name>/monitor.sock`` is gone. Nothing is lost: QMP carries every human monitor command through ``human-monitor-command``, so a consumer that drove the monitor sends ``{"execute": "human-monitor-command", "arguments": {"command-line": "info block"}}`` to ``/var/lib/qemu/<name>/qmp.sock`` instead. The human monitor is also not a stable interface: QEMU formats it for a person and reserves the right to change it, while QMP is the contract (https://github.com/maglo/ansible-collection-qemu/issues/173).
- vms role - the ``vms_el9_deprecation_warning`` variable is removed. A playbook that passes it as a role parameter now fails argument validation with ``Supported parameters include: ...``; one that sets it as a play or inventory variable is unaffected, because the variable is simply no longer read. Delete the line either way (https://github.com/maglo/ansible-collection-qemu/issues/168).
- vms role - the ``vms_vnc_address_deprecation_warning`` variable is gone, along with the notice it controlled. A playbook that passes it as a role parameter fails argument validation; one that sets it as a play or inventory variable is unaffected, because the variable is simply no longer read. Delete the line either way (https://github.com/maglo/ansible-collection-qemu/issues/174).
- vms role - the guest serial console leaves the systemd journal. A VM starts with ``-display none`` and an explicit ``-serial`` that points at the new serial socket, in place of ``-nographic``. ``journalctl -u qemu-vm@<name>`` therefore holds the stderr of QEMU and the start and stop lines of systemd, and no guest console output. Read the guest console at ``/var/lib/qemu/<name>/serial.sock`` instead, for example with ``socat - UNIX-CONNECT:/var/lib/qemu/<name>/serial.sock`` (https://github.com/maglo/ansible-collection-qemu/issues/161).
- vms role - the per-VM ``novnc_enabled`` and ``novnc_port`` keys and the ``vms_default_novnc_enabled`` and ``vms_default_novnc_port`` variables are gone, along with the per-VM environment file at ``/etc/qemu/vms/novnc-<name>.conf``, the ``novnc-dependency.conf`` drop-in and the duplicate noVNC port check. A VM that still carries one of the keys fails argument validation naming it, so delete them; the console of that VM comes from the ``labview`` role instead (https://github.com/maglo/ansible-collection-qemu/issues/166).
- vms role - upgrading needs one restart of each running VM. The role writes the new command line but does not restart a running VM, so a VM started before this release keeps a process with a monitor socket and no QMP socket. Its first graceful shutdown finds no QMP socket, falls through to stopping the unit, and therefore gets one SIGTERM instead of an ACPI power down. Run the play with ``state: restarted`` on each VM once after the upgrade (https://github.com/maglo/ansible-collection-qemu/issues/173).

Removed Features (previously deprecated)
----------------------------------------

- host role - support for Enterprise Linux 9 is removed. The deprecation was announced in 0.5.0. EL10 is now the only supported host platform: EL9 is gone from the CI matrix and from the ``platforms`` list of the role, and the ``host_el9_deprecation_warning`` variable is removed along with the notice it controlled (https://github.com/maglo/ansible-collection-qemu/issues/168).
- vms role - support for Enterprise Linux 9 is removed. The deprecation was announced in 0.5.0. This covers the EL9 *host* only; a VM may keep running an EL9 guest image. The ``vms_el9_deprecation_warning`` variable is removed along with the notice it controlled (https://github.com/maglo/ansible-collection-qemu/issues/168).

Bugfixes
--------

- vms role - a duplicate check now names the value at fault. Every such message was empty, because it built the list with ``L | difference(L | unique)`` and ``difference`` is a set operation that always returns an empty list. This covers the checks for a duplicate VM name, VNC display and MAC address (https://github.com/maglo/ansible-collection-qemu/issues/161).
- vms role - complete a run in which every VM carries ``state: absent`` (https://github.com/maglo/ansible-collection-qemu/issues/169). ``main.yml`` imported ``smbios.yml`` under ``when: _vms_active_vms | length > 0``, but ``import_tasks`` is static: the condition is copied onto each imported task rather than skipping the file, and Ansible builds a task's loop before it evaluates that task's ``when``. On a teardown run the selection is empty, so the ``set_fact`` that defines ``_vms_smbios_managed`` was skipped while the loop that reads it was still templated, and the play died with ``'_vms_smbios_managed' is undefined`` before ``destroy.yml`` had shut down or removed anything. The condition is gone from that import and from the two others that gate on ``_vms_active_vms``; every task in those files loops over a selection that is empty on a teardown run, so each no-ops by itself.

v0.5.0
======

Release Summary
---------------

Correctness release for the ``vms`` role, alongside a published documentation site and the deprecation of Enterprise Linux 9. The role now resolves the effective settings of every VM once and validates the whole list before it changes anything on the host, which turns a name collision or a contradictory key into an error instead of a VM that will not start. Several defaults that were documented but never read are honoured, a destroyed VM loses all of its state, and a guest is shut down gracefully before the role stops it.

Minor Changes
-------------

- Documentation - The guides and the role reference are now published as a documentation site at https://maglo.github.io/ansible-collection-qemu/, built from ``docs/`` with antsibull-docs and Sphinx and deployed to GitHub Pages on every push to ``main``. New guides cover installation, every VM feature, and the example playbooks. The README keeps a short overview of the collection and points at the site, so the page that Ansible Galaxy and the GitHub repository show is no longer the full reference (closes #154).
- galaxy.yml - The ``documentation`` and ``homepage`` URLs now point at the documentation site instead of the README.
- host role - add the ``host_el9_deprecation_warning`` variable. It controls the warning that the role prints on an Enterprise Linux 9 host (https://github.com/maglo/ansible-collection-qemu/issues/149).
- vms role - ``vms_verify_checksums`` now controls whether the per-VM ``disk_image_checksum`` is compared against the downloaded image. The variable was documented as reserved and had no effect.
- vms role - add the ``vms_el9_deprecation_warning`` variable. It controls the warning that the role prints on an Enterprise Linux 9 host (https://github.com/maglo/ansible-collection-qemu/issues/149).
- vms role - check the whole VM list before the role changes anything on the host. The new checks reject a duplicate VM name, a name that cannot be a systemd instance name, ``secure_boot`` without ``uefi``, a ``disk_image_url`` with a non-qcow2 ``disk_format``, and two VMs that would share a VNC display, a MAC address or a noVNC port. The role derives the display and the address from the VM name, so two names can collide; the run now fails with the names instead of leaving the second VM unable to start.
- vms role - drop the EL8 OVMF firmware paths. The collection supports EL9 and EL10, which share one layout, so ``vms_ovmf_code`` and ``vms_ovmf_vars_template`` are now plain paths like the two Secure Boot variables beside them, and ``meta/argument_specs.yml`` states their defaults. The role no longer gathers distribution facts, which were read only to pick between the two layouts.
- vms role - resolve the effective settings of every VM once, before the first task runs. Each task file now reads a ready-made selection (the UEFI VMs, the TPM VMs, the noVNC VMs, and so on) instead of filtering ``vms_list`` again with an expression that had to treat "key absent" and "key set to false" separately. The role also skips the firmware, TPM, noVNC, cloud-init and USB task files entirely when no VM uses them.

Deprecated Features
-------------------

- host role - support for Enterprise Linux 9 is deprecated and will be removed in a release after the next one. Until then EL9 stays supported and stays in the CI matrix. Plan an upgrade of the host to Enterprise Linux 10. The role prints a warning when it runs on EL9; set ``host_el9_deprecation_warning`` to ``false`` to silence it (https://github.com/maglo/ansible-collection-qemu/issues/149).
- vms role - support for Enterprise Linux 9 is deprecated and will be removed in a release after the next one. This covers the EL9 *host* only; a VM may keep running an EL9 guest image. The role prints a warning when it runs on an EL9 host; set ``vms_el9_deprecation_warning`` to ``false`` to silence it (https://github.com/maglo/ansible-collection-qemu/issues/149).

Bugfixes
--------

- vms role - clear the swtpm state only when ``tpm_generation`` increases. The role compared the generation for inequality, so lowering the value, or tidying a spent ``tpm_generation: 2`` line out of a playbook so that it fell back to 1, silently wiped the sealed key slots, the persistent handles and the PCR history of a running guest.
- vms role - fall back to stopping the unit when the guest ignores the ACPI powerdown. The condition that triggered the fallback could never be true, because the task it tested had ``failed_when: false``.
- vms role - honour ``vms_default_novnc_enabled``. A VM that did not set the per-VM ``novnc_enabled`` key was never configured for noVNC, even with the role default set to ``true``, while ``state: restarted`` and ``state: absent`` did honour the default.
- vms role - honour ``vms_default_novnc_port``. The variable was declared and documented but never read; every VM got 6080 plus its VNC display.
- vms role - remove every artifact of a destroyed VM. The UEFI variable store, the TPM state directory and the TPM state file were removed only when the VM still carried ``uefi: true`` or ``tpm: true``, so an operator who dropped the key in the same change that set ``state: absent`` left the state behind for the next VM of that name to adopt.
- vms role - shut the guest down over the QEMU monitor before destroying a VM. ``state: absent`` stopped and disabled the service first, which left the graceful shutdown with nothing to do, so the guest got a SIGTERM and its file systems stayed dirty. ``state: restarted`` had the same problem for a noVNC VM, whose service the role stopped first.

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
