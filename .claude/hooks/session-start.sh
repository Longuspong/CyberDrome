#!/bin/bash
# Stellt Godot fuer eine Web-Session bereit.
#
# Das Repo hat sonst keine Abhaengigkeiten: main.py laeuft auf der
# Python-Standardbibliothek, tools/check_workshop_stats.js auf Node-Builtins.
# Godot fehlt -- und ohne Godot ist von diesem Projekt nur die Haelfte
# pruefbar: die Testsuite liegt in GDScript, und ob ein Betonpfeiler den
# DROME davor verdeckt, sieht ohnehin kein Unit-Test.
#
# Die Version ist an project.godot gebunden:
#   config/features=PackedStringArray("4.3", "GL Compatibility")
# Wer sie dort hebt, hebt sie hier mit -- sonst importiert eine andere
# Engine die Assets, als das Projekt erwartet.

set -euo pipefail

# Nur in der Web-Session. Lokal bringt der Entwickler sein eigenes Godot mit,
# und das soll dieser Hook nicht ueberschreiben.
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

GODOT_VERSION="4.3-stable"
GODOT_ZIP="Godot_v${GODOT_VERSION}_linux.x86_64.zip"
GODOT_BIN_NAME="Godot_v${GODOT_VERSION}_linux.x86_64"
GODOT_URL="https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}/${GODOT_ZIP}"

# Genau das Archiv, gegen das die Suite hier gruen gelaufen ist. Ein
# stillschweigend ausgetauschtes Binary faellt damit auf, statt zu wirken.
GODOT_SHA256="7de56444b130b10af84d19c7e0cf63cf9e9937ee4ba94364c3b7dd114253ca21"

INSTALL_DIR="/opt/godot/${GODOT_VERSION}"
GODOT_BIN="${INSTALL_DIR}/${GODOT_BIN_NAME}"

# --- Godot holen, falls nicht schon da ------------------------------------
# Der Containerzustand wird nach dem Hook zwischengespeichert. Beim zweiten
# Lauf greift dieser Zweig, und der Hook ist in Sekunden durch.
if [ -x "${GODOT_BIN}" ] && "${GODOT_BIN}" --version >/dev/null 2>&1; then
  echo "Godot ${GODOT_VERSION} liegt bereits unter ${INSTALL_DIR}"
else
  echo "Godot ${GODOT_VERSION} wird geholt ..."
  mkdir -p "${INSTALL_DIR}"
  tmp="$(mktemp -d)"
  trap 'rm -rf "${tmp}"' EXIT

  curl -fsSL --retry 3 --retry-delay 2 -o "${tmp}/${GODOT_ZIP}" "${GODOT_URL}"

  echo "${GODOT_SHA256}  ${tmp}/${GODOT_ZIP}" | sha256sum -c - >/dev/null
  echo "Pruefsumme stimmt."

  unzip -o -q "${tmp}/${GODOT_ZIP}" -d "${INSTALL_DIR}"
  chmod +x "${GODOT_BIN}"
fi

# --- Unter dem Namen erreichbar machen, den der README nennt ---------------
# README und docs/ schreiben durchgehend `godot --headless ...`. Wer die
# Befehle von dort kopiert, soll sie unveraendert ausfuehren koennen.
ln -sf "${GODOT_BIN}" /usr/local/bin/godot

if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
  # Nur einmal eintragen: der Hook laeuft auch bei resume und compact.
  if ! grep -qs "^export GODOT=" "${CLAUDE_ENV_FILE}"; then
    echo "export GODOT=\"${GODOT_BIN}\"" >> "${CLAUDE_ENV_FILE}"
  fi
fi

echo "godot: $(godot --version 2>/dev/null | tail -1)"

# --- Importcache vorwaermen ------------------------------------------------
# Godot importiert rund 370 SVGs beim ersten Start. Das dauert Minuten und
# passiert sonst mitten im ersten Testlauf, wo es wie ein haengender Test
# aussieht. Hier kostet es einmalig Zeit und wird mit zwischengespeichert.
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

if [ -f "${PROJECT_DIR}/project.godot" ]; then
  if [ -d "${PROJECT_DIR}/.godot/imported" ]; then
    echo "Importcache steht, wird nur nachgezogen ..."
  else
    echo "Assets werden importiert (einmalig, dauert einige Minuten) ..."
  fi
  godot --headless --path "${PROJECT_DIR}" --import >/dev/null 2>&1 || {
    echo "Import fehlgeschlagen -- Godot ist trotzdem nutzbar," >&2
    echo "der erste Testlauf importiert dann selbst nach." >&2
  }
  echo "Assets importiert."
fi

# Fuer tests/screenshot.gd. In dieser Umgebung vorhanden; falls nicht, ist
# das kein Grund die Session zu blockieren -- nur die Bilder fallen aus.
if ! command -v xvfb-run >/dev/null 2>&1; then
  echo "Hinweis: xvfb-run fehlt, tests/screenshot.gd kann nicht rendern." >&2
fi

echo "Bereit. Tests: godot --headless --path . --script res://tests/run_tests.gd"
