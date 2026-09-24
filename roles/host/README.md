# maglo.qemu.host

> 📖 Full documentation, including the guides and the generated variable
> reference, is at
> <https://maglo.github.io/ansible-collection-qemu/>.

Install and configure a QEMU/KVM host on Enterprise Linux (RHEL, Rocky, Alma, CentOS).

The role:

- installs the QEMU/KVM packages listed in `host_packages`;
- creates the VM config and image directories;
- deploys the `qemu-vm@.service` and `swtpm@.service` systemd template units;
- compiles and installs a small SELinux policy module when SELinux is enforcing.

It sets up the host only. The per-VM instances of both template units are managed by the `maglo.qemu.vms` role.

## Requirements

- Ansible >= 2.15
- Target hosts running Enterprise Linux 10
- **EPEL** (or equivalent mirror) enabled on the target host — several packages installed by this role (`swtpm`, `swtpm-tools`, `socat` and `genisoimage`) are only available from EPEL. The collection intentionally does not manage EPEL setup to support airgapped deployments.

## Role Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `host_packages` | `[qemu-kvm, qemu-img, swtpm, swtpm-tools, socat, genisoimage, edk2-ovmf]` | Packages to install for the QEMU/KVM host |
| `host_vm_config_dir` | `/etc/qemu/vms` | Directory containing VM configuration files, one `.conf` per VM (must match `vms_vm_config_dir`) |
| `host_vm_image_dir` | `/var/lib/qemu/images` | Directory containing VM disk images (must match `vms_image_dir`) |
| `host_service_user` | `qemu` | User for the QEMU systemd service |
| `host_service_group` | `qemu` | Group for the QEMU systemd service |
| `host_vm_umask` | `0007` | Umask of the `qemu-vm@.service` units, and so the mode of every socket QEMU creates: `0770` rather than systemd's `0755` |
| `host_labview_enabled` | `true` | Install and run the labview console service |
| `host_labview_version` | `0.2.0` | Release of labview to install |
| `host_labview_arch` | `null` | Architecture suffix of the release asset. Derived from `ansible_architecture` when unset |
| `host_labview_binary_url` | the release asset | Where the binary comes from |
| `host_labview_checksum` | the release `SHA256SUMS` | Checksum, in the form `get_url` takes. `null` downloads without verifying |
| `host_labview_binary_path` | `/usr/local/bin/labview` | Where the binary is installed |
| `host_labview_user` / `host_labview_group` | `labview` | The service account. Never `root` — see below |
| `host_labview_qemu_group` | `{{ host_service_group }}` | Group of the QEMU sockets, joined as a supplementary group |
| `host_labview_state_dir` | `/var/lib/labview` | Base directory for everything labview writes |
| `host_labview_recordings_dir` | `<state_dir>/recordings` | Serial transcripts, one per machine per run |
| `host_labview_screenshot_dir` | `<state_dir>/screenshots` | Screenshot exchange, shared with QEMU |
| `host_labview_inventory_dir` | `/etc/labview/inventory.d` | Per-machine inventory files. Must match `vms_labview_inventory_dir` |
| `host_labview_listen` | `127.0.0.1:8080` | Address labview serves on |
| `host_labview_host_access` | `local` | Host introspection: `local`, `none` or `fake` |
| `host_labview_identity_header` | `X-Forwarded-User` | Header carrying the identity a proxy authenticated |
| `host_labview_extra_args` | `[]` | Extra arguments appended to `ExecStart` verbatim |
| `host_labview_polkit_rule_path` | `/etc/polkit-1/rules.d/50-labview-units.rules` | Where the polkit rule is installed |
| `host_labview_unit_pattern` | `^qemu-vm@[A-Za-z0-9._-]+\.service$` | Units labview may start, stop and restart |
| `host_labview_service_state` | `started` | State to leave `labview.service` in |
| `host_swtpm_state_dir` | `/var/lib/swtpm` | Base directory for per-VM swtpm state, read by the `swtpm@.service` template (must match `vms_swtpm_state_dir`) |

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

## The labview console service

The role installs and runs [labview](https://github.com/maglo/qemu-lab-manager), which serves the framebuffer, serial line and control channel of every machine behind one port. Preparing a hypervisor to run it is host setup, which is why it lives here beside the QEMU packages and the template units.

Point the `vms` role at the same directory so that it writes the per-machine inventory the service reads:

```yaml
- hosts: hypervisors
  roles:
    - role: maglo.qemu.host
    - role: maglo.qemu.vms
      vars:
        vms_labview_inventory_dir: /etc/labview/inventory.d   # host_labview_inventory_dir
        vms_list:
          - name: web01
            disk_size: 20G
            state: started
```

`host_labview_enabled: false` turns it off — for a host with no outbound network for the download, for instance.

### The binary

labview ships as a statically linked binary on each release of `maglo/qemu-lab-manager`. There is no container image and no package, so the role downloads the release asset and verifies it against the `SHA256SUMS` published beside it. `get_url` fetches that file and matches the entry whose name is the basename of `host_labview_binary_url`. Upgrading is one variable:

```yaml
host_labview_version: "0.3.0"
```

The default trusts a checksum file served from the same place as the binary, which protects against a corrupted download rather than a compromised release. Pin a literal digest to do better. With `host_labview_checksum: null` there is nothing to compare, so an existing binary is left alone and a version bump does **not** replace it.

### Why not root

The polkit rule is what lets labview start, stop and restart a VM, and it is mandatory. A system service has no logind session, so polkit evaluates a power operation as neither local nor active, falls through to `auth_admin`, and finds no agent to answer the prompt. Every power operation then fails, in a way that reads as a labview fault rather than a missing rule.

Running labview as root would hide that rather than fix it: systemd short-circuits the privilege check for a root caller, so polkit never runs and the rule bounds nothing.

Two layers have to agree before a machine is restarted. labview maps a machine to a unit through the inventory, so it can only ask about units the inventory named; the rule is the host's own opinion about which units that account may touch. Narrow `host_labview_unit_pattern` to bound labview to part of a hypervisor:

```yaml
host_labview_unit_pattern: '^qemu-vm@lab-[A-Za-z0-9._-]+\.service$'
```

### Putting a proxy in front

`host_labview_listen` is `127.0.0.1:8080`, and the role warns when it is set to anything that is not loopback. labview performs no authentication: whoever reaches it holds the write lease of every machine.

Whatever proxy terminates TLS and authenticates, three things are not optional, and each fails in a way that looks like a labview bug:

1. **Forward the original `Host` header.** labview's websocket origin check compares `Origin` against `Host`. A proxy that rewrites `Host` to `127.0.0.1:8080` makes every websocket look cross-origin.
2. **Set the identity header on the websocket upgrade too.** `host_labview_identity_header` is the only thing naming the lease holder; set on plain HTTP alone, no lease ever matches and nobody can type.
3. **Discard any client-supplied identity header.** labview trusts it completely — it is the only thing in the audit trail.

The [console service guide](../../docs/docsite/rst/guide_console_service.rst) covers the shape and the reasoning.

### Directories

| Directory | Owner | Mode | Why |
|-----------|-------|------|-----|
| `host_labview_state_dir` | `labview:labview` | `0750` | Everything labview writes, and the only path the unit makes writable |
| `host_labview_recordings_dir` | `labview:labview` | `0750` | Serial transcripts |
| `host_labview_screenshot_dir` | `labview:qemu` | `02770` | Shared with QEMU: QEMU writes a frame as its own user, labview reads it and removes it. Group writable so QEMU can create the file, setgid so the frame stays in a group labview can read |
| `host_labview_inventory_dir` | `root:root` | `0755` | Written by the `vms` role. The `host` role creates it with the same owner and mode, so a hypervisor with no VMs yet still starts the service |

### Where guest boot output went

A VM's serial console is a socket rather than stdout, so it no longer reaches the journal of `qemu-vm@<name>.service`. labview records a transcript per run in `host_labview_recordings_dir` instead. A consumer who read guest boot output with `journalctl -u qemu-vm@<name>` reads the transcript now, or watches the serial tab.

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

## Managing VMs

The role deploys these systemd template units:

- **`qemu-vm@.service`** — the QEMU VM itself.
- **`swtpm@.service`** — the software TPM 2.0 emulator, used by a VM with `tpm: true`.

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
