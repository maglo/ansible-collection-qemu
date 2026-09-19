.. _ansible_collections.maglo.qemu.docsite.guide_console_service:

Console service
===============

A console service serves every machine's framebuffer, serial line and details
on one page, behind one port. It replaces one noVNC instance per VM on a port
derived from the VM name, and it adds two channels a browser never had: the
serial line, and a control channel that can send a key chord, take a frame or
power a machine.

The collection deploys `labview <https://github.com/maglo/qemu-lab-manager>`_
with the ``maglo.qemu.labview`` role.

The shape
---------

.. code-block:: text

                      console   127.0.0.1:590N
    browser --443--> reverse --8080--> console --- serial    <vm>/serial.sock
             TLS     proxy             service    control   <vm>/qmp.sock
             + SSO                                 power     systemd D-Bus + polkit

All four channels are local to the hypervisor. The console service becomes the
only path to a machine, which is what makes its write lease mean anything: one
client holds the keyboard at a time, and everyone else watches.

Deploying it
------------

Three roles, in order. The ``host`` role creates the QEMU service group and
leaves the sockets group writable; the ``vms`` role writes one inventory file
per VM; the ``labview`` role serves them.

.. code-block:: yaml

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

``vms_labview_inventory_dir`` and ``labview_inventory_dir`` must name the same
directory. They both default to nothing useful on their own: the ``vms`` role
writes no inventory unless the variable is set, and labview serves an empty lab
if it is pointed somewhere nothing was written.

``playbooks/labview.yml`` is this, ready to run.

Why the sockets are group writable
----------------------------------

labview runs under its own account and joins the QEMU service group to open
the serial and QMP sockets of a VM. That works because ``host_vm_umask`` is
``0007``, which leaves the sockets at ``0770``.

Under systemd's own default umask they would be ``0755``, and connecting to a
UNIX socket needs the *write* bit, so labview would be refused on every machine
even though it is in the right group. See
:ref:`ansible_collections.maglo.qemu.docsite.guide_host`.

Why the polkit rule is mandatory
--------------------------------

The role installs a polkit rule granting the labview account
``start``, ``stop`` and ``restart`` on the VM units, and nothing else.

It is not optional. A system service has no logind session, so polkit evaluates
a power operation as neither local nor active, falls through to ``auth_admin``,
and finds no agent to answer the prompt. Every power operation then fails, and
it fails in a way that reads as a console service fault rather than a missing
rule.

Running the service as ``root`` would hide the problem rather than solve it:
systemd short-circuits the privilege check for a root caller, so polkit never
runs and the rule bounds nothing.

Two layers have to agree before a machine is restarted. labview maps a machine
to a unit through the inventory, so it can only ask about units the inventory
named. The rule is the host's own opinion about which units that account may
touch, so a mistake in the inventory cannot become "restart anything on this
hypervisor". ``labview_unit_pattern`` narrows it further:

.. code-block:: yaml

   labview_unit_pattern: '^qemu-vm@lab-[A-Za-z0-9._-]+\.service$'

Putting a proxy in front
------------------------

``labview_listen`` is ``127.0.0.1:8080``, and the role warns when it is set to
anything else. labview authenticates nobody: whoever can reach it holds the
write lease of every machine, so the address it binds is the whole access
control story until a proxy provides one.

The role deploys no proxy and manages no TLS material. Which proxy terminates
TLS and how a person is authenticated — OIDC, mTLS, ``auth_request``, basic
auth — is site policy, and the collection does not choose it.

What is not site policy is what any proxy has to do. Three things, each of
which fails in a way that looks like a console service bug:

1. **Forward the original** ``Host`` **header.** labview's websocket origin
   check compares ``Origin`` against ``Host``. A proxy that rewrites ``Host``
   to ``127.0.0.1:8080`` makes every websocket look cross-origin, and every
   console is refused.
2. **Set the identity header on the websocket upgrade**, not only on ordinary
   requests. ``labview_identity_header`` — ``X-Forwarded-User`` by default — is
   the only thing naming the lease holder. A proxy that sets it on plain HTTP
   alone leaves every console and serial socket unidentified, so no lease
   matches the person holding it and nobody can type.
3. **Discard any client-supplied identity header.** labview trusts it
   completely, and it is the only thing in the audit trail, so the proxy must
   overwrite it rather than pass it through.

An nginx location that does all three:

.. code-block:: nginx

   location / {
       proxy_pass http://127.0.0.1:8080;

       # (1) the origin check compares Origin to Host
       proxy_set_header Host $host;

       # (2) and (3): set from the authenticated identity, overwriting
       # whatever the client sent, in the same location that handles the
       # upgrade
       proxy_set_header X-Forwarded-User $remote_user;

       proxy_http_version 1.1;
       proxy_set_header Upgrade    $http_upgrade;
       proxy_set_header Connection $connection_upgrade;

       # a wall tile is a long lived view; without this the proxy closes
       # consoles that are working perfectly well
       proxy_read_timeout 1h;
       proxy_send_timeout 1h;

       # a framebuffer is latency sensitive and already compressed
       proxy_buffering off;
   }

``deploy/nginx-labview.conf`` upstream is a complete worked example.

Where a proxy asserts identity under another name, point labview at it:

.. code-block:: yaml

   labview_identity_header: X-Auth-Request-User

Identity is not an authorisation input. Everyone who gets past the proxy sees
every machine; the header decides who holds the keyboard, not who may look.

Guest boot output
-----------------

A VM's serial console is a socket rather than stdout, so it no longer reaches
the journal of ``qemu-vm@<name>.service``. The console service records a
transcript per run under ``labview_recordings_dir`` instead, and reads no host
journal at all.

A consumer who read guest boot output with ``journalctl -u qemu-vm@<name>``
reads the transcript now, or watches the serial tab while the guest boots.

Troubleshooting
---------------

**Every console is refused, or the serial line never connects.** Check the mode
of the sockets. They must be group writable and the labview account must be in
that group:

.. code-block:: console

   # ls -l /var/lib/qemu/web01/
   srwxrwx--- 1 qemu qemu 0 ... qmp.sock
   srwxrwx--- 1 qemu qemu 0 ... serial.sock
   # id labview
   uid=...(labview) gid=...(labview) groups=...(labview),...(qemu)

``0755`` sockets mean ``host_vm_umask`` is not in effect. It applies when QEMU
creates the socket, so a VM that was already running when the host role changed
keeps the old mode until its unit restarts.

**Every power operation fails.** Check that the polkit rule is installed and
that its pattern matches the unit names in the inventory. polkit watches its
rules directory and picks a new rule up by itself, so there is nothing to
reload.

**The page loads but no machines appear.** labview serves what the inventory
directory holds. Check that ``vms_labview_inventory_dir`` was set on the run
that created the VMs, and that it names the same directory as
``labview_inventory_dir``.

See also
--------

- :ref:`ansible_collections.maglo.qemu.docsite.guide_host` — the socket modes
- :ref:`ansible_collections.maglo.qemu.docsite.guide_features` — the consoles
  of a VM and the inventory file the ``vms`` role writes
