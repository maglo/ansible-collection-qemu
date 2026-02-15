# basalt.qemu.qemu_host

Install and configure a QEMU/KVM host on Enterprise Linux (RHEL, Rocky, Alma, CentOS).

The role installs QEMU/KVM packages, deploys a systemd template unit for managing VMs, and optionally sets up noVNC for browser-based console access.

## Requirements

- Ansible >= 2.15
- Target hosts running Enterprise Linux 9 or 10

## Role Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `qemu_host_packages` | `[qemu-kvm, qemu-img, libvirt, swtpm, swtpm-tools]` | Packages to install for QEMU/KVM host |
| `qemu_host_libvirtd_enabled` | `true` | Whether to enable and start libvirtd |
| `qemu_host_vm_config_dir` | `/etc/qemu/vms` | Directory containing VM configuration files (one `.conf` per VM) |
| `qemu_host_vm_image_dir` | `/var/lib/qemu/images` | Directory containing VM disk images |
| `qemu_host_service_user` | `qemu` | User for the QEMU systemd service |
| `qemu_host_service_group` | `qemu` | Group for the QEMU systemd service |
| `qemu_host_novnc_enabled` | `false` | Enable noVNC deployment |
| `qemu_host_novnc_install_dir` | `/opt/noVNC` | noVNC installation directory |
| `qemu_host_novnc_version` | `v1.5.0` | noVNC release tag to install |
| `qemu_host_novnc_vms` | `[]` | List of VMs to create noVNC proxy instances for (see below) |

Each entry in `qemu_host_novnc_vms` creates a `novnc@<name>.service` systemd instance:

| Key | Required | Description |
|-----|----------|-------------|
| `name` | yes | VM name (matches `qemu-vm@<name>.service`) |
| `novnc_port` | yes | Port the noVNC websocket proxy listens on |
| `vnc_target` | yes | VNC backend address (e.g. `localhost:5900`) |

## Dependencies

None.

## Example Playbook

Basic usage:

```yaml
- hosts: hypervisors
  roles:
    - basalt.qemu.qemu_host
```

With noVNC enabled for two VMs:

```yaml
- hosts: hypervisors
  roles:
    - role: basalt.qemu.qemu_host
      vars:
        qemu_host_novnc_enabled: true
        qemu_host_novnc_vms:
          - name: web01
            novnc_port: 6080
            vnc_target: localhost:5900
          - name: db01
            novnc_port: 6081
            vnc_target: localhost:5901
```

## Managing VMs

The role deploys a `qemu-vm@.service` systemd template unit. Each VM is defined by a configuration file in `qemu_host_vm_config_dir` (`/etc/qemu/vms` by default) that sets `QEMU_ARGS`:

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
