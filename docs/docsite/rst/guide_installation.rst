.. _ansible_collections.maglo.qemu.docsite.guide_installation:

Installation
============

This page covers what the collection needs from a host, how to install it, and
which platforms it supports.

Requirements
------------

.. list-table::
   :header-rows: 1
   :widths: 30 70

   * - Component
     - Requirement
   * - Control node
     - ``ansible-core`` 2.15 or newer. CI runs the sanity tests against
       ``stable-2.16`` and ``stable-2.17``.
   * - Target host
     - Enterprise Linux 10 (RHEL, Rocky, Alma, CentOS).
   * - CPU
     - Hardware virtualization (Intel VT-x or AMD-V) enabled in the
       BIOS/UEFI — see `Verify hardware virtualization`_.
   * - Packages
     - The EPEL repository, or an equivalent mirror — see
       `Package repositories`_.
   * - Privileges
     - The roles install packages and write under ``/etc`` and ``/var/lib``,
       so run the plays with ``become: true``.

Installing the collection
-------------------------

.. code-block:: bash

   ansible-galaxy collection install maglo.qemu

Or pin it in a ``requirements.yml`` next to your playbooks:

.. code-block:: yaml

   collections:
     - name: maglo.qemu

.. code-block:: bash

   ansible-galaxy collection install -r requirements.yml

The collection has no collection dependencies. Its releases are published to
`Ansible Galaxy <https://galaxy.ansible.com/ui/repo/published/maglo/qemu/>`_
and attached to the `GitHub releases
<https://github.com/maglo/ansible-collection-qemu/releases>`_ as a tarball,
which ``ansible-galaxy collection install ./maglo-qemu-*.tar.gz`` also accepts.

Verify hardware virtualization
------------------------------

A VM needs KVM acceleration. Confirm the target host exposes it:

.. code-block:: bash

   # Must return a non-zero number
   grep -c -E '(vmx|svm)' /proc/cpuinfo

   # Alternatively, check for the KVM kernel module
   lsmod | grep kvm

If the count is ``0`` or the module is missing, enable Intel VT-x / AMD-V in
the BIOS/UEFI settings. Nested virtualization — running this collection inside
a VM — needs the same flag exposed to that guest by its own hypervisor.

Package repositories
--------------------

The ``maglo.qemu.host`` role installs ``swtpm``, ``swtpm-tools``, ``socat``,
and ``genisoimage``. These come from **EPEL** (Extra
Packages for Enterprise Linux). Enable it before the first run:

.. code-block:: bash

   dnf install epel-release

.. note::

   The collection does not manage EPEL itself. Enabling a third-party
   repository automatically is the wrong default for an airgapped or otherwise
   restricted host. Enable EPEL yourself, or point the host at a mirror that
   carries these packages.

Next steps
----------

- :ref:`ansible_collections.maglo.qemu.docsite.guide_host` — prepare the hypervisor host
- :ref:`ansible_collections.maglo.qemu.docsite.guide_vm_management` — create and manage VMs
- :ref:`ansible_collections.maglo.qemu.docsite.guide_examples` — ready-to-run playbooks
