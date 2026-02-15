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
| `state` | no | `present` | Desired service state: `started`, `stopped`, or `present` |

## Service management

The role manages each VM as a `qemu-vm@<name>.service` systemd unit. The per-VM `state` parameter controls the service:

- **`present`** (default) — the config file is written but the service is not managed at all (useful for testing or environments without KVM).
- **`started`** — the service is enabled and started.
- **`stopped`** — the service is enabled but stopped (useful for pre-provisioning).

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

This deploys an `swtpm@.service` systemd template and starts `swtpm@secure-vm.service`, creating a per-VM state directory under `create_vm_swtpm_state_dir`.

## License

GPL-3.0-only
