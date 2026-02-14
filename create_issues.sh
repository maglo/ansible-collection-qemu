#!/usr/bin/env bash
# Helper script to create GitHub issues for ansible-collection-qemu
# Usage: ./create_issues.sh
# Requires: gh CLI authenticated (run `gh auth login` first)

set -euo pipefail

REPO="maglo/ansible-collection-qemu"

echo "Creating issues in ${REPO}..."
echo ""

###############################################################################
# Issue 1: noVNC per-VM port allocation
###############################################################################
echo "--- Creating: noVNC per-VM websocket proxy issue ---"
NOVNC_ISSUE=$(gh issue create --repo "${REPO}" \
  --label "bug" \
  --title "noVNC: support per-VM websocket proxy ports" \
  --body "$(cat <<'EOF'
## Problem

The current noVNC implementation deploys a single `novnc.service` systemd unit that
listens on one port (default `6080`). This only proxies a single VNC backend.

Each QEMU VM typically exposes its own VNC server on a unique display/port
(e.g. `-vnc :0`, `-vnc :1`, …). To make every VM reachable through the browser
the noVNC websocket proxy must also run once **per VM**, each on its own listen
port and pointing at the correct QEMU VNC backend.

### Current behaviour

- `novnc.service` is a plain (non-template) unit.
- It runs `novnc_proxy --listen 6080` with no `--vnc` target, so it can only
  serve a single VM.
- There is no mechanism to map a VM to its own noVNC proxy instance.

### Expected behaviour

- Each VM that has VNC enabled should get its own noVNC websocket proxy
  instance (e.g. via a systemd template unit `novnc@.service`).
- The proxy port and VNC target should be derived from VM configuration
  (variable list or per-VM dict).
- Port allocation should be deterministic and conflict-free.

## Acceptance criteria

- [ ] Replace or supplement `novnc.service` with a per-VM template unit
      (e.g. `novnc@<vmname>.service`).
- [ ] Each instance listens on a unique port and connects to the correct
      QEMU VNC backend.
- [ ] Existing Molecule tests are updated/extended to verify multi-VM noVNC.
- [ ] `defaults/main.yml` documents the new variables.
- [ ] Role README is updated.
EOF
)")
echo "  Created: ${NOVNC_ISSUE}"

###############################################################################
# Issue 2: create_vm role – umbrella
###############################################################################
echo "--- Creating: create_vm role umbrella issue ---"
UMBRELLA_ISSUE=$(gh issue create --repo "${REPO}" \
  --label "enhancement" \
  --title "Add a create_vm role to fully provision a QEMU virtual machine" \
  --body "$(cat <<'EOF'
## Summary

Today the collection provides `qemu_host` which prepares a host to **run** VMs,
but the actual creation of a VM is left entirely to the operator (manually
writing a `.conf` file with raw `QEMU_ARGS`). A new `create_vm` role should
automate every step needed to bring up a fully functional VM:

1. **Create a virtual block device** (qcow2 image) – see sub-issue.
2. **Ensure UEFI firmware is available** (OVMF/AAVMF) – see sub-issue.
3. **Start swtpm instance per VM** (TPM 2.0 emulation) – see sub-issue.
4. **Configure networking** (bridge/tap or user-mode) – see sub-issue.
5. **Generate the QEMU command / config and start the VM** – see sub-issue.

Each of the above should be tracked as its own sub-issue so work can proceed
in parallel.

## Design notes

- The role should accept a list/dict of VMs with per-VM parameters (name,
  memory, CPUs, disk size, firmware, TPM, network mode, etc.).
- It should integrate with the existing `qemu-vm@.service` template unit from
  `qemu_host`.
- Molecule tests should cover at least the "happy path" of creating a single
  VM with all subsystems enabled.

## Sub-issues

_These will be linked here once created._

- [ ] Create virtual block device (qcow2)
- [ ] Ensure UEFI firmware (OVMF)
- [ ] Per-VM swtpm instance
- [ ] Networking setup (bridge/tap)
- [ ] Generate VM config and start the VM
EOF
)")
echo "  Created: ${UMBRELLA_ISSUE}"

# Extract umbrella issue number for cross-referencing
UMBRELLA_NUM=$(echo "${UMBRELLA_ISSUE}" | grep -oP '\d+$')

###############################################################################
# Sub-issue 2a: Virtual block device
###############################################################################
echo "--- Creating: create_vm sub-issue – block device ---"
SUB_BLOCK=$(gh issue create --repo "${REPO}" \
  --label "enhancement" \
  --title "create_vm: create virtual block device (qcow2 image)" \
  --body "$(cat <<BODY
Part of #${UMBRELLA_NUM}

## Goal

Add tasks to the \`create_vm\` role that create a qcow2 virtual disk image for
each VM.

## Requirements

- Use \`qemu-img create -f qcow2\` to create the image.
- Disk size, path, and format should be configurable per VM.
- Idempotent: skip creation if the image already exists.
- Set correct ownership (\`qemu:qemu\`) and permissions.

## Acceptance criteria

- [ ] Task creates a qcow2 image at the configured path/size.
- [ ] Task is idempotent (no-op on re-run when image exists).
- [ ] Molecule test verifies the image is created with expected size.
BODY
)")
echo "  Created: ${SUB_BLOCK}"

###############################################################################
# Sub-issue 2b: UEFI firmware
###############################################################################
echo "--- Creating: create_vm sub-issue – UEFI firmware ---"
SUB_UEFI=$(gh issue create --repo "${REPO}" \
  --label "enhancement" \
  --title "create_vm: ensure UEFI firmware (OVMF) is available" \
  --body "$(cat <<BODY
Part of #${UMBRELLA_NUM}

## Goal

Ensure OVMF (or AAVMF on aarch64) firmware packages are installed so VMs can
boot with UEFI.

## Requirements

- Install the appropriate firmware package (\`edk2-ovmf\` on EL).
- Provide a variable to select UEFI vs. legacy BIOS boot per VM.
- When UEFI is selected, add the correct \`-drive if=pflash,...\` arguments to
  \`QEMU_ARGS\`.
- Create a per-VM copy of the OVMF_VARS file so each VM has its own NVRAM.

## Acceptance criteria

- [ ] OVMF package is installed when any VM requests UEFI boot.
- [ ] Per-VM NVRAM vars file is created.
- [ ] Molecule test verifies firmware file exists and QEMU_ARGS contain the
      pflash entries.
BODY
)")
echo "  Created: ${SUB_UEFI}"

###############################################################################
# Sub-issue 2c: swtpm per VM
###############################################################################
echo "--- Creating: create_vm sub-issue – swtpm ---"
SUB_TPM=$(gh issue create --repo "${REPO}" \
  --label "enhancement" \
  --title "create_vm: start per-VM swtpm instance" \
  --body "$(cat <<BODY
Part of #${UMBRELLA_NUM}

## Goal

Start a dedicated \`swtpm\` process for each VM that requires TPM 2.0 emulation.

## Requirements

- Create a systemd template unit \`swtpm@.service\` (or equivalent) so each VM
  gets its own swtpm socket/state directory.
- State directory: \`/var/lib/swtpm/<vmname>/\` (configurable).
- TPM should be optional and toggled per VM.
- Add the matching \`-chardev socket,...\` and \`-tpmdev emulator,...\` arguments
  to \`QEMU_ARGS\`.

## Acceptance criteria

- [ ] swtpm template unit is deployed.
- [ ] Per-VM state directory is created with correct ownership.
- [ ] Molecule test verifies swtpm service starts and socket is created.
BODY
)")
echo "  Created: ${SUB_TPM}"

###############################################################################
# Sub-issue 2d: Networking
###############################################################################
echo "--- Creating: create_vm sub-issue – networking ---"
SUB_NET=$(gh issue create --repo "${REPO}" \
  --label "enhancement" \
  --title "create_vm: configure VM networking (bridge/tap)" \
  --body "$(cat <<BODY
Part of #${UMBRELLA_NUM}

## Goal

Set up networking for each VM so it can communicate with the host and external
network.

## Requirements

- Support at least two modes, selectable per VM:
  1. **User-mode networking** (\`-nic user\`) – simple, no host config needed.
  2. **Bridge/tap networking** – create a tap interface and attach it to a
     configurable bridge.
- For bridge mode:
  - Ensure the bridge device exists (or document that it must be pre-created).
  - Create a tap device owned by \`qemu\`.
  - Add appropriate \`-netdev tap,...\` and \`-device virtio-net-pci,...\`
    arguments.
- MAC address should be deterministic or configurable per VM.

## Acceptance criteria

- [ ] User-mode networking works out of the box for a VM.
- [ ] Bridge/tap mode creates the tap device and adds correct QEMU_ARGS.
- [ ] Molecule test verifies network arguments in the generated config.
BODY
)")
echo "  Created: ${SUB_NET}"

###############################################################################
# Sub-issue 2e: Generate config and start VM
###############################################################################
echo "--- Creating: create_vm sub-issue – generate config & start ---"
SUB_START=$(gh issue create --repo "${REPO}" \
  --label "enhancement" \
  --title "create_vm: generate VM config and start the VM" \
  --body "$(cat <<BODY
Part of #${UMBRELLA_NUM}

## Goal

Assemble the final \`QEMU_ARGS\` from all sub-components (disk, firmware, TPM,
network, VNC, memory, CPU, etc.) and write the VM config file used by the
existing \`qemu-vm@.service\` template unit.

## Requirements

- Generate \`/etc/qemu/vms/<vmname>.conf\` with the assembled \`QEMU_ARGS\`.
- Template the config from a Jinja2 template so all subsystem arguments are
  composed cleanly.
- Enable and start \`qemu-vm@<vmname>.service\`.
- Support a \`state\` parameter (present/absent/started/stopped) per VM.
- Ensure ordering: block device, firmware, swtpm, and networking must all be
  ready before the VM starts.

## Acceptance criteria

- [ ] Config file is generated with correct QEMU_ARGS for each VM.
- [ ] VM service is enabled and started.
- [ ] Molecule test verifies config content and service state.
BODY
)")
echo "  Created: ${SUB_START}"

###############################################################################
# Issue 3: Ansible Galaxy registration
###############################################################################
echo "--- Creating: Ansible Galaxy registration issue ---"
GALAXY_ISSUE=$(gh issue create --repo "${REPO}" \
  --label "enhancement,infrastructure" \
  --title "Register collection with Ansible Galaxy" \
  --body "$(cat <<'EOF'
## Summary

Publish the `basalt.qemu` collection to Ansible Galaxy so users can install it
with `ansible-galaxy collection install basalt.qemu`.

## Tasks

- [ ] Create an account / namespace `basalt` on [Ansible Galaxy](https://galaxy.ansible.com/).
- [ ] Verify `galaxy.yml` metadata is complete and accurate (version, authors,
      license, description, repository URL, tags).
- [ ] Add a GitHub Actions workflow step (or separate workflow) to build and
      publish the collection tarball on tagged releases.
      ```yaml
      ansible-galaxy collection build
      ansible-galaxy collection publish *.tar.gz --api-key ${{ secrets.GALAXY_API_KEY }}
      ```
- [ ] Store the Galaxy API key as a repository secret (`GALAXY_API_KEY`).
- [ ] Test the publish pipeline with a pre-release version.
- [ ] Update README with Galaxy install instructions and badge.

## References

- [Galaxy publishing docs](https://docs.ansible.com/ansible/latest/galaxy/dev_guide.html)
- Current `galaxy.yml` already defines namespace `basalt` and name `qemu`.
EOF
)")
echo "  Created: ${GALAXY_ISSUE}"

###############################################################################
# Update umbrella issue with sub-issue links
###############################################################################
echo ""
echo "--- Updating umbrella issue with sub-issue links ---"
SUB_BLOCK_NUM=$(echo "${SUB_BLOCK}" | grep -oP '\d+$')
SUB_UEFI_NUM=$(echo "${SUB_UEFI}" | grep -oP '\d+$')
SUB_TPM_NUM=$(echo "${SUB_TPM}" | grep -oP '\d+$')
SUB_NET_NUM=$(echo "${SUB_NET}" | grep -oP '\d+$')
SUB_START_NUM=$(echo "${SUB_START}" | grep -oP '\d+$')

gh issue edit "${UMBRELLA_NUM}" --repo "${REPO}" --body "$(cat <<BODY
## Summary

Today the collection provides \`qemu_host\` which prepares a host to **run** VMs,
but the actual creation of a VM is left entirely to the operator (manually
writing a \`.conf\` file with raw \`QEMU_ARGS\`). A new \`create_vm\` role should
automate every step needed to bring up a fully functional VM:

1. **Create a virtual block device** (qcow2 image) – #${SUB_BLOCK_NUM}
2. **Ensure UEFI firmware is available** (OVMF/AAVMF) – #${SUB_UEFI_NUM}
3. **Start swtpm instance per VM** (TPM 2.0 emulation) – #${SUB_TPM_NUM}
4. **Configure networking** (bridge/tap or user-mode) – #${SUB_NET_NUM}
5. **Generate the QEMU command / config and start the VM** – #${SUB_START_NUM}

## Design notes

- The role should accept a list/dict of VMs with per-VM parameters (name,
  memory, CPUs, disk size, firmware, TPM, network mode, etc.).
- It should integrate with the existing \`qemu-vm@.service\` template unit from
  \`qemu_host\`.
- Molecule tests should cover at least the "happy path" of creating a single
  VM with all subsystems enabled.

## Sub-issues

- [ ] #${SUB_BLOCK_NUM} – Create virtual block device (qcow2)
- [ ] #${SUB_UEFI_NUM} – Ensure UEFI firmware (OVMF)
- [ ] #${SUB_TPM_NUM} – Per-VM swtpm instance
- [ ] #${SUB_NET_NUM} – Networking setup (bridge/tap)
- [ ] #${SUB_START_NUM} – Generate VM config and start the VM
BODY
)"

echo ""
echo "=== All issues created successfully ==="
echo ""
echo "Summary:"
echo "  ${NOVNC_ISSUE}  – noVNC per-VM proxy ports"
echo "  ${UMBRELLA_ISSUE}  – create_vm role (umbrella)"
echo "  ${SUB_BLOCK}  – Sub: block device"
echo "  ${SUB_UEFI}  – Sub: UEFI firmware"
echo "  ${SUB_TPM}  – Sub: swtpm"
echo "  ${SUB_NET}  – Sub: networking"
echo "  ${SUB_START}  – Sub: generate config & start"
echo "  ${GALAXY_ISSUE}  – Ansible Galaxy registration"
