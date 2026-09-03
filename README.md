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
| [`maglo.qemu.host`](https://github.com/maglo/ansible-collection-qemu/blob/main/roles/host/README.md) | Install QEMU/KVM packages, deploy systemd template units for VMs, and optionally set up noVNC |
| [`maglo.qemu.vms`](https://github.com/maglo/ansible-collection-qemu/blob/main/roles/vms/README.md) | Create and manage QEMU/KVM virtual machines — disk images, UEFI, TPM, networking, noVNC, USB, and lifecycle |

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

### Package repositories

The `maglo.qemu.host` role installs packages (`swtpm`, `swtpm-tools`, `socat`, and optionally `novnc`) that are only available from **EPEL** (Extra Packages for Enterprise Linux). Ensure EPEL — or an equivalent mirror — is enabled on the target host before running the collection:

```bash
dnf install epel-release
```

> **Note:** The collection intentionally does not manage EPEL setup. Automatically enabling EPEL is unsuitable for airgapped or restricted environments. Enable EPEL yourself or point your hosts at a compatible mirror.

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
- **Disk bus:** `virtio-blk` by default. Set `disk_bus: virtio-scsi` per VM to attach the disk through a `virtio-scsi-pci` controller, which is the bus that production images usually use. The cloud-init seed ISO stays on virtio-blk

### UEFI firmware

- UEFI boot with OVMF firmware, enabled by default
- Per-VM writable NVRAM (`OVMF_VARS.fd`) copied automatically
- **Secure Boot**: Enable per VM with `secure_boot: true` — uses `OVMF_CODE.secboot.fd` with pre-enrolled Microsoft/OVMF keys and SMM
- **Custom variable store**: Give one VM its own template with `nvram_template: /path/to/OVMF_VARS.fd` — for example a store that holds your own PK, KEK and db keys. The other VMs on the host keep the global template
- **NVRAM reset**: Increase `nvram_generation` to write the NVRAM file again from the template. The role also writes it again when `secure_boot`, the template path, or the content of the template changes. The role never rewrites the file otherwise, so UEFI boot entries that the guest writes survive a converge
- **Verification**: Set `vms_nvram_verify: true` to assert that the variable store of each Secure Boot VM holds a PK, a KEK and a db, and that Secure Boot is enabled. A store without a PK is in Setup Mode, and a VM with such a store boots an unsigned artifact without a complaint. Add `nvram_expected_db_cn` per VM to also assert a certificate in the db. The check needs `virt-fw-vars` from `python3-virt-firmware` (EPEL on EL9); the role reports a skip when the command is absent

  `SecureBoot` and `SetupMode` are volatile variables that the firmware creates at boot, so an offline check cannot read them. An enrolled PK is the offline equivalent of `SetupMode=0`
- Disable per VM with `uefi: false`

### SMBIOS OEM strings

- Pass a list of SMBIOS type 11 OEM strings to a VM with `smbios_oem_strings`
- `systemd-stub` reads these strings, so they add to the command line of a UKI without a rebuild and a new signature:

  ```yaml
  smbios_oem_strings:
    - "io.systemd.stub.kernel-cmdline-extra=rd.debug systemd.log_level=debug"
  ```

- The role writes each string to its own file and passes it with `-smbios type=11,path=...`, so a string may contain spaces
- The files are mode `0600` and belong to the QEMU user. An OEM string can hold a secret, and the `path=` form keeps it out of the command line, where `ps` would show it to every user. Deleting the key from `vms_list` removes the files
- **A change takes effect at the next boot of the VM.** The firmware reads the strings once. The role does not restart a running VM, so restart it yourself to pick up a new string
- `systemd-stub` ignores these strings under confidential computing, and they measure into PCR 12
- OpenStack Nova has no equivalent knob. This feature is a convenience of this collection only

### TPM 2.0 emulation

- Software TPM via `swtpm`, managed as `swtpm@<name>.service`
- Per-VM state directories under `/var/lib/swtpm/`
- Systemd dependency ensures swtpm starts before QEMU
- Enable per VM with `tpm: true`
- **TPM reset**: TPM state is persistent. Sealed key slots, persistent handles and the PCR history survive a rebuild of the VM. Increase `tpm_generation` to clear `/var/lib/swtpm/<name>`. The role stops the VM and swtpm first, and starts them again afterwards

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

### Cloud-init / configuration drive

- Auto-generate a NoCloud seed ISO from inline per-VM content (`cloud_init_user_data`, `cloud_init_meta_data`, `cloud_init_network_config`)
- ISO is placed automatically at `vms_image_dir/<name>-seed.iso` and attached as a virtio CD-ROM
- `meta-data` is auto-generated from the VM name when `cloud_init_meta_data` is omitted
- Requires `genisoimage` or `xorriso` on the host; guest image must have `cloud-init` installed

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
| `vms_default_disk_bus` | `virtio-blk` | Default disk bus (`virtio-blk` or `virtio-scsi`) |
| `vms_default_secure_boot` | `false` | UEFI Secure Boot by default |
| `vms_nvram_verify` | `false` | Verify the variable store of each Secure Boot VM |
| `vms_nvram_force_reset` | `false` | Write the NVRAM file of every VM again (command line only) |
| `vms_tpm_force_reset` | `false` | Clear the swtpm state of every TPM VM (command line only) |
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
| `secure_boot` | no | `vms_default_secure_boot` | UEFI Secure Boot |
| `disk_bus` | no | `vms_default_disk_bus` | Disk bus: `virtio-blk` or `virtio-scsi` |
| `nvram_template` | no | global template | UEFI variable store template for this VM only |
| `nvram_generation` | no | `1` | Increase to write the NVRAM file again |
| `nvram_expected_db_cn` | no | — | Subject CN that the db must hold |
| `smbios_oem_strings` | no | — | List of SMBIOS type 11 OEM strings |
| `tpm_generation` | no | `1` | Increase to clear the swtpm state of this VM |
| `tpm` | no | `vms_default_tpm` | TPM 2.0 emulation |
| `net_mode` | no | `vms_default_net_mode` | `user` or `bridge` |
| `net_bridge` | no | `br0` | Bridge device (bridge mode) |
| `mac_address` | no | auto | MAC address override |
| `memory` | no | `vms_default_memory` | Memory (e.g. `4G`) |
| `cpus` | no | `vms_default_cpus` | Number of vCPUs |
| `vnc` | no | hash-based | VNC display number |
| `usb_disk_image` | no | — | Path to USB image to attach |
| `usb_boot_priority` | no | `true` | Boot USB first |
| `cloud_init_user_data` | no | — | cloud-init `user-data` content; triggers seed ISO generation |
| `cloud_init_meta_data` | no | auto-generated | cloud-init `meta-data` content |
| `cloud_init_network_config` | no | — | cloud-init `network-config` content |
| `novnc_enabled` | no | `false` | Enable noVNC web console |
| `novnc_port` | no | `6080 + vnc` | noVNC port |
| `state` | no | `present` | Service state |
| `force_destroy` | no | `false` | Required for `state: absent` |
| `shutdown_timeout` | no | `120` | Graceful shutdown timeout |

## Example Playbooks

See the [example playbooks](https://github.com/maglo/ansible-collection-qemu/tree/main/playbooks/) directory for ready-to-use examples:

| Playbook | Description |
|----------|-------------|
| [`basic_host.yml`](https://github.com/maglo/ansible-collection-qemu/blob/main/playbooks/basic_host.yml) | Minimal host setup |
| [`vms.yml`](https://github.com/maglo/ansible-collection-qemu/blob/main/playbooks/vms.yml) | Host setup + basic VM creation |
| [`vms_with_novnc.yml`](https://github.com/maglo/ansible-collection-qemu/blob/main/playbooks/vms_with_novnc.yml) | Host + VMs with noVNC enabled |

## Contributing

Contributions are welcome! See [CONTRIBUTING.md](https://github.com/maglo/ansible-collection-qemu/blob/main/CONTRIBUTING.md) for development setup, testing, and workflow guidelines.

## License

GPL-3.0-only

## AI Assistance

This collection was developed with AI assistance. AI tools were used for issue triage, architecture decisions, engineering, and release practices. Human intervention was limited to **reviewing, commenting, and merging** contributions.

AI tools used:
- [Grok](https://x.ai) (xAI)
- [OpenAI Codex](https://openai.com/codex)
- [Claude](https://claude.ai) (Anthropic)
