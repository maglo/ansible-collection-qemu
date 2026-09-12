#!/usr/bin/env bash
# Copyright (c) maglo
# SPDX-License-Identifier: GPL-3.0-only
#
# Build the maglo.qemu documentation site into docs/site/_build/html.
#
# The role reference and the guides under docs/docsite/rst are generated into
# docs/site/collection by antsibull-docs, which needs the collection to be
# reachable under an ansible_collections/maglo/qemu path. This script builds
# that path in a temporary directory, so it works from a plain git checkout.
#
# Usage:
#   pip install -r docs/site/requirements.txt
#   docs/site/build.sh            # build
#   docs/site/build.sh --serve    # build, then serve on http://localhost:8000

set -euo pipefail

site_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_dir="$(cd "${site_dir}/../.." && pwd)"
generated_dir="${site_dir}/collection"
build_dir="${site_dir}/_build/html"

collection_root="$(mktemp -d)"
trap 'rm -rf "${collection_root}"' EXIT
mkdir -p "${collection_root}/ansible_collections/maglo"
ln -s "${repo_dir}" "${collection_root}/ansible_collections/maglo/qemu"

echo "==> Generating the collection reference into docs/site/collection"
rm -rf "${generated_dir}"
mkdir -p "${generated_dir}"
ANSIBLE_COLLECTIONS_PATH="${collection_root}" antsibull-docs collection \
  --use-current \
  --squash-hierarchy \
  --no-indexes \
  --fail-on-error \
  --dest-dir "${generated_dir}" \
  maglo.qemu

# antsibull-docs puts a `.. contents::` block at the top of every generated
# page. Furo renders a local table of contents as an error, because it already
# shows one in the right-hand sidebar, so drop those blocks.
echo "==> Dropping the local tables of contents from the generated pages"
python3 - "${generated_dir}" <<'PY'
import re
import sys
from pathlib import Path

CONTENTS = re.compile(r"^\.\. contents::\n(?:[ \t]+:[^\n]*\n)*\n?", re.MULTILINE)

for path in Path(sys.argv[1]).rglob("*.rst"):
    text = path.read_text(encoding="utf-8")
    stripped = CONTENTS.sub("", text)
    if stripped != text:
        path.write_text(stripped, encoding="utf-8")
PY

echo "==> Building the HTML site into docs/site/_build/html"
sphinx-build -W --keep-going -b html "${site_dir}" "${build_dir}"

# GitHub Pages serves the site through Jekyll unless told otherwise, and Jekyll
# drops every directory whose name starts with an underscore — which is where
# Sphinx puts its CSS and JavaScript.
touch "${build_dir}/.nojekyll"

echo "==> Done: ${build_dir}/index.html"

if [[ "${1:-}" == "--serve" ]]; then
  echo "==> Serving on http://localhost:8000 (Ctrl-C to stop)"
  python3 -m http.server 8000 --directory "${build_dir}"
fi
