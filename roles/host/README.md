# maglo.qemu.host

Install and configure a QEMU/KVM host on Enterprise Linux (RHEL, Rocky, Alma, CentOS).

The role installs QEMU/KVM packages, deploys systemd template units for managing VMs (`qemu-vm@.service` and `swtpm@.service`), and optionally installs the noVNC package for browser-based console access. Per-VM noVNC configuration is managed by the `maglo.qemu.vms` role.

## Requirements

- Ansible >= 2.15
- Target hosts running Enterprise Linux 9 or 10

## Role Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `host_packages` | `[qemu-kvm, qemu-img, libvirt, swtpm, swtpm-tools, socat]` | Packages to install for QEMU/KVM host |
| `host_libvirtd_enabled` | `true` | Whether to enable and start libvirtd |
| `host_vm_config_dir` | `/etc/qemu/vms` | Directory containing VM configuration files (one `.conf` per VM) |
| `host_vm_image_dir` | `/var/lib/qemu/images` | Directory containing VM disk images |
| `host_service_user` | `qemu` | User for the QEMU systemd service |
| `host_service_group` | `qemu` | Group for the QEMU systemd service |
| `host_swtpm_state_dir` | `/var/lib/swtpm` | Base directory for per-VM swtpm state (used by `swtpm@.service` template) |
| `host_novnc_enabled` | `false` | Install the noVNC package from EPEL and deploy the `novnc@.service` systemd template (per-VM service instances managed by `maglo.qemu.vms` role) |

## Dependencies

None.

## Example Playbook

Basic usage:

```yaml
- hosts: hypervisors
  roles:
    - maglo.qemu.host
```

With noVNC package installation (for browser-based console access):

```yaml
- hosts: hypervisors
  roles:
    - role: maglo.qemu.host
      vars:
        host_novnc_enabled: true
```

**Note:** This installs the `novnc` package from EPEL and deploys the `novnc@.service` systemd template unit. Per-VM noVNC service instances (`novnc@<vmname>.service`) are enabled by the `maglo.qemu.vms` role when `novnc_enabled: true` is set for a VM.

## Managing VMs

The role deploys two systemd template units:

- **`qemu-vm@.service`** — Main QEMU VM service template
- **`swtpm@.service`** — Software TPM 2.0 emulator service template (used by VMs with TPM enabled)

Each VM is defined by a configuration file in `host_vm_config_dir` (`/etc/qemu/vms` by default) that sets `QEMU_ARGS`:

```bash
cat > /etc/qemu/vms/myvm.conf <<'EOF'
QEMU_ARGS="-m 2048 -smp 2 -drive file=/var/lib/qemu/images/myvm.qcow2,format=qcow2 -vnc :1"
EOF

systemctl start qemu-vm@myvm
systemctl enable qemu-vm@myvm
```

The instance name after `@` corresponds to the `.conf` filename (without the extension).

## License

GPL-3.0-only
