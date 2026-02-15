# basalt.qemu.create_vm

Create QEMU/KVM virtual machines on an Enterprise Linux host.

The role creates disk images, configures UEFI firmware, TPM emulation, and networking for each VM defined in `create_vm_vms`. It generates a complete per-VM `.conf` file with all QEMU arguments and manages the `qemu-vm@<name>.service` systemd service.

## Requirements

- Ansible >= 2.15
- Target hosts running Enterprise Linux 9 or 10

## Dependencies

- `basalt.qemu.qemu_host` — must be applied first to install QEMU and create the image directory.

## Role Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `create_vm_vms` | `[]` | List of VMs to create (see below) |
| `create_vm_default_disk_size` | `20G` | Default disk size when not specified per VM |
| `create_vm_default_disk_format` | `qcow2` | Default disk format (`qcow2` or `raw`) |
| `create_vm_image_dir` | `/var/lib/qemu/images` | Directory for disk images (should match `qemu_host_vm_image_dir`) |
| `create_vm_service_user` | `qemu` | Owner of the created disk images |
| `create_vm_service_group` | `qemu` | Group of the created disk images |
| `create_vm_default_uefi` | `true` | Whether VMs default to UEFI boot when not specified per VM |
| `create_vm_ovmf_code` | `/usr/share/edk2/ovmf/OVMF_CODE.fd` | Path to OVMF firmware code file |
| `create_vm_ovmf_vars_template` | `/usr/share/edk2/ovmf/OVMF_VARS.fd` | Path to OVMF vars template (copied per VM) |
| `create_vm_default_tpm` | `false` | Whether VMs default to TPM 2.0 emulation (per-VM override with `tpm` key) |
| `create_vm_swtpm_state_dir` | `/var/lib/swtpm` | Base directory for per-VM swtpm state |
| `create_vm_default_net_mode` | `user` | Default networking mode (`user` or `bridge`) |
| `create_vm_default_net_bridge` | `br0` | Default bridge device for bridge-mode VMs |
| `create_vm_bridge_conf` | `/etc/qemu/bridge.conf` | Path to the QEMU bridge helper ACL file |
| `create_vm_vm_config_dir` | `/etc/qemu/vms` | Directory for per-VM QEMU configuration files |
| `create_vm_default_memory` | `2G` | Default memory allocation for VMs |
| `create_vm_default_cpus` | `2` | Default number of virtual CPUs |
| `create_vm_default_novnc_enabled` | `false` | Whether VMs default to noVNC web console when not specified per VM |
| `create_vm_default_novnc_port` | `null` | Default noVNC port (null = auto-assign as 6080 + VNC display number) |
| `create_vm_default_shutdown_timeout` | `120` | Default timeout in seconds for graceful ACPI shutdown |

### VM definition

Each entry in `create_vm_vms` is a dictionary with the following keys:

| Key | Required | Default | Description |
|-----|----------|---------|-------------|
| `name` | yes | — | VM name, used as the disk image filename |
| `disk_size` | no | `create_vm_default_disk_size` | Disk image size (e.g. `20G`, `100G`) |
| `disk_format` | no | `create_vm_default_disk_format` | Disk format (`qcow2` or `raw`) |
| `uefi` | no | `create_vm_default_uefi` | Whether to enable UEFI boot for this VM |
| `tpm` | no | `create_vm_default_tpm` | Enable TPM 2.0 emulation via swtpm |
| `net_mode` | no | `create_vm_default_net_mode` | Networking mode: `user` or `bridge` |
| `net_bridge` | no | `create_vm_default_net_bridge` | Bridge device (only used when `net_mode` is `bridge`) |
| `mac_address` | no | auto-generated | MAC address (overrides the deterministic auto-generated MAC) |
| `memory` | no | `create_vm_default_memory` | Memory allocation (e.g. `2G`, `4G`) |
| `cpus` | no | `create_vm_default_cpus` | Number of virtual CPUs |
| `vnc` | no | hash-based | VNC display number (port = 5900+N) |
| `novnc_enabled` | no | `create_vm_default_novnc_enabled` | Enable noVNC web console for this VM |
| `novnc_port` | no | `6080 + vnc` | Port for noVNC web console (auto-assigned if not specified) |
| `state` | no | `present` | Desired service state: `started`, `stopped`, `present`, `restarted`, or `absent` |
| `force_destroy` | no | `false` | Safety flag required to destroy VM with `state: absent` (must be `true`) |
| `shutdown_timeout` | no | `120` | Timeout in seconds for graceful ACPI shutdown (used by `restarted` and `absent`) |

## Service management

The role manages each VM as a `qemu-vm@<name>.service` systemd unit. The per-VM `state` parameter controls the service lifecycle:

- **`present`** (default) — the config file is written but the service is not managed at all (useful for testing or environments without KVM).
- **`started`** — the service is enabled and started.
- **`stopped`** — the service is enabled but stopped (useful for pre-provisioning).
- **`restarted`** — performs a graceful restart (stop + start). The VM is sent an ACPI shutdown signal and given time to shut down gracefully before being restarted.
- **`absent`** — **DESTRUCTIVE**: stops and removes the VM along with all artifacts (disk image, NVRAM, TPM state, configs). Requires `force_destroy: true` to execute.

### Graceful shutdown

When stopping or restarting VMs, the role uses QEMU's monitor socket to send an ACPI shutdown signal (`system_powerdown`). This allows the guest OS to shut down cleanly. The role waits up to `shutdown_timeout` seconds (default: 120) for the guest to stop. If the timeout is exceeded, the VM is forcefully stopped via `systemctl stop`.

### Destroying VMs

To prevent accidental data loss, destroying a VM requires setting `force_destroy: true` on the VM definition:

```yaml
create_vm_vms:
  - name: testvm
    state: absent
    force_destroy: true  # Required!
```

When destroyed, the following artifacts are removed:
- Disk image (`/var/lib/qemu/images/{name}.{qcow2|raw}`)
- UEFI NVRAM file (`/var/lib/qemu/images/{name}_VARS.fd`)
- Config files (`/etc/qemu/vms/{name}.conf`, `/etc/qemu/vms/novnc-{name}.conf`)
- Runtime directory (`/var/lib/qemu/{name}/`)
- TPM state directory (`/var/lib/swtpm/{name}/`)
- Systemd service instances

**Note:** Shared resources like `/etc/qemu/bridge.conf` are not removed.

## Networking

The role supports two networking modes:

- **`user`** (default) — QEMU user-mode networking (SLIRP). No host configuration needed. The VM gets outbound connectivity via NAT but is not reachable from the host network.
- **`bridge`** — Bridge/tap networking via `qemu-bridge-helper`. The VM is attached to a host bridge and appears as a device on the bridged network.

### Bridge mode prerequisites

Bridge mode uses QEMU's `qemu-bridge-helper` to attach VMs to a host bridge. The bridge device itself must already exist on the host (this role does not create it). The role writes `/etc/qemu/bridge.conf` to authorize the helper to use the specified bridges.

### MAC address generation

Each VM is assigned a deterministic MAC address derived from its name using the QEMU OUI prefix `52:54:00`. The last three octets are taken from the MD5 hash of the VM name. You can override this with the `mac_address` per-VM key.

## VNC Console Access

Each VM is configured with a VNC console for remote graphical access. VNC display numbers are assigned as follows:

- **Default**: Hash of VM name modulo 100 (deterministic, prevents conflicts)
- **Override**: Set `vnc: N` per VM to specify display number N

VNC ports are calculated as 5900+N where N is the display number.

**Examples:**
- VM "testvm" → display :42 → VNC port 5942
- VM with `vnc: 10` → display :10 → VNC port 5910

**Access:** Connect using any VNC client:
```bash
vncviewer <host>:<5900+display>
```

**Security note:** VNC is unauthenticated by default. Consider firewall rules or VNC password authentication for production use.

## noVNC Web Console

The role can configure per-VM noVNC instances for browser-based console access. noVNC provides an HTML5 VNC client that requires no client-side software.

### Prerequisites

1. Install the `novnc` package on the host (handled by `basalt.qemu.qemu_host` role with `qemu_host_novnc_enabled: true`)
2. Ensure the EPEL repository is enabled (EPEL 9 provides novnc 1.4.0, EPEL 10 provides 1.5.0)

### Configuration

Enable noVNC per-VM by setting `novnc_enabled: true`:

```yaml
create_vm_vms:
  - name: web01
    novnc_enabled: true
    novnc_port: 6080  # Optional, auto-assigned if omitted
```

When enabled, the role:
- Deploys the `novnc@.service` systemd template
- Creates a per-VM environment file at `/etc/qemu/vms/novnc-<name>.conf`
- Starts and enables the `novnc@<name>.service` instance

### Port Assignment

noVNC ports are auto-assigned if not specified:
- **Auto-assignment**: `6080 + VNC display number`
- **Manual override**: Set `novnc_port: N` per VM

**Examples:**
- VM with VNC display :0 → noVNC port 6080
- VM with VNC display :1 → noVNC port 6081
- VM with `novnc_port: 8080` → noVNC port 8080 (override)

### Access

Once configured, access the VM console in a web browser:
```
http://<host>:<novnc_port>/vnc.html
```

For example, a VM with noVNC on port 6080:
```
http://192.168.1.100:6080/vnc.html
```

### Service Dependencies

The `novnc@<name>.service` automatically depends on the corresponding `qemu-vm@<name>.service`, ensuring the VM starts before its noVNC proxy.

**Security note:** noVNC serves unencrypted WebSocket connections by default. For production use, consider placing it behind a reverse proxy with TLS/SSL.

## Example Playbook

```yaml
- hosts: hypervisors
  roles:
    - basalt.qemu.qemu_host
    - role: basalt.qemu.create_vm
      vars:
        create_vm_vms:
          - name: web01
            disk_size: 40G
            memory: 4G
            cpus: 4
            vnc: 1
          - name: db01
            disk_size: 100G
            disk_format: raw
            net_mode: bridge
            net_bridge: br-lan
            memory: 8G
            cpus: 8
          - name: worker01
            uefi: false
            mac_address: "52:54:00:aa:bb:cc"
            state: stopped
```

### TPM 2.0 emulation

To start a per-VM `swtpm` instance, set `tpm: true` on the VM entry:

```yaml
- hosts: hypervisors
  roles:
    - basalt.qemu.qemu_host
    - role: basalt.qemu.create_vm
      vars:
        create_vm_vms:
          - name: secure-vm
            disk_size: 40G
            tpm: true
```

This starts the `swtpm@secure-vm.service` instance (using the `swtpm@.service` template deployed by `qemu_host`), creating a per-VM state directory under `create_vm_swtpm_state_dir`.

### noVNC web console

To enable browser-based console access with noVNC:

```yaml
- hosts: hypervisors
  roles:
    - role: basalt.qemu.qemu_host
      vars:
        qemu_host_novnc_enabled: true  # Install novnc package
    - role: basalt.qemu.create_vm
      vars:
        create_vm_vms:
          - name: web01
            disk_size: 40G
            novnc_enabled: true
            novnc_port: 6080  # Optional, auto-assigned if omitted
          - name: db01
            disk_size: 100G
            novnc_enabled: true  # Port auto-assigned (6081 based on VNC display)
```

Access the web console at `http://<host>:6080/vnc.html` (for web01) and `http://<host>:6081/vnc.html` (for db01).

### VM lifecycle operations

Manage VM lifecycle states with the `state` parameter:

```yaml
- hosts: hypervisors
  roles:
    - basalt.qemu.qemu_host
    - role: basalt.qemu.create_vm
      vars:
        create_vm_vms:
          # Create but don't start
          - name: vm01
            disk_size: 20G
            state: present

          # Create and start
          - name: vm02
            disk_size: 20G
            state: started

          # Graceful restart (ACPI shutdown + start)
          - name: vm03
            disk_size: 20G
            state: restarted
            shutdown_timeout: 180  # Wait up to 3 minutes for graceful shutdown

          # Destroy VM and remove all artifacts
          - name: old-vm
            state: absent
            force_destroy: true  # Required safety flag
```

The `restarted` state performs a graceful stop followed by a start. The VM receives an ACPI shutdown signal and is given `shutdown_timeout` seconds to shut down cleanly before being forcefully stopped.

The `absent` state completely removes the VM including disk images, NVRAM, TPM state, and configuration files. This operation requires `force_destroy: true` to prevent accidental data loss.

## License

GPL-3.0-only
