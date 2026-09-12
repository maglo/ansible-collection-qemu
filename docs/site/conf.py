# Copyright (c) maglo
# GNU General Public License v3.0 only (see LICENSE)
# SPDX-License-Identifier: GPL-3.0-only

"""Sphinx configuration for the maglo.qemu documentation site.

The site is built from two sources:

* ``docs/docsite/rst`` — the hand-written guides. antsibull-docs copies them
  into ``docs/site/collection/docsite`` and Ansible Galaxy renders the same
  files in its documentation tab.
* ``roles/*/meta/argument_specs.yml`` — the role reference, generated into
  ``docs/site/collection`` by antsibull-docs.

Everything under ``docs/site/collection`` is therefore generated; run
``docs/site/build.sh`` (or ``make docs``) instead of writing files there.
"""

from pathlib import Path

import yaml

SITE_DIR = Path(__file__).resolve().parent
_galaxy = yaml.safe_load((SITE_DIR.parent.parent / "galaxy.yml").read_text(encoding="utf-8"))

# Furo inlines this markup in the footer; keeping it in a file keeps conf.py
# readable and its lines within the length the pep8 sanity test allows.
GITHUB_ICON = (SITE_DIR / "_static" / "github.svg").read_text(encoding="utf-8")

project = "maglo.qemu"
author = "maglo"
copyright = "maglo — GPL-3.0-only"  # noqa: A001
version = _galaxy["version"]
release = version

title = "maglo.qemu collection"
html_short_title = "maglo.qemu"

extensions = [
    "sphinx_antsibull_ext",
    "sphinx_copybutton",
    "sphinx_design",
]

# The generated collection tree is written into the source directory, so keep
# the build output and the tooling files out of the document set. The two
# generated index pages go with them: index.rst is antsibull-docs' own
# collection landing page, which this site replaces, and the environment
# variable index is empty because the collection ships no plugins.
exclude_patterns = [
    "_build",
    "requirements.txt",
    "README.md",
    "collection/index.rst",
    "collection/environment_variables.rst",
]

pygments_style = "ansible"
highlight_language = "YAML+Jinja"


html_theme = "furo"
html_title = f"maglo.qemu {version}"
html_static_path = ["_static"]
html_css_files = ["custom.css"]
html_logo = "_static/logo.svg"
html_favicon = "_static/logo.svg"
html_copy_source = False
html_show_sourcelink = False
html_show_sphinx = False
html_use_index = False

html_theme_options = {
    "light_css_variables": {
        "color-brand-primary": "#0b5d8f",
        "color-brand-content": "#0b5d8f",
        "font-stack": "system-ui, -apple-system, 'Segoe UI', Roboto, sans-serif",
    },
    "dark_css_variables": {
        "color-brand-primary": "#6bc1f0",
        "color-brand-content": "#6bc1f0",
    },
    "footer_icons": [
        {
            "name": "GitHub",
            "url": "https://github.com/maglo/ansible-collection-qemu",
            "html": GITHUB_ICON,
            "class": "",
        },
    ],
}
