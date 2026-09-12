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

GALAXY_YML = Path(__file__).resolve().parents[2] / "galaxy.yml"
_galaxy = yaml.safe_load(GALAXY_YML.read_text(encoding="utf-8"))

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
            "html": (
                '<svg viewBox="0 0 16 16" fill="currentColor" aria-hidden="true">'
                '<path fill-rule="evenodd" d="M8 0C3.58 0 0 3.58 0 8c0 3.54 2.29 6.53 5.47 7.59.4.07.55-.17.55-.38 0-.19-.01-.82-.01-1.49-2.01.37-2.53-.49-2.69-.94-.09-.23-.48-.94-.82-1.13-.28-.15-.68-.52-.01-.53.63-.01 1.08.58 1.23.82.72 1.21 1.87.87 2.33.66.07-.52.28-.87.51-1.07-1.78-.2-3.64-.89-3.64-3.95 0-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82.63-.18 1.31-.27 1.98-.27.67 0 1.35.09 1.98.27 1.53-1.04 2.2-.82 2.2-.82.44 1.1.16 1.92.08 2.12.51.56.82 1.27.82 2.15 0 3.07-1.87 3.75-3.65 3.95.29.25.54.73.54 1.48 0 1.07-.01 1.93-.01 2.2 0 .21.15.46.55.38A8.012 8.012 0 0 0 16 8c0-4.42-3.58-8-8-8z"></path></svg>'
            ),
            "class": "",
        },
    ],
}
