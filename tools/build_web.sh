#!/bin/bash
# Baut das Spiel als PWA nach build/web -- fuer Vercel UND den GitHub-Workflow.
#
#   bash tools/build_web.sh
#
# Holt Godot (Pruefsumme wie in .claude/hooks/session-start.sh) und nur die
# zwei Web-Templates (tools/fetch_web_templates.py), importiert die Assets und
# exportiert mit der Voreinstellung "Web" aus export_presets.cfg.
#
# Braucht nur curl, sha256sum und python3 -- kein unzip, kein sudo: die
# Build-Umgebung von Vercel bringt weder das eine mit noch erlaubt sie das
# andere. Ein vorhandenes `godot` im PATH wird benutzt (lokal, Cloud-Session).
#
# Die Version ist an project.godot gebunden. Wer sie hebt, hebt hier, im
# Session-Hook und in tools/fetch_web_templates.py mit.

set -euo pipefail
cd "$(dirname "$0")/.."

GODOT_VERSION="4.7-stable"
GODOT_SHA256="0b1a6c54c2c619c12e169fe9241edda4b81080b519451cec2984bf0d2c6cb73c"
GODOT_NAME="Godot_v${GODOT_VERSION}_linux.x86_64"
CACHE_DIR="${GODOT_CACHE_DIR:-$PWD/.cache/godot}"

if command -v godot >/dev/null 2>&1 \
    && godot --version 2>/dev/null | grep -q "^${GODOT_VERSION/-/.}"; then
  GODOT="$(command -v godot)"
else
  GODOT="${CACHE_DIR}/${GODOT_NAME}"
  if [ ! -x "${GODOT}" ]; then
    echo "Godot ${GODOT_VERSION} wird geholt ..."
    mkdir -p "${CACHE_DIR}"
    zip="${CACHE_DIR}/${GODOT_NAME}.zip"
    curl -fsSL --retry 3 -o "${zip}" \
      "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}/${GODOT_NAME}.zip"
    echo "${GODOT_SHA256}  ${zip}" | sha256sum -c -
    python3 -m zipfile -e "${zip}" "${CACHE_DIR}"
    chmod +x "${GODOT}"
    rm -f "${zip}"
  fi
fi
echo "Godot: $("${GODOT}" --version | tail -1)"

python3 tools/fetch_web_templates.py

echo "Assets importieren ..."
"${GODOT}" --headless --path . --import

echo "Exportieren ..."
rm -rf build/web
mkdir -p build/web
# Godot soll die eigene Ausgabe beim naechsten Import nicht als Assets einlesen.
touch build/.gdignore
"${GODOT}" --headless --path . --export-release "Web" build/web/index.html

for file in index.html index.pck index.wasm index.manifest.json index.service.worker.js; do
  test -s "build/web/${file}" || { echo "Export unvollstaendig: ${file} fehlt"; exit 1; }
done
touch build/web/.nojekyll
echo "Fertig: build/web ($(du -sh build/web | cut -f1))"
