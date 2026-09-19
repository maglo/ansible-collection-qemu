# Ansible Collection — maglo.qemu

[![CI](https://github.com/maglo/ansible-collection-qemu/actions/workflows/ci.yml/badge.svg)](https://github.com/maglo/ansible-collection-qemu/actions/workflows/ci.yml)
[![Docs](https://github.com/maglo/ansible-collection-qemu/actions/workflows/docs.yml/badge.svg)](https://maglo.github.io/ansible-collection-qemu/)
[![Galaxy](https://img.shields.io/badge/galaxy-maglo.qemu-660198)](https://galaxy.ansible.com/ui/repo/published/maglo/qemu/)

QEMU/KVM hosts and virtual machines on Enterprise Linux (RHEL, Rocky, Alma,
CentOS), driven by Ansible and systemd — no libvirtd, no XML, no virsh.

📖 **[Read the documentation](https://maglo.github.io/ansible-collection-qemu/)**

## Why this collection

It is for developers who want repeatable, idempotent QEMU/KVM virtual machines
on an Enterprise Linux box — and nothing more than that. Each VM is one
`qemu-system-*` process, described in a playbook and supervised by a systemd
template unit.

| Principle | Detail |
|-----------|--------|
| **Libvirt-free** | VMs are driven directly by `qemu-system-*` — no libvirtd, no XML, no virsh |
| **Systemd-native** | VM lifecycle is managed via `qemu-vm@<name>.service` template units |
| **Enterprise Linux focused** | Targets RHEL, Rocky, Alma and CentOS 10 exclusively |
| **Minimal footprint** | No heavy infrastructure dependencies; only QEMU and swtpm |

If you want an Ansible-driven, version-controlled alternative to running QEMU
commands by hand — without adopting Proxmox, oVirt or VMware — this collection
is for you.

## Roles

| Role | Description |
|------|-------------|
| [`maglo.qemu.host`](https://github.com/maglo/ansible-collection-qemu/blob/main/roles/host/README.md) | Install QEMU/KVM packages and deploy the systemd template units |
| [`maglo.qemu.vms`](https://github.com/maglo/ansible-collection-qemu/blob/main/roles/vms/README.md) | Create and manage VMs — disk images, UEFI and Secure Boot, TPM, networking, consoles, cloud-init, USB, lifecycle |
| [`maglo.qemu.labview`](https://github.com/maglo/ansible-collection-qemu/blob/main/roles/labview/README.md) | Deploy the labview console service — every VM's framebuffer, serial line and control channel behind one port |

## Requirements

- A host running Enterprise Linux 10 with hardware virtualization enabled.
- The EPEL repository, or a mirror carrying `swtpm`, `socat` and
  `genisoimage`. The collection does not enable EPEL itself.
- `ansible-core` >= 2.15 on the control node.

The [installation
guide](https://maglo.github.io/ansible-collection-qemu/collection/docsite/guide_installation.html)
has the details, including how to check a host for KVM support.

## Installation

```bash
ansible-galaxy collection install maglo.qemu
```

Or add it to a `requirements.yml`:

```yaml
collections:
  - name: maglo.qemu
```

## Quick start

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
            disk_bus: virtio-scsi
            memory: 8G
            cpus: 8
            state: started
```

The `host` role installs the QEMU/KVM packages and the `qemu-vm@.service`
and `swtpm@.service` template units. The `vms` role creates
each disk image, writes `/etc/qemu/vms/<name>.conf` and manages the
`qemu-vm@<name>.service` instance of every VM:

```bash
systemctl status qemu-vm@web01
journalctl -u qemu-vm@web01
```

More playbooks live in [`playbooks/`](https://github.com/maglo/ansible-collection-qemu/tree/main/playbooks/) and in the [example
playbooks
guide](https://maglo.github.io/ansible-collection-qemu/collection/docsite/guide_examples.html).

## Documentation

Everything is on the documentation site:
**<https://maglo.github.io/ansible-collection-qemu/>**

| Page | Contents |
|------|----------|
| [Installation](https://maglo.github.io/ansible-collection-qemu/collection/docsite/guide_installation.html) | Requirements, EPEL, hardware virtualization, supported platforms |
| [Host setup](https://maglo.github.io/ansible-collection-qemu/collection/docsite/guide_host.html) | Preparing a hypervisor: packages, directories, systemd units, SELinux |
| [VM management](https://maglo.github.io/ansible-collection-qemu/collection/docsite/guide_vm_management.html) | Creating, starting, restarting and destroying VMs |
| [Feature guide](https://maglo.github.io/ansible-collection-qemu/collection/docsite/guide_features.html) | Disks, UEFI and Secure Boot, TPM, networking, consoles, cloud-init |
| [Console service](https://maglo.github.io/ansible-collection-qemu/collection/docsite/guide_console_service.html) | Serving every VM console through one service, and the proxy in front of it |
| [Example playbooks](https://maglo.github.io/ansible-collection-qemu/collection/docsite/guide_examples.html) | Ready-to-run playbooks |
| [`host` role reference](https://maglo.github.io/ansible-collection-qemu/collection/host_role.html) | Every `host_*` variable, generated from the role argument spec |
| [`vms` role reference](https://maglo.github.io/ansible-collection-qemu/collection/vms_role.html) | Every `vms_*` variable and per-VM key |
| [`labview` role reference](https://maglo.github.io/ansible-collection-qemu/collection/labview_role.html) | Every `labview_*` variable |
| [CHANGELOG.rst](https://github.com/maglo/ansible-collection-qemu/blob/main/CHANGELOG.rst) | Release notes |

Offline, `ansible-doc -t role maglo.qemu.host` and `ansible-doc -t role
maglo.qemu.vms` print the same variable reference, and each role keeps a
[`README.md`](https://github.com/maglo/ansible-collection-qemu/tree/main/roles/) next to its code.

## Contributing

Contributions are welcome. See [CONTRIBUTING.md](https://github.com/maglo/ansible-collection-qemu/blob/main/CONTRIBUTING.md) for the
development setup, the tests, and how to build the documentation site locally.

## License

GPL-3.0-only

## AI Assistance

This collection was developed with AI assistance. AI tools were used for issue
triage, architecture decisions, engineering, and release practices. Human
intervention was limited to **reviewing, commenting, and merging**
contributions.

AI tools used:

- [Grok](https://x.ai) (xAI)
- [OpenAI Codex](https://openai.com/codex)
- [Claude](https://claude.ai) (Anthropic)
