# basalt.qemu.create_vm

Create QEMU/KVM virtual machine disk images on an Enterprise Linux host.

The role creates qcow2 (or raw) disk images for each VM defined in `create_vm_vms`, sets the correct ownership and permissions, and is idempotent (existing images are not recreated).

## Requirements

- Ansible >= 2.15
- Target hosts running Enterprise Linux 8 or 9

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

### VM definition

Each entry in `create_vm_vms` is a dictionary with the following keys:

| Key | Required | Default | Description |
|-----|----------|---------|-------------|
| `name` | yes | — | VM name, used as the disk image filename |
| `disk_size` | no | `create_vm_default_disk_size` | Disk image size (e.g. `20G`, `100G`) |
| `disk_format` | no | `create_vm_default_disk_format` | Disk format (`qcow2` or `raw`) |
| `uefi` | no | `create_vm_default_uefi` | Whether to enable UEFI boot for this VM |
| `tpm` | no | `create_vm_default_tpm` | Enable TPM 2.0 emulation via swtpm |

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
          - name: db01
            disk_size: 100G
            disk_format: raw
          - name: worker01
            uefi: false
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
