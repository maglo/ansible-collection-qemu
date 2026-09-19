# maglo.qemu.labview

Deploy [labview](https://github.com/maglo/qemu-lab-manager), a console service for a QEMU/KVM lab, on a hypervisor.

labview serves every machine's framebuffer, serial line and details on one page, behind one port, with the keyboard held as a write lease by one client at a time. It replaces one `novnc_proxy` per VM on a port derived from the VM name, and it gives a consumer a serial console and a control channel that no browser had before.

The role installs the binary, creates the service account and the directories, installs the polkit rule that lets labview power machines, and runs it as `labview.service`.

## What it does not do

**The role deploys no reverse proxy and manages no TLS material.** labview listens on loopback and authenticates nobody. Terminating TLS and authenticating a person belongs to a proxy in front of it, and which proxy — nginx, Caddy, HAProxy, an ingress — is site policy. [Putting a proxy in front](#putting-a-proxy-in-front) below states what any proxy has to do; the collection does not mandate one.

## Requirements

- The `maglo.qemu.host` role has run. labview joins the QEMU service group to open the sockets, and the role fails with a clear message when that group does not exist.
- `host_vm_umask` leaves those sockets group writable. It is `0007` by default, which is what makes them `0770`. Under systemd's own `0022` they are `0755`, and connecting to a UNIX socket needs the write bit, so labview would be refused.
- The `maglo.qemu.vms` role writes the inventory: set `vms_labview_inventory_dir` to the same path as `labview_inventory_dir`. Without it labview starts and serves an empty lab.
- Outbound HTTPS to wherever `labview_binary_url` points, for the download.

## Example playbook

```yaml
- hosts: hypervisors
  become: true
  roles:
    - role: maglo.qemu.host

    - role: maglo.qemu.vms
      vars:
        vms_labview_inventory_dir: /etc/labview/inventory.d
        vms_list:
          - name: web01
            disk_size: 20G
            vnc_address: 127.0.0.1
            state: started

    - role: maglo.qemu.labview
```

`playbooks/labview.yml` is the same thing, ready to run.

## Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `labview_version` | `0.2.0` | Release of labview to install |
| `labview_arch` | `null` | Architecture suffix of the release asset. Derived from `ansible_architecture` when unset |
| `labview_binary_url` | the release asset of `labview_version` | Where the binary comes from |
| `labview_checksum` | the `SHA256SUMS` of the same release | Checksum, in the form `get_url` takes. `null` downloads without verifying |
| `labview_binary_path` | `/usr/local/bin/labview` | Where the binary is installed |
| `labview_user` | `labview` | Service account. Never `root` — see [Why not root](#why-not-root) |
| `labview_group` | `labview` | Primary group of the account |
| `labview_qemu_group` | `qemu` | Group of the QEMU sockets, joined as a supplementary group. Must match `host_service_group` |
| `labview_state_dir` | `/var/lib/labview` | Base directory for everything labview writes |
| `labview_recordings_dir` | `{{ labview_state_dir }}/recordings` | Serial transcripts, one per machine per run |
| `labview_screenshot_dir` | `{{ labview_state_dir }}/screenshots` | Screenshot exchange, shared with QEMU |
| `labview_inventory_dir` | `/etc/labview/inventory.d` | Per-machine inventory files. Must match `vms_labview_inventory_dir` |
| `labview_listen` | `127.0.0.1:8080` | Address labview serves on |
| `labview_host_access` | `local` | Host introspection: `local`, `none` or `fake` |
| `labview_identity_header` | `X-Forwarded-User` | Header carrying the identity a proxy authenticated |
| `labview_extra_args` | `[]` | Extra arguments appended to `ExecStart` verbatim |
| `labview_polkit_rule_path` | `/etc/polkit-1/rules.d/50-labview-units.rules` | Where the polkit rule is installed |
| `labview_unit_pattern` | `^qemu-vm@[A-Za-z0-9._-]+\.service$` | Units labview may start, stop and restart |
| `labview_service_enabled` | `true` | Enable `labview.service` at boot |
| `labview_service_state` | `started` | State to leave the service in |

## The binary

labview ships as a statically linked binary on each release of `maglo/qemu-lab-manager`. There is no container image and no package, so the role downloads the release asset and verifies it against the `SHA256SUMS` published beside it. `get_url` fetches that file and matches the entry whose name is the basename of `labview_binary_url`.

Upgrading is one variable:

```yaml
labview_version: "0.3.0"
```

The role notices the binary no longer matches the checksum, replaces it and restarts the service.

Two things are worth knowing:

- The default trusts a checksum file served from the same place as the binary, which protects against a corrupted download rather than a compromised release. Pin a literal digest to do better:

  ```yaml
  labview_checksum: "sha256:d85034b3c96fd8bfcbf5617eadaba63353b7b52b197dea53ec70fa955a213b2f"
  ```

- With `labview_checksum: null` there is nothing to compare, so an existing binary is left alone and a version bump does **not** replace it.

A custom `labview_binary_url` whose basename is not in the checksum file needs a literal digest too, because the lookup is by that basename.

## Why not root

labview runs under its own account, and the polkit rule is what lets it start, stop and restart a VM.

The rule is mandatory. A system service has no logind session, so polkit evaluates a power operation as neither local nor active, falls through to `auth_admin`, and finds no agent to answer the prompt. Every power operation then fails, and it fails in a way that reads as a labview fault rather than a missing rule.

Running labview as root would not fix that — it would hide it. systemd short-circuits the privilege check for a root caller, so polkit never runs and the rule bounds nothing at all.

Two layers have to agree before a machine is restarted. labview maps a machine to a unit through the inventory, so it can only ask about units the inventory named. The rule is the host's own opinion about which units that account may touch, so a mistake in the inventory cannot become "restart anything on this hypervisor". Narrow `labview_unit_pattern` further to bound labview to part of a hypervisor:

```yaml
labview_unit_pattern: '^qemu-vm@lab-[A-Za-z0-9._-]+\.service$'
```

## Putting a proxy in front

`labview_listen` is `127.0.0.1:8080`, and the role warns when it is set to anything that is not loopback. labview performs no authentication: whoever reaches it holds the write lease of every machine, so the address it binds is the whole access control story until a proxy provides one.

Whatever proxy terminates TLS and authenticates, three things are not optional. All three are easy to miss, and each one fails in a way that looks like a labview bug:

1. **Forward the original `Host` header.** labview's websocket origin check compares `Origin` against `Host`. A proxy that rewrites `Host` to `127.0.0.1:8080` makes every websocket look cross-origin, and every console is refused.
2. **Set the identity header on the websocket upgrade too**, not only on ordinary requests. `labview_identity_header` (`X-Forwarded-User` by default) is the only thing naming the lease holder. A proxy that sets it on plain HTTP alone leaves every console and serial socket unidentified, no lease ever matches the person holding it, and nobody can type.
3. **Discard any client-supplied identity header.** labview trusts it completely — it is the only thing in the audit trail — so the proxy must overwrite it, never pass it through.

Set `labview_identity_header` to match the proxy where it asserts identity under another name, for example `X-Auth-Request-User` from oauth2-proxy.

`deploy/nginx-labview.conf` upstream is a worked nginx example that does all three. The [console service guide](../../docs/docsite/rst/guide_console_service.rst) covers the shape and the reasoning.

## Where guest boot output went

A VM's serial console is a socket rather than stdout, so it no longer reaches the journal of `qemu-vm@<name>.service`. labview records a transcript per run in `labview_recordings_dir` instead, and does not read the host journal at all. A consumer who read guest boot output with `journalctl -u qemu-vm@<name>` reads the transcript now, or watches the serial tab.

## Directories

| Directory | Owner | Mode | Why |
|-----------|-------|------|-----|
| `labview_state_dir` | `labview:labview` | `0750` | Everything labview writes, and the only path the unit makes writable |
| `labview_recordings_dir` | `labview:labview` | `0750` | Serial transcripts |
| `labview_screenshot_dir` | `labview:qemu` | `02770` | Shared with QEMU: QEMU writes a frame as its own user, labview reads it and removes it. Group writable so QEMU can create the file, setgid so the frame stays in a group labview can read |
| `labview_inventory_dir` | `root:root` | `0755` | Written by the `vms` role. The `labview` role creates it with the same owner and mode, so a service on a hypervisor with no VMs yet still starts |

The screenshot directory is under `labview_state_dir` and not in `/tmp` because the unit sets `PrivateTmp=yes`: QEMU would write into the real `/tmp` and labview would look in its own.

## Hardening

The unit follows `deploy/labview.service` upstream: `ProtectSystem=strict` with only `labview_state_dir` writable, `NoNewPrivileges`, an empty `CapabilityBoundingSet`, `SystemCallFilter=@system-service`, and `RestrictAddressFamilies` down to `AF_UNIX`, `AF_INET` and `AF_INET6`.

`ProtectSystem=strict` leaves the QEMU sockets on a read-only mount, which is no obstacle: connecting to a UNIX socket does not write to the filesystem, and needs only the write bit in the socket's own mode.

`ProtectProc=default` and `ProcSubset=all` stay permissive on purpose. Reading another process's `/proc/<pid>/cmdline` is how the details tab shows the QEMU command line of a machine, and a stricter setting hides it.

## SELinux

The role installs no SELinux policy module. The binary goes to `/usr/local/bin`, which systemd runs without the transition that `/usr/libexec/qemu-kvm` needs — that one is why the `host` role ships a module. A site that relocates the binary somewhere with a different label should check `ausearch -m AVC` after the first start.

## Dependencies

None declared. In practice the `host` role runs first, because the QEMU service group has to exist.

## Molecule

```bash
cd roles/labview
molecule test
```

The `default` scenario runs the `host` role, creates a VM with the `vms` role, deploys labview, and then asserts the account, the binary version, the directory modes, the unit, the polkit rule, and that the running service serves the machine the `vms` role wrote.
