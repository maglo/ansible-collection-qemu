# Ansible Collection — maglo.qemu

![CI](https://github.com/maglo/ansible-collection-qemu/actions/workflows/ci.yml/badge.svg)

Ansible collection for managing QEMU/KVM hosts and virtual machines on Enterprise Linux (RHEL, Rocky, Alma, CentOS).

## Use Case

This collection is for **developers** who need repeatable, idempotent provisioning of QEMU/KVM virtual machines on Enterprise Linux hosts — without the overhead of a full virtualization management stack.

### Design philosophy

| Principle | Detail |
|-----------|--------|
| **Libvirt-free** | VMs are driven directly by `qemu-system-*` — no libvirtd, no XML, no virsh |
| **Systemd-native** | VM lifecycle is managed via `qemu-vm@<name>.service` template units |
| **Enterprise Linux focused** | Targets RHEL, Rocky, Alma, and CentOS 9+ exclusively |
| **Minimal footprint** | No heavy infrastructure dependencies; only QEMU, swtpm, and optionally noVNC |

If you need an Ansible-driven, version-controlled alternative to manually running QEMU commands or heavyweight platforms (Proxmox, oVirt, VMware), this collection is for you.

## Included Roles

| Role | Description |
|------|-------------|
| [`maglo.qemu.host`](roles/host/README.md) | Install QEMU/KVM packages, deploy systemd template units for VMs, and optionally set up noVNC |
| [`maglo.qemu.vms`](roles/vms/README.md) | Create and manage QEMU/KVM virtual machines — disk images, UEFI, TPM, networking, noVNC, USB, and lifecycle |

## Supported Platforms

| Platform | Versions |
|----------|----------|
| Enterprise Linux (RHEL, Rocky, Alma, CentOS) | 9, 10 |

**Ansible compatibility:** >= 2.15

## Installation

```bash
ansible-galaxy collection install maglo.qemu
```

Or add to `requirements.yml`:

```yaml
collections:
  - name: maglo.qemu
```

## Prerequisites

### Verify hardware virtualization

Before running the collection, confirm that your target host supports KVM hardware virtualization:

```bash
# Must return a non-zero number
grep -c -E '(vmx|svm)' /proc/cpuinfo

# Alternatively, check for the KVM kernel module
lsmod | grep kvm
```

If the command returns `0` or the module is missing, check your BIOS/UEFI settings and ensure Intel VT-x / AMD-V is enabled. Nested virtualization (VMs inside VMs) also requires this flag to be exposed to the guest.

## Quick Start

### Set up the host and create VMs

```yaml
- hosts: hypervisors
  become: true
  roles:
    - maglo.qemu.host
    - role: maglo.qemu.vms
      vars:
        vms_list:
          - name: web01
            disk_size: 40G
            memory: 4G
            cpus: 4
            state: started
          - name: db01
            disk_size: 100G
            disk_format: raw
            memory: 8G
            cpus: 8
            state: started
          - name: installer
            disk_size: 40G
            usb_disk_image: /var/lib/qemu/images/installer.iso
            usb_boot_priority: true
```

The `host` role installs QEMU/KVM packages and deploys the `qemu-vm@.service` and `swtpm@.service` systemd template units. The `vms` role creates a disk image (qcow2 by default) and, when UEFI is enabled (the default), copies per-VM OVMF NVRAM files, then manages the `qemu-vm@<name>.service` instance.

### Manage VMs with systemd

VMs are managed as `qemu-vm@<name>.service` instances. The `vms` role writes a `.conf` file for each VM containing QEMU arguments, and manages the service state. You can also manage VMs manually:

```bash
systemctl start qemu-vm@web01
systemctl enable qemu-vm@web01
systemctl status qemu-vm@web01
```

## Feature Overview

### Disk image management

- **Blank disks:** qcow2 (default) or raw format with configurable size
- **URL-provisioned images:** Download a cloud image (QCOW2) from a URL and use it as a backing file; multiple VMs share the same cached base image (copy-on-write)
- **Checksum verification:** Optional SHA256 checksum validation for downloaded images
- **Idempotent:** Existing images are never recreated

### UEFI firmware

- UEFI boot with OVMF firmware, enabled by default
- Per-VM writable NVRAM (`OVMF_VARS.fd`) copied automatically
- Disable per VM with `uefi: false`

### TPM 2.0 emulation

- Software TPM via `swtpm`, managed as `swtpm@<name>.service`
- Per-VM state directories under `/var/lib/swtpm/`
- Systemd dependency ensures swtpm starts before QEMU
- Enable per VM with `tpm: true`

### Networking

- **User mode (default):** NAT outbound connectivity via SLIRP, no host configuration needed
- **Bridge mode:** Attach to a host bridge (`br0` or custom) via `qemu-bridge-helper`
- **MAC addresses:** Deterministic hash-based generation (QEMU OUI `52:54:00`) or manual override

### VNC console

- Every VM gets a VNC console; display number is deterministic (hash of VM name mod 100)
- Override with `vnc: N` per VM; port = 5900 + N

### noVNC web console

- HTML5 browser-based VNC client, no client software needed
- Managed as `novnc@<name>.service` per VM
- Port auto-assigned as `6080 + VNC display number`, or override with `novnc_port`
- Requires `host_novnc_enabled: true` on the host role to install the `novnc` package

```yaml
- role: maglo.qemu.host
  vars:
    host_novnc_enabled: true

- role: maglo.qemu.vms
  vars:
    vms_list:
      - name: web01
        disk_size: 40G
        novnc_enabled: true   # accessible at http://<host>:6080/vnc.html
        state: started
```

### USB disk/ISO attachment

- Attach one pre-provisioned USB image per VM (`.iso`, `.raw`, `.img`, `.qcow2`)
- USB 3.0 XHCI controller emulated
- Boot from USB first with `usb_boot_priority: true`

### VM lifecycle management

| State | Behaviour |
|-------|-----------|
| `present` | Write config only; do not manage the service |
| `started` | Enable and start the service |
| `stopped` | Enable but stop the service |
| `restarted` | Graceful ACPI shutdown then start |
| `absent` | Destroy VM and all artifacts (requires `force_destroy: true`) |

Graceful shutdown sends an ACPI powerdown via the QEMU monitor socket and waits up to `shutdown_timeout` seconds (default: 120) before forcing a stop.

## Key Variables

### `maglo.qemu.host`

| Variable | Default | Description |
|----------|---------|-------------|
| `host_packages` | see defaults | Packages to install |
| `host_libvirtd_enabled` | `true` | Enable and start libvirtd |
| `host_vm_config_dir` | `/etc/qemu/vms` | VM config files directory |
| `host_vm_image_dir` | `/var/lib/qemu/images` | VM disk images directory |
| `host_service_user` | `qemu` | Service user |
| `host_service_group` | `qemu` | Service group |
| `host_swtpm_state_dir` | `/var/lib/swtpm` | swtpm state directory |
| `host_novnc_enabled` | `false` | Install noVNC package and template |

### `maglo.qemu.vms`

| Variable | Default | Description |
|----------|---------|-------------|
| `vms_list` | `[]` | List of VM definitions (see below) |
| `vms_default_disk_size` | `20G` | Default disk size |
| `vms_default_disk_format` | `qcow2` | Default disk format |
| `vms_default_uefi` | `true` | UEFI boot by default |
| `vms_default_tpm` | `false` | TPM emulation by default |
| `vms_default_net_mode` | `user` | Default networking mode |
| `vms_default_memory` | `2G` | Default memory |
| `vms_default_cpus` | `2` | Default CPUs |
| `vms_default_novnc_enabled` | `false` | noVNC by default |
| `vms_default_shutdown_timeout` | `120` | Graceful shutdown timeout (seconds) |
| `vms_image_dir` | `/var/lib/qemu/images` | Disk images directory |
| `vms_image_cache_dir` | `/var/lib/qemu/images/cache` | Downloaded image cache |

### Per-VM keys in `vms_list`

| Key | Required | Default | Description |
|-----|----------|---------|-------------|
| `name` | yes | — | VM name |
| `disk_size` | no | `vms_default_disk_size` | Disk image size |
| `disk_format` | no | `vms_default_disk_format` | `qcow2` or `raw` |
| `disk_image_url` | no | — | URL to a QCOW2 image (creates overlay) |
| `disk_image_checksum` | no | — | `sha256:...` checksum for URL image |
| `uefi` | no | `vms_default_uefi` | UEFI boot |
| `tpm` | no | `vms_default_tpm` | TPM 2.0 emulation |
| `net_mode` | no | `vms_default_net_mode` | `user` or `bridge` |
| `net_bridge` | no | `br0` | Bridge device (bridge mode) |
| `mac_address` | no | auto | MAC address override |
| `memory` | no | `vms_default_memory` | Memory (e.g. `4G`) |
| `cpus` | no | `vms_default_cpus` | Number of vCPUs |
| `vnc` | no | hash-based | VNC display number |
| `usb_disk_image` | no | — | Path to USB image to attach |
| `usb_boot_priority` | no | `true` | Boot USB first |
| `novnc_enabled` | no | `false` | Enable noVNC web console |
| `novnc_port` | no | `6080 + vnc` | noVNC port |
| `state` | no | `present` | Service state |
| `force_destroy` | no | `false` | Required for `state: absent` |
| `shutdown_timeout` | no | `120` | Graceful shutdown timeout |

## Example Playbooks

See the [example playbooks](playbooks/) directory for ready-to-use examples:

| Playbook | Description |
|----------|-------------|
| [`basic_host.yml`](playbooks/basic_host.yml) | Minimal host setup |
| [`vms.yml`](playbooks/vms.yml) | Host setup + basic VM creation |
| [`vms_with_novnc.yml`](playbooks/vms_with_novnc.yml) | Host + VMs with noVNC enabled |

## Contributing

Contributions are welcome! See [CONTRIBUTING.md](CONTRIBUTING.md) for development setup, testing, and workflow guidelines.

## License

GPL-3.0-only

## AI Assistance

This collection was developed with AI assistance. AI tools were used for issue triage, architecture decisions, engineering, and release practices. Human intervention was limited to **reviewing, commenting, and merging** contributions.

AI tools used:
- [Grok](https://x.ai) (xAI)
- [OpenAI Codex](https://openai.com/codex)
- [Claude](https://claude.ai) (Anthropic)
