#!/usr/bin/env python3
"""Holt NUR die Web-Export-Templates aus dem Godot-Release.

Das offizielle Templatepaket (.tpz) ist ein ZIP mit allen Plattformen,
rund 1,3 GB. Der Web-Export braucht daraus zwei Dateien zu je ~10 MB. Statt
das ganze Paket zu laden, liest dieses Skript per HTTP-Range nur das
Inhaltsverzeichnis am Ende des ZIP und dann genau diese zwei Eintraege.

    python3 tools/fetch_web_templates.py            # nach ~/.local/share/godot/...
    python3 tools/fetch_web_templates.py ZIELORDNER

Nur Standardbibliothek. Die Version ist an project.godot gebunden (wie in
.claude/hooks/session-start.sh); wer sie hebt, hebt hier mit -- inklusive der
Pruefsummen.

Die Pruefsummen sind die der Eintraege, wie sie aus dem 4.7-stable-Paket
gelesen wurden. Godot veroeffentlicht nur Summen fuer das ganze .tpz, nicht
fuer die Eintraege -- gegen diese Zahlen geprueft faellt aber ein
ausgetauschtes oder kaputtes Template auf, statt still exportiert zu werden.
Zusaetzlich prueft zipfile beim Lesen die CRC jedes Eintrags.
"""

import hashlib
import io
import os
import ssl
import sys
import urllib.request
import zipfile

GODOT_VERSION = "4.7-stable"
TEMPLATE_DIR_NAME = "4.7.stable"
URL = ("https://github.com/godotengine/godot/releases/download/"
       f"{GODOT_VERSION}/Godot_v{GODOT_VERSION}_export_templates.tpz")

WANTED = {
    "templates/web_nothreads_release.zip":
        "6e1d01e7d8995a2dfec8b33dc530f02c034906267ec441288c2a3318d49e00b9",
    "templates/web_nothreads_debug.zip":
        "3467f4b041216d43f0abd590bb995bf6c8eb1e2de715e1d7c9b5b765509efeb8",
}


def _ssl_context():
    # Hinter einem Proxy mit eigener CA (z. B. Cloud-Sessions) liegt das
    # Buendel unter SSL_CERT_FILE; sonst gilt der Systemstandard.
    cafile = os.environ.get("SSL_CERT_FILE")
    return ssl.create_default_context(cafile=cafile) if cafile else None


class RangeFile(io.RawIOBase):
    """Eine entfernte Datei, die sich wie eine lokale lesen und springen laesst."""

    def __init__(self, url):
        self._ctx = _ssl_context()
        head = urllib.request.urlopen(
            urllib.request.Request(url, method="HEAD"), context=self._ctx)
        self.url = head.geturl()          # nach der Weiterleitung
        self.size = int(head.headers["Content-Length"])
        self.pos = 0

    def readable(self):
        return True

    def seekable(self):
        return True

    def tell(self):
        return self.pos

    def seek(self, offset, whence=0):
        base = {0: 0, 1: self.pos, 2: self.size}[whence]
        self.pos = base + offset
        return self.pos

    def readinto(self, buffer):
        count = min(len(buffer), self.size - self.pos)
        if count <= 0:
            return 0
        request = urllib.request.Request(self.url, headers={
            "Range": f"bytes={self.pos}-{self.pos + count - 1}"})
        data = urllib.request.urlopen(request, context=self._ctx).read()
        buffer[:len(data)] = data
        self.pos += len(data)
        return len(data)


def main():
    target = sys.argv[1] if len(sys.argv) > 1 else os.path.expanduser(
        f"~/.local/share/godot/export_templates/{TEMPLATE_DIR_NAME}")
    os.makedirs(target, exist_ok=True)

    archive = zipfile.ZipFile(io.BufferedReader(RangeFile(URL), buffer_size=1 << 20))
    for name, expected in WANTED.items():
        data = archive.read(name)
        digest = hashlib.sha256(data).hexdigest()
        if digest != expected:
            sys.exit(f"Pruefsumme falsch fuer {name}: {digest}")
        out = os.path.join(target, os.path.basename(name))
        with open(out, "wb") as handle:
            handle.write(data)
        print(f"{name} -> {out} ({len(data)} Bytes, Pruefsumme stimmt)")


if __name__ == "__main__":
    main()
