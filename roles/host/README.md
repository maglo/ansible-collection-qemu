# maglo.qemu.host

> 📖 Full documentation, including the guides and the generated variable
> reference, is at
> <https://maglo.github.io/ansible-collection-qemu/>.

Install and configure a QEMU/KVM host on Enterprise Linux (RHEL, Rocky, Alma, CentOS).

The role:

- installs the QEMU/KVM packages listed in `host_packages`;
- creates the VM config and image directories;
- deploys the `qemu-vm@.service` and `swtpm@.service` systemd template units;
- deploys the `novnc@.service` template unit and installs the `novnc` package when `host_novnc_enabled` is true;
- compiles and installs a small SELinux policy module when SELinux is enforcing.

It sets up the host only. The per-VM instances of all three template units are managed by the `maglo.qemu.vms` role.

## Requirements

- Ansible >= 2.15
- Target hosts running Enterprise Linux 10
- **EPEL** (or equivalent mirror) enabled on the target host — several packages installed by this role (`swtpm`, `swtpm-tools`, `socat`, `genisoimage`, and optionally `novnc`) are only available from EPEL. The collection intentionally does not manage EPEL setup to support airgapped deployments.

## Role Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `host_packages` | `[qemu-kvm, qemu-img, swtpm, swtpm-tools, socat, genisoimage, edk2-ovmf]` | Packages to install for the QEMU/KVM host |
| `host_vm_config_dir` | `/etc/qemu/vms` | Directory containing VM configuration files, one `.conf` per VM (must match `vms_vm_config_dir`) |
| `host_vm_image_dir` | `/var/lib/qemu/images` | Directory containing VM disk images (must match `vms_image_dir`) |
| `host_service_user` | `qemu` | User for the QEMU systemd service |
| `host_service_group` | `qemu` | Group for the QEMU systemd service |
| `host_vm_umask` | `0007` | Umask of the `qemu-vm@.service` units, and so the mode of every socket QEMU creates: `0770` rather than systemd's `0755` |
| `host_swtpm_state_dir` | `/var/lib/swtpm` | Base directory for per-VM swtpm state, read by the `swtpm@.service` template (must match `vms_swtpm_state_dir`) |
| `host_novnc_enabled` | `false` | Install the noVNC package from EPEL and deploy the `novnc@.service` systemd template (per-VM service instances managed by `maglo.qemu.vms` role) |

The three "must match" variables above have a counterpart in the `vms` role. The template units read the `host_*` value, and the `vms` role writes to the `vms_*` value. Change one and you must change the other, or the units will look for files that the `vms` role never wrote.

### Which package each feature needs

`host_packages` is a full replacement, not an addition. Dropping a package from the list disables the feature that needs it:

| Package | Needed for |
|---------|------------|
| `qemu-kvm`, `qemu-img` | Everything |
| `edk2-ovmf` | UEFI and Secure Boot VMs. `vms_default_uefi` is `true`, so this is the default path |
| `swtpm`, `swtpm-tools` | `tpm: true` |
| `genisoimage` | The cloud-init seed ISO |
| `socat` | The graceful guest shutdown used by `state: restarted` and `state: absent` |

## Socket permissions

QEMU creates the serial and QMP sockets of a VM itself, at start, and never chmods them. Their mode is therefore `0777` minus the umask of the unit, and systemd's default umask of `0022` leaves each socket at `0755`.

That is not usable by anything but the `qemu` user. Connecting to a UNIX socket needs the **write** bit, so `0755` refuses even a member of `host_service_group`:

```console
$ sudo -u labview socat - UNIX-CONNECT:/var/lib/qemu/web01/serial.sock
socat: E connect(...): Permission denied
```

`host_vm_umask` is `0007`, which leaves the sockets at `0770`. A console service that runs under its own account in the `qemu` group can then attach to the serial line and the QMP socket, and nothing outside the group can — which is narrower than the `0755` of earlier releases, not wider.

The mode is fixed when QEMU creates the socket, so a VM that is already running keeps the socket it started with. Restart the VMs to pick the new mode up:

```yaml
- hosts: hypervisors
  roles:
    - role: maglo.qemu.vms
      vars:
        vms_list:
          - name: web01
            state: restarted
```

Set `host_vm_umask: "0022"` to keep the previous behaviour. Quote the value: an unquoted `0022` is an integer in YAML, and the unit needs the literal digits.

## SELinux

`qemu-vm@.service` runs as `init_t`, which is not allowed to execute `/usr/libexec/qemu-kvm` or `/usr/bin/swtpm`. When `getenforce` reports `Enforcing`, the role installs `checkpolicy` and `policycoreutils`, compiles the policy module in `files/selinux/qemu_vm.te`, and loads it. The step is skipped when SELinux is permissive or disabled.

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

The role deploys these systemd template units:

- **`qemu-vm@.service`** — the QEMU VM itself.
- **`swtpm@.service`** — the software TPM 2.0 emulator, used by a VM with `tpm: true`.
- **`novnc@.service`** — the noVNC websocket proxy, deployed only when `host_novnc_enabled` is true.

Each VM is described by one file in `host_vm_config_dir` (`/etc/qemu/vms` by default). The unit reads it as an `EnvironmentFile` and passes `$QEMU_ARGS` to `/usr/libexec/qemu-kvm`. The instance name after `@` is the file name without the extension.

Use the `maglo.qemu.vms` role to write these files. It generates the full argument list, including the UEFI pflash drives and the monitor socket that the graceful shutdown path needs, and it overwrites `<name>.conf` on every run.

A hand-written file is only for a VM that the `vms` role does not manage. The minimum is:

```bash
cat > /etc/qemu/vms/myvm.conf <<'EOF'
QEMU_ARGS="-m 2048 -smp 2 -drive file=/var/lib/qemu/images/myvm.qcow2,format=qcow2 -vnc :1"
EOF

systemctl enable --now qemu-vm@myvm
```

Note what this minimal example leaves out: no UEFI firmware, and no `-monitor` socket, so `systemctl stop` sends SIGTERM to QEMU instead of asking the guest to power down.

**systemd splits `$QEMU_ARGS` at each space** and does not interpret quotation marks inside the value, so no single argument may contain a space. Where a value can, pass it to QEMU in a file — this is why the `vms` role writes SMBIOS OEM strings to files.

## License

GPL-3.0-only
