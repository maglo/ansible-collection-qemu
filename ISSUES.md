# Planned GitHub Issues

## Issue: noVNC: support per-VM websocket proxy ports

**Labels:** bug

### Problem

The current noVNC implementation deploys a single `novnc.service` systemd unit
that listens on one port (default `6080`). This only proxies a single VNC
backend.

Each QEMU VM typically exposes its own VNC server on a unique display/port
(e.g. `-vnc :0`, `-vnc :1`, …). To make every VM reachable through the browser
the noVNC websocket proxy must also run once **per VM**, each on its own listen
port and pointing at the correct QEMU VNC backend.

### Current behaviour

- `novnc.service` is a plain (non-template) unit.
- It runs `novnc_proxy --listen 6080` with no `--vnc` target, so it can only
  serve a single VM.
- There is no mechanism to map a VM to its own noVNC proxy instance.

### Expected behaviour

- Each VM that has VNC enabled should get its own noVNC websocket proxy
  instance (e.g. via a systemd template unit `novnc@.service`).
- The proxy port and VNC target should be derived from VM configuration
  (variable list or per-VM dict).
- Port allocation should be deterministic and conflict-free.

### Acceptance criteria

- [ ] Replace or supplement `novnc.service` with a per-VM template unit
      (e.g. `novnc@<vmname>.service`).
- [ ] Each instance listens on a unique port and connects to the correct
      QEMU VNC backend.
- [ ] Existing Molecule tests are updated/extended to verify multi-VM noVNC.
- [ ] `defaults/main.yml` documents the new variables.
- [ ] Role README is updated.

---

## Issue: Add a create_vm role to fully provision a QEMU virtual machine

**Labels:** enhancement

### Summary

Today the collection provides `qemu_host` which prepares a host to **run** VMs,
but the actual creation of a VM is left entirely to the operator (manually
writing a `.conf` file with raw `QEMU_ARGS`). A new `create_vm` role should
automate every step needed to bring up a fully functional VM:

1. **Create a virtual block device** (qcow2 image)
2. **Ensure UEFI firmware is available** (OVMF/AAVMF)
3. **Start swtpm instance per VM** (TPM 2.0 emulation)
4. **Configure networking** (bridge/tap or user-mode)
5. **Generate the QEMU command / config and start the VM**

Each of the above is tracked as its own sub-issue below so work can proceed
in parallel.

### Design notes

- The role should accept a list/dict of VMs with per-VM parameters (name,
  memory, CPUs, disk size, firmware, TPM, network mode, etc.).
- It should integrate with the existing `qemu-vm@.service` template unit from
  `qemu_host`.
- Molecule tests should cover at least the "happy path" of creating a single
  VM with all subsystems enabled.

### Sub-issues

- [ ] create_vm: create virtual block device (qcow2)
- [ ] create_vm: ensure UEFI firmware (OVMF)
- [ ] create_vm: per-VM swtpm instance
- [ ] create_vm: configure VM networking (bridge/tap)
- [ ] create_vm: generate VM config and start the VM

---

## Sub-issue: create_vm: create virtual block device (qcow2 image)

**Labels:** enhancement

_Part of: Add a create_vm role to fully provision a QEMU virtual machine_

### Goal

Add tasks to the `create_vm` role that create a qcow2 virtual disk image for
each VM.

### Requirements

- Use `qemu-img create -f qcow2` to create the image.
- Disk size, path, and format should be configurable per VM.
- Idempotent: skip creation if the image already exists.
- Set correct ownership (`qemu:qemu`) and permissions.

### Acceptance criteria

- [ ] Task creates a qcow2 image at the configured path/size.
- [ ] Task is idempotent (no-op on re-run when image exists).
- [ ] Molecule test verifies the image is created with expected size.

---

## Sub-issue: create_vm: ensure UEFI firmware (OVMF) is available

**Labels:** enhancement

_Part of: Add a create_vm role to fully provision a QEMU virtual machine_

### Goal

Ensure OVMF (or AAVMF on aarch64) firmware packages are installed so VMs can
boot with UEFI.

### Requirements

- Install the appropriate firmware package (`edk2-ovmf` on EL).
- Provide a variable to select UEFI vs. legacy BIOS boot per VM.
- When UEFI is selected, add the correct `-drive if=pflash,...` arguments to
  `QEMU_ARGS`.
- Create a per-VM copy of the OVMF_VARS file so each VM has its own NVRAM.

### Acceptance criteria

- [ ] OVMF package is installed when any VM requests UEFI boot.
- [ ] Per-VM NVRAM vars file is created.
- [ ] Molecule test verifies firmware file exists and QEMU_ARGS contain the
      pflash entries.

---

## Sub-issue: create_vm: start per-VM swtpm instance

**Labels:** enhancement

_Part of: Add a create_vm role to fully provision a QEMU virtual machine_

### Goal

Start a dedicated `swtpm` process for each VM that requires TPM 2.0 emulation.

### Requirements

- Create a systemd template unit `swtpm@.service` (or equivalent) so each VM
  gets its own swtpm socket/state directory.
- State directory: `/var/lib/swtpm/<vmname>/` (configurable).
- TPM should be optional and toggled per VM.
- Add the matching `-chardev socket,...` and `-tpmdev emulator,...` arguments
  to `QEMU_ARGS`.

### Acceptance criteria

- [ ] swtpm template unit is deployed.
- [ ] Per-VM state directory is created with correct ownership.
- [ ] Molecule test verifies swtpm service starts and socket is created.

---

## Sub-issue: create_vm: configure VM networking (bridge/tap)

**Labels:** enhancement

_Part of: Add a create_vm role to fully provision a QEMU virtual machine_

### Goal

Set up networking for each VM so it can communicate with the host and external
network.

### Requirements

- Support at least two modes, selectable per VM:
  1. **User-mode networking** (`-nic user`) – simple, no host config needed.
  2. **Bridge/tap networking** – create a tap interface and attach it to a
     configurable bridge.
- For bridge mode:
  - Ensure the bridge device exists (or document that it must be pre-created).
  - Create a tap device owned by `qemu`.
  - Add appropriate `-netdev tap,...` and `-device virtio-net-pci,...`
    arguments.
- MAC address should be deterministic or configurable per VM.

### Acceptance criteria

- [ ] User-mode networking works out of the box for a VM.
- [ ] Bridge/tap mode creates the tap device and adds correct QEMU_ARGS.
- [ ] Molecule test verifies network arguments in the generated config.

---

## Sub-issue: create_vm: generate VM config and start the VM

**Labels:** enhancement

_Part of: Add a create_vm role to fully provision a QEMU virtual machine_

### Goal

Assemble the final `QEMU_ARGS` from all sub-components (disk, firmware, TPM,
network, VNC, memory, CPU, etc.) and write the VM config file used by the
existing `qemu-vm@.service` template unit.

### Requirements

- Generate `/etc/qemu/vms/<vmname>.conf` with the assembled `QEMU_ARGS`.
- Template the config from a Jinja2 template so all subsystem arguments are
  composed cleanly.
- Enable and start `qemu-vm@<vmname>.service`.
- Support a `state` parameter (present/absent/started/stopped) per VM.
- Ensure ordering: block device, firmware, swtpm, and networking must all be
  ready before the VM starts.

### Acceptance criteria

- [ ] Config file is generated with correct QEMU_ARGS for each VM.
- [ ] VM service is enabled and started.
- [ ] Molecule test verifies config content and service state.

---

## Issue: Add a manage_vm role for VM lifecycle operations (start, stop, restart, destroy)

**Labels:** enhancement

### Summary

Once VMs are created via the `create_vm` role, operators need a way to manage
their lifecycle through Ansible. A `manage_vm` role (or an extension of
`create_vm`) should support the following operations per VM:

| Operation   | Description |
|-------------|-------------|
| **start**   | Start a stopped VM via `qemu-vm@<vmname>.service`. |
| **stop**    | Gracefully shut down a running VM (ACPI poweroff via QEMU monitor or `systemctl stop`). |
| **restart** | Stop then start a VM (graceful reboot). |
| **destroy** | Force-stop the VM, remove its config, disk image, NVRAM, swtpm state, and noVNC proxy. Full cleanup. |

### Design notes

- Accept a per-VM `state` parameter: `started`, `stopped`, `restarted`,
  `absent` (destroy).
- **Graceful shutdown**: prefer sending ACPI shutdown via the QEMU monitor
  socket (`system_powerdown`) with a configurable timeout, falling back to
  SIGTERM/`systemctl stop` if the guest does not respond.
- **Destroy** should be opt-in and require explicit confirmation (e.g.
  `force_destroy: true`) to prevent accidental data loss.
- **Restart** should wait for the VM to fully stop before starting it again;
  honour a configurable timeout.
- Integrate with systemd: use `qemu-vm@<vmname>.service` for start/stop and
  `swtpm@<vmname>.service` / `novnc@<vmname>.service` for dependent services.

### Requirements

#### start
- Enable and start `qemu-vm@<vmname>.service`.
- Ensure dependent services (swtpm, noVNC proxy) are started first.
- Verify the VM process is running after start (poll QEMU monitor or PID).

#### stop
- Send ACPI shutdown via QEMU monitor socket if available.
- Wait up to `shutdown_timeout` (default 120 s) for graceful shutdown.
- Fall back to `systemctl stop qemu-vm@<vmname>.service` (SIGTERM).
- Optionally stop dependent services (swtpm, noVNC) after the VM stops.

#### restart
- Perform a stop followed by a start.
- Fail if the VM does not stop within the timeout.

#### destroy
- Require `force_destroy: true` to execute.
- Stop the VM (if running).
- Remove:
  - VM config file (`/etc/qemu/vms/<vmname>.conf`)
  - Disk image(s)
  - NVRAM vars file
  - swtpm state directory (`/var/lib/swtpm/<vmname>/`)
  - noVNC proxy unit instance
  - Tap network device (if bridge/tap mode)
- Disable and remove systemd unit overrides.

### Acceptance criteria

- [ ] `state: started` starts a stopped VM and its dependent services.
- [ ] `state: stopped` gracefully shuts down a running VM.
- [ ] `state: restarted` performs a stop + start cycle.
- [ ] `state: absent` with `force_destroy: true` removes all VM artifacts.
- [ ] `state: absent` without `force_destroy` fails with an error message.
- [ ] Timeouts are configurable and honoured.
- [ ] Molecule tests cover each lifecycle transition.

---

## Issue: Register collection with Ansible Galaxy

**Labels:** enhancement, infrastructure

### Summary

Publish the `basalt.qemu` collection to Ansible Galaxy so users can install it
with `ansible-galaxy collection install basalt.qemu`.

### Tasks

- [ ] Create an account / namespace `basalt` on [Ansible Galaxy](https://galaxy.ansible.com/).
- [ ] Verify `galaxy.yml` metadata is complete and accurate (version, authors,
      license, description, repository URL, tags).
- [ ] Add a GitHub Actions workflow step (or separate workflow) to build and
      publish the collection tarball on tagged releases.
      ```yaml
      ansible-galaxy collection build
      ansible-galaxy collection publish *.tar.gz --api-key ${{ secrets.GALAXY_API_KEY }}
      ```
- [ ] Store the Galaxy API key as a repository secret (`GALAXY_API_KEY`).
- [ ] Test the publish pipeline with a pre-release version.
- [ ] Update README with Galaxy install instructions and badge.

### References

- [Galaxy publishing docs](https://docs.ansible.com/ansible/latest/galaxy/dev_guide.html)
- Current `galaxy.yml` already defines namespace `basalt` and name `qemu`.
