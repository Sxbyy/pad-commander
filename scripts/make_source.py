#!/usr/bin/env python3
"""Erzeugt source.json fuer SideStore / AltStore.

Mit dieser Quelle laesst sich Pad Commander direkt auf dem iPad installieren und aktualisieren.

Aufruf: make_source.py <ziel.json> <version> <build> <ipa> <ordner-mit-screen-*.png>
"""
import datetime
import json
import pathlib
import sys

BASE = "https://github.com/Sxbyy/pad-commander/releases/download/latest/"
DESCRIPTION = (
    "Dateimanager mit zwei Fenstern im Stil der klassischen Commander-Programme: "
    "F-Tasten-Leiste (F3 Ansehen, F4 Bearbeiten, F5 Kopieren, F6 Verschieben, F7 Neuer Ordner, F8 Löschen), "
    "ZIP packen und entpacken, Suche, Ordner vergleichen, Orte aus der Dateien-App (iCloud Drive, USB, Netzlaufwerk), "
    "Ziehen und Ablegen, volle Tastatursteuerung. Designs Klassisch und Nacht."
)


def main() -> None:
    out, version, build, ipa, shots_dir = sys.argv[1:6]
    size = pathlib.Path(ipa).stat().st_size
    shots = sorted(p.name for p in pathlib.Path(shots_dir).glob("screen-*.png"))
    now = datetime.datetime.now(datetime.timezone.utc).replace(microsecond=0)
    stamp = now.strftime("%Y-%m-%dT%H:%M:%SZ")
    notes = f"Version {version} (Build {build}) vom {now.strftime('%d.%m.%Y')}."
    app = {
        "name": "Pad Commander",
        "bundleIdentifier": "de.sxbyy.padcommander",
        "developerName": "Sxbyy",
        "subtitle": "Dateimanager mit zwei Fenstern fürs iPad",
        "localizedDescription": DESCRIPTION,
        "iconURL": BASE + "icon.png",
        "tintColor": "#000080",
        "category": "utilities",
        "screenshotURLs": [BASE + s for s in shots],
        "versions": [
            {
                "version": version,
                "buildVersion": build,
                "date": stamp,
                "localizedDescription": notes,
                "downloadURL": BASE + "PadCommander.ipa",
                "size": size,
                "minOSVersion": "17.0",
            }
        ],
        "appPermissions": {"entitlements": [], "privacy": {}},
        # Felder fuer aeltere SideStore-/AltStore-Versionen
        "version": version,
        "versionDate": stamp,
        "versionDescription": notes,
        "downloadURL": BASE + "PadCommander.ipa",
        "size": size,
    }
    source = {
        "name": "Pad Commander",
        "identifier": "de.sxbyy.padcommander.source",
        "subtitle": "Zwei-Fenster-Dateimanager fürs iPad",
        "description": DESCRIPTION,
        "iconURL": BASE + "icon.png",
        "website": "https://github.com/Sxbyy/pad-commander",
        "tintColor": "#000080",
        "apps": [app],
        "news": [],
    }
    pathlib.Path(out).write_text(json.dumps(source, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"{out}: Version {version} ({build}), {size} Bytes, {len(shots)} Bildschirmfotos")


if __name__ == "__main__":
    main()
