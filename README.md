# Ansible Collection — basalt.qemu

![CI](https://github.com/maglo/ansible-collection-qemu/actions/workflows/ci.yml/badge.svg)

Ansible collection for managing QEMU/KVM hosts on Enterprise Linux (RHEL, Rocky, Alma, CentOS).

## Included Roles

| Role | Description |
|------|-------------|
| [`basalt.qemu.qemu_host`](roles/qemu_host/README.md) | Install QEMU/KVM packages, deploy a systemd template unit for VMs, and optionally set up noVNC |
| [`basalt.qemu.create_vm`](roles/create_vm/README.md) | Create QEMU/KVM virtual machine disk images |

## Supported Platforms

| Platform | Versions |
|----------|----------|
| Enterprise Linux (RHEL, Rocky, Alma, CentOS) | 8, 9 |

**Ansible compatibility:** >= 2.15

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

### Set up the host and create VM disk images

```yaml
- hosts: hypervisors
  become: true
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
            uefi: false
```

`qemu_host` installs QEMU/KVM packages and deploys the `qemu-vm@.service` systemd
template unit. `create_vm` then creates a disk image (qcow2 by default) for each
VM and, when UEFI is enabled (the default), copies per-VM OVMF NVRAM files.

### Manage VMs with systemd

After both roles have run, write a configuration file for each VM and start it
through the systemd template unit:

```bash
cat > /etc/qemu/vms/myvm.conf <<'EOF'
QEMU_ARGS="-m 2048 -smp 2 -drive file=/var/lib/qemu/images/myvm.qcow2,format=qcow2 -vnc :1"
EOF

systemctl start qemu-vm@myvm
systemctl enable qemu-vm@myvm
```

See the [example playbooks](playbooks/) for more usage patterns.

## Contributing

Contributions are welcome! See [CONTRIBUTING.md](CONTRIBUTING.md) for development setup, testing, and workflow guidelines.

## License

GPL-3.0-only
