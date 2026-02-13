# Ansible Collection — basalt.qemu

Ansible collection for managing QEMU/KVM hosts on Enterprise Linux (RHEL, Rocky, Alma, CentOS).

## Included Roles

| Role | Description |
|------|-------------|
| `basalt.qemu.qemu_host` | Install QEMU/KVM packages, deploy a systemd template unit for VMs, and optionally set up noVNC |

## Requirements

- Ansible >= 2.15
- Target hosts running Enterprise Linux 8 or 9

## Installation

```bash
ansible-galaxy collection install basalt.qemu
```

Or add to `requirements.yml`:

```yaml
collections:
  - name: basalt.qemu
```

## Quick Start

```yaml
- hosts: hypervisors
  roles:
    - role: basalt.qemu.qemu_host
      vars:
        qemu_host_novnc_enabled: true
```

After the role runs, manage individual VMs with the systemd template unit:

```bash
# Create a VM config file
cat > /etc/qemu/vms/myvm.conf <<'EOF'
QEMU_ARGS="-m 2048 -smp 2 -drive file=/var/lib/qemu/images/myvm.qcow2,format=qcow2 -vnc :1"
EOF

# Start the VM
systemctl start qemu-vm@myvm
systemctl enable qemu-vm@myvm
```

## Role Variables

See [`roles/qemu_host/defaults/main.yml`](roles/qemu_host/defaults/main.yml) for the full list of configurable variables.

## License

GPL-3.0-only
