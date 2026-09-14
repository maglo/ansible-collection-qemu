# maglo.qemu.vms

> 📖 Full documentation, including the guides and the generated variable
> reference, is at
> <https://maglo.github.io/ansible-collection-qemu/>.

Create QEMU/KVM virtual machines on an Enterprise Linux host.

For each VM in `vms_list` the role creates the disk image, the UEFI variable store, the emulated TPM state, the cloud-init seed ISO and the noVNC proxy, writes the QEMU arguments to `/etc/qemu/vms/<name>.conf`, and brings the `qemu-vm@<name>.service` unit to the state the VM asks for.

The role checks the whole list before it changes anything on the host, so a run that cannot finish leaves the host untouched. See [Input validation](#input-validation).

A configuration change is written to the `.conf` file, but it does not restart a running VM. QEMU reads its arguments once at start. Use `state: restarted` to apply a change now.

## Requirements

- Ansible >= 2.15
- Target hosts running Enterprise Linux 10

  This covers the **host**. A VM may run any guest image, including an EL9 one.
- Optional: `virt-fw-vars`, from the package `python3-virt-firmware`, when `vms_nvram_verify` is on. The role reports a skip when the command is absent.

## Dependencies

- No automatic role dependencies.
- Prerequisite: apply `maglo.qemu.host` first (or provide equivalent host setup) so QEMU binaries, directories, and systemd templates exist.

## Role Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `vms_list` | `[]` | List of VMs to create (see below) |
| `vms_default_disk_size` | `20G` | Default disk size when not specified per VM |
| `vms_default_disk_format` | `qcow2` | Default disk format (`qcow2` or `raw`) |
| `vms_default_disk_bus` | `virtio-blk` | Default disk bus (`virtio-blk` or `virtio-scsi`, per-VM override with `disk_bus` key) |
| `vms_image_dir` | `/var/lib/qemu/images` | Directory for disk images (should match `host_vm_image_dir`) |
| `vms_image_cache_dir` | `/var/lib/qemu/images/cache` | Cache directory for downloaded disk images (shared across VMs) |
| `vms_verify_checksums` | `true` | Whether to compare the per-VM `disk_image_checksum` against the downloaded image |
| `vms_service_user` | `qemu` | Owner of the created disk images |
| `vms_service_group` | `qemu` | Group of the created disk images |
| `vms_default_uefi` | `true` | Whether VMs default to UEFI boot when not specified per VM |
| `vms_ovmf_code` | `/usr/share/edk2/ovmf/OVMF_CODE.fd` | Path to the OVMF firmware code file |
| `vms_ovmf_vars_template` | `/usr/share/edk2/ovmf/OVMF_VARS.fd` | Path to the OVMF vars template (copied per VM) |
| `vms_default_secure_boot` | `false` | Whether VMs default to UEFI Secure Boot (per-VM override with `secure_boot` key) |
| `vms_ovmf_code_secboot` | `/usr/share/edk2/ovmf/OVMF_CODE.secboot.fd` | Path to OVMF Secure Boot firmware code file |
| `vms_ovmf_vars_secboot_template` | `/usr/share/edk2/ovmf/OVMF_VARS.secboot.fd` | Path to OVMF Secure Boot vars template (pre-enrolled keys) |
| `vms_nvram_verify` | `false` | Verify the variable store of each Secure Boot VM (needs `virt-fw-vars`) |
| `vms_nvram_force_reset` | `false` | Write the NVRAM file of every VM again from its template. Command-line escape hatch only |
| `vms_default_tpm` | `false` | Whether VMs default to TPM 2.0 emulation (per-VM override with `tpm` key) |
| `vms_tpm_force_reset` | `false` | Clear the swtpm state of every TPM VM. Command-line escape hatch only |
| `vms_swtpm_state_dir` | `/var/lib/swtpm` | Base directory for per-VM swtpm state (must match `host_swtpm_state_dir`) |
| `vms_default_net_mode` | `user` | Default networking mode (`user` or `bridge`) |
| `vms_default_net_bridge` | `br0` | Default bridge device for bridge-mode VMs |
| `vms_bridge_conf` | `/etc/qemu/bridge.conf` | Path to the QEMU bridge helper ACL file |
| `vms_vm_config_dir` | `/etc/qemu/vms` | Directory for per-VM QEMU configuration files (must match `host_vm_config_dir`) |
| `vms_default_memory` | `2G` | Default memory allocation for VMs |
| `vms_default_cpus` | `2` | Default number of virtual CPUs |
| `vms_default_cpu` | `host` | Default CPU model passed to the QEMU `-cpu` flag |
| `vms_default_novnc_enabled` | `false` | Whether VMs default to noVNC web console when not specified per VM |
| `vms_default_novnc_port` | `null` | Default noVNC port. When null, each VM gets 6080 plus its own VNC display number |
| `vms_default_shutdown_timeout` | `120` | Default timeout in seconds for graceful ACPI shutdown |
| `vms_default_vnc_address` | `""` | Default address that the VNC console binds. Empty binds every interface. **Deprecated default**: the next release changes it to `127.0.0.1` |
| `vms_vnc_address_deprecation_warning` | `true` | Whether to warn about VMs that leave `vnc_address` unset. Set it to `false` to silence the notice |
| `vms_default_serial_socket` | `null` | Default path of the serial console socket. When null, each VM gets `/var/lib/qemu/<name>/serial.sock` |
| `vms_default_qmp_socket` | `null` | Default path of the QMP socket. When null, each VM gets `/var/lib/qemu/<name>/qmp.sock` |

The four firmware paths above are the layout that `edk2-ovmf` uses on EL10. Set them when your firmware is somewhere else.

### VM definition

Each entry in `vms_list` is a dictionary with the following keys:

| Key | Required | Default | Description |
|-----|----------|---------|-------------|
| `name` | yes | — | VM name, used as the disk image filename |
| `disk_size` | no | `vms_default_disk_size` | Disk image size (e.g. `20G`, `100G`) |
| `disk_format` | no | `vms_default_disk_format` | Disk format (`qcow2` or `raw`) |
| `disk_bus` | no | `vms_default_disk_bus` | Disk bus (`virtio-blk` or `virtio-scsi`) |
| `disk_image_url` | no | — | URL to a qcow2 image to download and use as a backing file |
| `disk_image_checksum` | no | — | SHA256 checksum for the downloaded image (format: `sha256:abc123...`) |
| `uefi` | no | `vms_default_uefi` | Whether to enable UEFI boot for this VM |
| `secure_boot` | no | `vms_default_secure_boot` | Enable UEFI Secure Boot (requires UEFI) |
| `nvram_template` | no | `vms_ovmf_vars_template` or `vms_ovmf_vars_secboot_template` | UEFI variable store template for this VM only |
| `nvram_generation` | no | `1` | Increase to write the NVRAM file again from the template |
| `nvram_expected_db_cn` | no | — | Subject CN that the signature database (db) must hold (checked when `vms_nvram_verify` is true) |
| `tpm` | no | `vms_default_tpm` | Enable TPM 2.0 emulation via swtpm |
| `tpm_generation` | no | `1` | Increase to clear the swtpm state of this VM |
| `net_mode` | no | `vms_default_net_mode` | Networking mode: `user` or `bridge` |
| `net_bridge` | no | `vms_default_net_bridge` | Bridge device (only used when `net_mode` is `bridge`) |
| `mac_address` | no | derived from the name | MAC address. Set it when two VM names give the same derived address |
| `memory` | no | `vms_default_memory` | Memory allocation (e.g. `2G`, `4G`) |
| `cpus` | no | `vms_default_cpus` | Number of virtual CPUs |
| `cpu_model` | no | `vms_default_cpu` | CPU model for the QEMU `-cpu` flag (for example `host`, `kvm64`) |
| `vnc` | no | derived from the name | VNC display number (port = 5900+N). Set it when two VM names give the same derived display |
| `vnc_address` | no | `vms_default_vnc_address` | Address that the VNC console binds. Empty binds every interface. Use `127.0.0.1` to reach the console through the host only. Wrap an IPv6 address in brackets |
| `serial_socket` | no | `/var/lib/qemu/<name>/serial.sock` | Path of the serial console socket |
| `qmp_socket` | no | `/var/lib/qemu/<name>/qmp.sock` | Path of the QMP control socket |
| `smbios_oem_strings` | no | — | List of SMBIOS type 11 OEM strings (read by `systemd-stub`). Stored in `0600` files; a change needs a restart of the VM |
| `usb_disk_image` | no | — | Path to USB disk image to attach (`.iso`, `.raw`, `.img`, `.qcow2`) |
| `usb_boot_priority` | no | `true` when `usb_disk_image` is set | Boot from USB first |
| `cloud_init_user_data` | no | — | cloud-init `user-data` content; triggers seed ISO generation |
| `cloud_init_meta_data` | no | auto-generated | cloud-init `meta-data` content; auto-generated from VM name if omitted |
| `cloud_init_network_config` | no | — | cloud-init `network-config` content; omitted from ISO if not set |
| `novnc_enabled` | no | `vms_default_novnc_enabled` | Enable noVNC web console for this VM |
| `novnc_port` | no | `6080 + vnc` | Port for noVNC web console (auto-assigned if not specified) |
| `state` | no | `present` | Desired service state: `started`, `stopped`, `present`, `restarted`, or `absent` |
| `force_destroy` | no | `false` | Safety flag required to destroy VM with `state: absent` (must be `true`) |
| `shutdown_timeout` | no | `120` | Timeout in seconds for graceful ACPI shutdown (used by `restarted` and `absent`) |

## Input validation

Every check that can be answered from `vms_list` alone runs before the role writes anything to the host. A run that cannot finish therefore leaves the host as it was. The role fails when:

- two VMs share a name, or a name is not usable as a systemd instance name and a file name (letters, digits, `.`, `_` and `-`, starting with a letter or a digit);
- a VM has `secure_boot: true` and `uefi: false`;
- a VM has `disk_image_url` and a `disk_format` other than `qcow2`, because only qcow2 can hold a backing file;
- two VMs would use the same VNC display, the same MAC address or the same noVNC port;
- two VMs would open the same serial socket or the same QMP socket;
- a VM has `state: absent` without `force_destroy: true`.

The role derives the VNC display and the MAC address from the VM name, so two names can give the same value. The message names the VMs; set `vnc` or `mac_address` on one of them.

## Service management

The role manages each VM as a `qemu-vm@<name>.service` systemd unit. The per-VM `state` key controls the unit:

- **`present`** (default) — the role writes the config file and leaves the `qemu-vm@` unit alone. Use it to prepare a VM without starting it, or on a host without KVM. The swtpm and noVNC instances of the VM are still started, so that the VM can be started by hand afterwards.
- **`started`** — the role enables and starts the unit, then checks that it is active.
- **`stopped`** — the role enables the unit but stops it.
- **`restarted`** — the role shuts the guest down over the QEMU monitor and starts the VM again.
- **`absent`** — **destructive**. The role shuts the guest down and removes every artifact of the VM. It needs `force_destroy: true`.

A configuration change is written to the `.conf` file but does not restart a running VM. Use `state: restarted` to apply it.

### Graceful shutdown

`state: restarted` and `state: absent` shut the guest down instead of killing QEMU. The role writes `system_powerdown` to the QEMU monitor socket of the VM, which the guest sees as an ACPI power button press, and waits up to `shutdown_timeout` seconds (default 120) for QEMU to exit. It then stops the unit either way, because a guest may ignore the request and because `Restart=on-failure` would otherwise bring a VM that exited non-zero straight back up.

`systemctl stop qemu-vm@<name>` is not the same thing: the unit sends SIGTERM to QEMU, which exits at once and leaves the guest file systems dirty.

### Destroying VMs

To prevent accidental data loss, destroying a VM requires setting `force_destroy: true` on the VM definition:

```yaml
vms_list:
  - name: testvm
    state: absent
    force_destroy: true  # Required!
```

The role removes these paths, whether or not the VM still carries the key that created them:

| Path | What it is |
|------|------------|
| `/etc/qemu/vms/{name}.conf` | QEMU arguments |
| `/etc/qemu/vms/novnc-{name}.conf` | noVNC environment file |
| `/var/lib/qemu/images/{name}.{qcow2\|raw}` | Disk image |
| `/var/lib/qemu/images/{name}-seed.iso` | cloud-init seed ISO |
| `/var/lib/qemu/images/.cloud-init-staging/{name}/` | cloud-init staging directory |
| `/var/lib/qemu/images/{name}_VARS.fd` | UEFI variable store |
| `/var/lib/qemu/images/{name}_VARS.fd.state` | UEFI variable store state file |
| `/var/lib/qemu/images/{name}_VARS.fd.secboot` | Secure Boot marker of versions before 0.4.0 |
| `/var/lib/qemu/{name}/` | Runtime directory: monitor socket, QMP socket, serial socket and SMBIOS files |
| `/var/lib/swtpm/{name}/` | swtpm state directory |
| `/var/lib/swtpm/{name}.state` | swtpm state file |
| `/etc/systemd/system/qemu-vm@{name}.service.d/` | systemd drop-in directory |

It also stops and disables the `qemu-vm@`, `novnc@` and `swtpm@` instances of the VM.

**Note:** shared resources are not removed. `/etc/qemu/bridge.conf` and the cached backing image under `/var/lib/qemu/images/cache/` stay in place.

## UEFI firmware and Secure Boot

A UEFI VM gets a read-only firmware image, shared by every VM, and its own writable variable store at `/var/lib/qemu/images/<name>_VARS.fd`. The store holds the UEFI boot entries and, on a Secure Boot VM, the PK, KEK and db keys.

`secure_boot: true` selects the Secure Boot firmware, which enforces signature checks, and turns on SMM so that the guest cannot write the store behind the firmware's back.

```yaml
vms_list:
  - name: secure-vm
    disk_size: 40G
    secure_boot: true
```

### When the role writes the variable store again

The role copies the template over the store only when it has to, because a rewrite erases the UEFI boot entries of the VM. It records a fingerprint of the store in `<name>_VARS.fd.state` and writes the store again when:

- the store does not exist yet;
- the `secure_boot` flag changed;
- `nvram_template` points at a different file;
- the content of the template changed, for example after a firmware package update;
- `nvram_generation` increased;
- `vms_nvram_force_reset` is true.

QEMU maps the store as pflash while the VM runs, so the role stops a running VM before it writes the file and starts the VM again afterwards.

Increase `nvram_generation` to reset the store of one VM:

```yaml
vms_list:
  - name: secure-vm
    secure_boot: true
    nvram_generation: 2   # was 1
```

`vms_nvram_force_reset` does the same for every VM in the run. It is an escape hatch for the command line, not a playbook setting, because it erases the boot entries at every run:

```bash
ansible-playbook site.yml -e vms_nvram_force_reset=true
```

### A custom variable store

`nvram_template` gives one VM a store of its own, for example one with your own PK, KEK and db. It overrides both `vms_ovmf_vars_template` and `vms_ovmf_vars_secboot_template` for that VM.

```yaml
vms_list:
  - name: devbox
    secure_boot: true
    nvram_template: /srv/firmware/devbox_VARS.fd
    nvram_expected_db_cn: "My Devbox Secure Boot"
```

### Verifying the store

A store that is still in Setup Mode, or that lost its db entry, gives a VM that boots an unsigned artifact without a complaint. Set `vms_nvram_verify: true` to have the role check each Secure Boot store after it writes it. The role asserts that a PK, a KEK and a db are enrolled and that `SecureBootEnable` is on, and, when `nvram_expected_db_cn` is set, that the db holds a certificate with that subject CN.

`SecureBoot` and `SetupMode` are volatile variables that the firmware creates at boot, so an offline check cannot read them. An enrolled PK is the offline equivalent of `SetupMode=0`.

The check needs `virt-fw-vars` from the package `python3-virt-firmware`. The role reports a skip when the command is absent.

### Upgrading from a version before 0.4.0

Earlier versions recorded only the `secure_boot` flag, by the presence of a `<name>_VARS.fd.secboot` marker file. 0.4.0 replaced it with the `<name>_VARS.fd.state` file.

A VM that has only a marker keeps its variable store as long as the marker agrees with its `secure_boot` flag. The role writes a state file for it and removes the marker, so the UEFI boot entries of an existing VM survive the upgrade.

## System disk bus

`vms_default_disk_bus`, and the per-VM `disk_bus` key, choose how the system disk is attached:

- **`virtio-blk`** (default) — `-drive if=virtio`. Least overhead, and the default of earlier versions, so the QEMU arguments of an existing VM do not change.
- **`virtio-scsi`** — a `virtio-scsi-pci` controller and an `scsi-hd` device. This is the bus that production images usually expect, and it supports discard and more than 26 disks.

The cloud-init seed ISO stays on virtio-blk in both cases. With an attached USB image, the USB device keeps boot priority ahead of the system disk.

## SMBIOS type 11 OEM strings

`smbios_oem_strings` passes a list of strings to the guest as SMBIOS type 11 OEM strings. `systemd-stub` reads them, so they add to the kernel command line of a unified kernel image without a rebuild and a new signature, and they can carry a credential.

```yaml
vms_list:
  - name: uki-vm
    smbios_oem_strings:
      - "io.systemd.stub.kernel-cmdline-extra=rd.debug systemd.log_level=debug"
      - "io.systemd.credential:mycred=abc"
```

The role writes each string to its own file under `/var/lib/qemu/<name>/smbios/` and passes the path to QEMU with `-smbios type=11,path=...`. It does not use the `value=` form, because the systemd unit passes the QEMU arguments unquoted and systemd would split a string that contains a space into two arguments.

The files have mode `0600` and belong to `vms_service_user`, because an OEM string can hold a secret. The `path=` form also keeps the string out of the command line, where `ps` would show it to every user.

Shortening the list, emptying it or deleting the key removes the files that are no longer used.

The firmware reads the strings once at boot, so a change takes effect the next time the VM starts. The role does not restart a running VM.

**Limits:** `systemd-stub` ignores these strings under confidential computing, and they measure into PCR 12. OpenStack Nova has no equivalent knob, so do not build a production configuration on this feature.

## Networking

The role supports two networking modes:

- **`user`** (default) — QEMU user-mode networking (SLIRP). No host configuration needed. The VM gets outbound connectivity via NAT but is not reachable from the host network.
- **`bridge`** — Bridge/tap networking via `qemu-bridge-helper`. The VM is attached to a host bridge and appears as a device on the bridged network.

### Bridge mode prerequisites

Bridge mode uses QEMU's `qemu-bridge-helper` to attach VMs to a host bridge. The bridge device itself must already exist on the host (this role does not create it). The role writes `/etc/qemu/bridge.conf` to authorize the helper to use the specified bridges.

### MAC address generation

Each VM gets a MAC address derived from its name: the QEMU OUI prefix `52:54:00` plus the first three bytes of the MD5 hash of the name. The address is therefore stable across a rebuild of the VM.

Two names can give the same address. The role checks for that and fails with both names; set `mac_address` on one of them.

## Serial console and QMP

Each VM opens two UNIX sockets in its runtime directory, beside the monitor
socket. QEMU creates both when it starts and does not wait for a client.

| Socket | Default path | What it carries |
|---|---|---|
| Serial console | `/var/lib/qemu/<name>/serial.sock` | The guest serial console: the boot messages, the login prompt and the keystrokes a client sends |
| QMP | `/var/lib/qemu/<name>/qmp.sock` | The machine readable control channel, with typed commands such as `send-key` and `screendump` |
| Monitor | `/var/lib/qemu/<name>/monitor.sock` | The human monitor. The role writes `system_powerdown` here on a graceful shutdown |

Set `serial_socket` or `qmp_socket` per VM to move a socket. The role creates
`/var/lib/qemu/<name>/` only. A path anywhere else needs a directory that the
deployer creates and that the QEMU user can write. No path may hold a space,
because systemd splits `$QEMU_ARGS` at each space.

The role fails the run when two VMs would open one socket.

**The guest serial console is no longer in the journal.** The VM starts with
`-display none` and an explicit `-serial`, so the console goes to the socket
instead of stdout. The unit journal of a VM now holds the stderr of QEMU and
the start and stop lines of systemd. Read the guest console at the socket:

```bash
socat - UNIX-CONNECT:/var/lib/qemu/testvm/serial.sock
```

Drive the VM over QMP with any QMP client:

```bash
socat - UNIX-CONNECT:/var/lib/qemu/testvm/qmp.sock
```

## VNC Console Access

Each VM is configured with a VNC console for remote graphical access. VNC display numbers are assigned as follows:

- **Default**: the MD5 hash of the VM name, modulo 100. The display is therefore stable across a rebuild of the VM.
- **Override**: set `vnc: N` per VM.

The VNC port is 5900 plus the display number.

Two names can hash to the same display, which would leave the second QEMU unable to bind its console. The role checks for that and fails with both names; set `vnc` on one of them.

**Examples:**
- VM "testvm" → display :42 → VNC port 5942
- VM with `vnc: 10` → display :10 → VNC port 5910

**Access:** Connect using any VNC client:
```bash
vncviewer <host>:<5900+display>
```

### Bind address

`vnc_address` sets the address that the console binds:

```yaml
vms_list:
  - name: testvm
    vnc_address: 127.0.0.1
```

An empty value binds every interface, on both `0.0.0.0` and `::`. Wrap an IPv6
address in brackets, for example `[::1]`.

`127.0.0.1` reaches the console through the host only. noVNC keeps working,
because the noVNC instance of a VM connects to `localhost`.

**The default of `vms_default_vnc_address` is deprecated.** It is empty today,
so the console of every VM is reachable from anywhere that can route to the
host. The next release changes the default to `127.0.0.1`. The role warns
about each VM that leaves `vnc_address` unset. Set the key, or set
`vms_default_vnc_address`, to choose the address yourself. Set
`vms_vnc_address_deprecation_warning: false` to silence the notice.

**Security note:** VNC is unauthenticated by default. Bind it to `127.0.0.1`,
or use firewall rules or VNC password authentication, for production use.

## USB Disk Image Attachment

You can attach one pre-provisioned USB disk image per VM (for example installer or rescue media).
When `usb_disk_image` is set, the role adds a USB 3.0 XHCI controller and USB storage device to QEMU.

Supported image formats:
- `.iso`
- `.raw`
- `.img`
- `.qcow2`

By default, USB is given boot priority when attached. You can disable this with `usb_boot_priority: false`.

Example:

```yaml
vms_list:
  - name: installer-vm
    disk_size: 40G
    usb_disk_image: /var/lib/qemu/images/installer.iso
    usb_boot_priority: true
    state: started
```

## Cloud-Init / Configuration Drive

The role can automatically generate a NoCloud seed ISO and attach it to a VM as a virtio CD-ROM. This lets cloud-init (Linux) or cloudbase-init (Windows) pick up first-boot configuration without any manual ISO preparation.

### Prerequisites

- **Host**: `genisoimage` must be installed. The `maglo.qemu.host` role installs it. The role checks for it and fails with that instruction when it is missing.
- **Guest**: `cloud-init` or `cloudbase-init` must be installed inside the VM image. Cloud images from major distributions (AlmaLinux, Rocky Linux, Ubuntu, Debian) ship with `cloud-init` pre-installed.

### Usage

Set any combination of `cloud_init_user_data`, `cloud_init_meta_data`, or `cloud_init_network_config` on a VM entry. As soon as any of these keys is present, the role:

1. Writes the content files to a temporary staging directory.
2. Generates a seed ISO (`/var/lib/qemu/images/<name>-seed.iso`) with volume label `CIDATA`.
3. Attaches the ISO to QEMU as a read-only virtio CD-ROM drive.

`meta-data` is auto-generated from the VM name if `cloud_init_meta_data` is not provided:

```yaml
instance-id: <name>
local-hostname: <name>
```

Example:

```yaml
vms_list:
  - name: web01
    disk_image_url: "https://repo.almalinux.org/almalinux/9/cloud/x86_64/images/AlmaLinux-9-GenericCloud-latest.x86_64.qcow2"
    cloud_init_user_data: |
      #cloud-config
      packages:
        - nginx
      runcmd:
        - systemctl enable --now nginx
    cloud_init_network_config: |
      version: 2
      ethernets:
        eth0:
          dhcp4: true
    state: started
```

The seed ISO is placed alongside the disk image:
```
/var/lib/qemu/images/
├── web01.qcow2          (overlay disk)
└── web01-seed.iso       (cloud-init seed ISO, auto-generated)
```

When the VM is destroyed with `state: absent`, the seed ISO is removed along with all other VM artifacts.

## noVNC Web Console

The role can configure per-VM noVNC instances for browser-based console access. noVNC provides an HTML5 VNC client that requires no client-side software.

### Prerequisites

1. Install the `novnc` package on the host (handled by `maglo.qemu.host` role with `host_novnc_enabled: true`)
2. Ensure the EPEL repository is enabled (EPEL 10 provides novnc 1.5.0)

### Configuration

Enable noVNC per-VM by setting `novnc_enabled: true`:

```yaml
vms_list:
  - name: web01
    novnc_enabled: true
    novnc_port: 6080  # Optional, auto-assigned if omitted
```

When enabled, the role:
- Checks that the `novnc@.service` template unit is present. The `maglo.qemu.host` role deploys it; the `vms` role fails when it is missing.
- Writes a per-VM environment file at `/etc/qemu/vms/novnc-<name>.conf` with the port and the VNC target.
- Writes a systemd drop-in at `/etc/systemd/system/qemu-vm@<name>.service.d/novnc-dependency.conf`.
- Enables and starts the `novnc@<name>.service` instance.

### Port Assignment

noVNC ports are auto-assigned if not specified:
- **Auto-assignment**: `6080 + VNC display number`
- **Manual override**: Set `novnc_port: N` per VM

**Examples:**
- VM with VNC display :0 → noVNC port 6080
- VM with VNC display :1 → noVNC port 6081
- VM with `novnc_port: 8080` → noVNC port 8080 (override)

### Access

Once configured, access the VM console in a web browser:
```
http://<host>:<novnc_port>/vnc.html
```

For example, a VM with noVNC on port 6080:
```
http://192.168.1.100:6080/vnc.html
```

### Service dependencies

The role writes a drop-in on the **VM** unit that makes it require its proxy:

```ini
# /etc/systemd/system/qemu-vm@<name>.service.d/novnc-dependency.conf
[Unit]
After=novnc@<name>.service
Requires=novnc@<name>.service
```

So the proxy starts before the VM, and stopping the proxy stops the VM as well. `state: restarted` and `state: absent` therefore shut the guest down first and touch the proxy afterwards.

**Security note:** noVNC serves unencrypted WebSocket connections by default. For production use, consider placing it behind a reverse proxy with TLS/SSL.

## URL-based Disk Provisioning

The role supports provisioning VMs from pre-built cloud images (QCOW2 format) downloaded from a URL. This enables rapid VM deployment with pre-installed operating systems while maintaining storage efficiency through QCOW2 copy-on-write overlay images.

### How it works

When you specify `disk_image_url` for a VM:

1. **Download**: The image is downloaded to `vms_image_cache_dir` (default: `/var/lib/qemu/images/cache/`)
2. **Cache**: The downloaded image is cached and reused across multiple VMs
3. **Overlay**: An overlay disk is created with the cached image as a backing file
4. **Efficiency**: Multiple VMs sharing the same URL use the same cached base image

### Storage architecture

```
/var/lib/qemu/images/
├── cache/
│   └── AlmaLinux-9-GenericCloud-latest.x86_64.qcow2  (1.2 GB - shared)
├── web01.qcow2  (overlay referencing cached image)
├── web02.qcow2  (overlay referencing cached image)
└── custom.qcow2 (blank disk, no backing file)
```

**Result**: Two VMs with 20G disks only consume ~1.2 GB (not 40 GB) on disk.

### Features

- **Checksum verification**: optional SHA256 checksum with `disk_image_checksum`. Setting `vms_verify_checksums: false` skips the comparison for every VM.
- **Idempotency**: Images are only downloaded once; re-runs skip existing files
- **Format validation**: Downloaded images are verified to be valid QCOW2 format
- **Disk resizing**: Overlay disks can be larger than the backing file (e.g., 10G base → 50G VM)
- **Backward compatible**: VMs without `disk_image_url` still get blank disks as before

### Usage

```yaml
vms_list:
  # Cloud image with checksum verification
  - name: almalinux-web
    disk_image_url: "https://repo.almalinux.org/almalinux/9/cloud/x86_64/images/AlmaLinux-9-GenericCloud-latest.x86_64.qcow2"
    disk_image_checksum: "sha256:abc123def456..."
    disk_size: 20G
    state: started

  # Multiple VMs sharing same backing file
  - name: almalinux-db
    disk_image_url: "https://repo.almalinux.org/almalinux/9/cloud/x86_64/images/AlmaLinux-9-GenericCloud-latest.x86_64.qcow2"
    disk_image_checksum: "sha256:abc123def456..."
    disk_size: 50G  # Larger than base image
    state: started

  # Cloud image without checksum
  - name: ubuntu-test
    disk_image_url: "https://cloud-images.ubuntu.com/releases/24.04/release/ubuntu-24.04-server-cloudimg-amd64.img"
    disk_size: 30G
    state: present

  # Traditional blank disk (backward compatible)
  - name: custom-vm
    disk_size: 100G
    state: started
```

### Cloud image sources

Common cloud image providers:

- **AlmaLinux**: `https://repo.almalinux.org/almalinux/9/cloud/x86_64/images/`
- **Rocky Linux**: `https://download.rockylinux.org/pub/rocky/9/images/x86_64/`
- **Ubuntu**: `https://cloud-images.ubuntu.com/releases/`
- **CentOS Stream**: `https://cloud.centos.org/centos/9-stream/x86_64/images/`

**Important**: Only QCOW2-format images are supported. The role validates the format and fails if a non-QCOW2 file is downloaded.

### Security considerations

- **Checksums**: Always use `disk_image_checksum` for production to verify image integrity
- **HTTPS**: Prefer HTTPS URLs to prevent man-in-the-middle attacks
- **Trusted sources**: Only download images from trusted, official repositories

## Example Playbook

```yaml
- hosts: hypervisors
  roles:
    - maglo.qemu.host
    - role: maglo.qemu.vms
      vars:
        vms_list:
          - name: web01
            disk_size: 40G
            memory: 4G
            cpus: 4
            vnc: 1
          - name: db01
            disk_size: 100G
            disk_format: raw
            net_mode: bridge
            net_bridge: br-lan
            memory: 8G
            cpus: 8
          - name: worker01
            uefi: false
            cpu_model: kvm64
            mac_address: "52:54:00:aa:bb:cc"
            state: stopped
```

### TPM 2.0 emulation

To start a per-VM `swtpm` instance, set `tpm: true` on the VM entry:

```yaml
- hosts: hypervisors
  roles:
    - maglo.qemu.host
    - role: maglo.qemu.vms
      vars:
        vms_list:
          - name: secure-vm
            disk_size: 40G
            tpm: true
```

The role checks that the `swtpm@.service` template unit is present — the `maglo.qemu.host` role deploys it — creates a state directory for the VM under `vms_swtpm_state_dir`, starts the `swtpm@secure-vm.service` instance, and writes a drop-in that makes the VM require it.

TPM state is persistent: the sealed key slots, the persistent handles and the PCR history survive a rebuild of the VM. To clear it, increase `tpm_generation`:

```yaml
vms_list:
  - name: secure-vm
    tpm: true
    tpm_generation: 2   # was 1
```

The role stops the VM and swtpm, removes the state directory, and starts both again. A VM that has no state file yet keeps its TPM state, so upgrading the collection does not clear the TPM of a VM that already exists.

Only an increase resets. Lowering `tpm_generation`, or deleting the key so that it falls back to `1`, leaves the TPM alone — tidying a spent `tpm_generation: 2` line out of a playbook must not wipe the sealed keys of a running guest. The role records the generation you asked for either way, so raising it again resets again.

`vms_tpm_force_reset` does the same for every TPM VM in the run. Like `vms_nvram_force_reset` it is an escape hatch for the command line, not a playbook setting:

```bash
ansible-playbook site.yml -e vms_tpm_force_reset=true
```

### noVNC web console

To enable browser-based console access with noVNC:

```yaml
- hosts: hypervisors
  roles:
    - role: maglo.qemu.host
      vars:
        host_novnc_enabled: true  # Install novnc package
    - role: maglo.qemu.vms
      vars:
        vms_list:
          - name: web01
            disk_size: 40G
            novnc_enabled: true
            novnc_port: 6080  # Optional, auto-assigned if omitted
          - name: db01
            disk_size: 100G
            novnc_enabled: true  # Port auto-assigned (6081 based on VNC display)
```

Access the web console at `http://<host>:6080/vnc.html` (for web01) and `http://<host>:6081/vnc.html` (for db01).

### VM lifecycle operations

Manage VM lifecycle states with the `state` parameter:

```yaml
- hosts: hypervisors
  roles:
    - maglo.qemu.host
    - role: maglo.qemu.vms
      vars:
        vms_list:
          # Create but don't start
          - name: vm01
            disk_size: 20G
            state: present

          # Create and start
          - name: vm02
            disk_size: 20G
            state: started

          # Graceful restart (ACPI shutdown + start)
          - name: vm03
            disk_size: 20G
            state: restarted
            shutdown_timeout: 180  # Wait up to 3 minutes for graceful shutdown

          # Destroy VM and remove all artifacts
          - name: old-vm
            state: absent
            force_destroy: true  # Required safety flag
```

`restarted` shuts the guest down over the QEMU monitor, waits up to `shutdown_timeout` seconds, stops the unit, and starts the VM again. `absent` does the same and then removes every artifact of the VM; it needs `force_destroy: true`. See [Graceful shutdown](#graceful-shutdown) and [Destroying VMs](#destroying-vms).

## License

GPL-3.0-only
