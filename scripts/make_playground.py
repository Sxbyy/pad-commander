#!/usr/bin/env python3
"""Baut aus den App-Quellen ein Swift-Playground-Paket (PadCommander.swiftpm).

Das Paket laesst sich auf dem iPad in der kostenlosen App „Swift Playground“ oeffnen und mit ▶ starten:
ohne PC, ohne Apple-ID-Signatur und ohne 7-Tage-Ablauf.

Aufruf: make_playground.py <ausgabeordner> <version> <build>
"""
import pathlib
import shutil
import sys

MANIFEST = """// swift-tools-version: 5.9

// Pad Commander als App für „Swift Playground“ auf dem iPad: Paket öffnen und ▶ antippen.
// Diese Datei wird beim Bauen auf GitHub erzeugt (scripts/make_playground.py).

import PackageDescription
import AppleProductTypes

let package = Package(
    name: "PadCommander",
    platforms: [
        .iOS("17.0")
    ],
    products: [
        .iOSApplication(
            name: "Pad Commander",
            targets: ["AppModule"],
            bundleIdentifier: "de.sxbyy.padcommander.playground",
            teamIdentifier: "",
            displayVersion: "@VERSION@",
            bundleVersion: "@BUILD@",
            appIcon: .asset("AppIcon"),
            accentColor: .presetColor(.blue),
            supportedDeviceFamilies: [
                .pad
            ],
            supportedInterfaceOrientations: [
                .portrait,
                .landscapeRight,
                .landscapeLeft,
                .portraitUpsideDown(.when(deviceFamilies: [.pad]))
            ]
        )
    ],
    targets: [
        .executableTarget(
            name: "AppModule",
            path: "."
        )
    ]
)
"""


def main() -> None:
    root = pathlib.Path(__file__).resolve().parent.parent
    out_dir = pathlib.Path(sys.argv[1]).resolve()
    version, build = sys.argv[2], sys.argv[3]
    pkg = out_dir / "PadCommander.swiftpm"
    if pkg.exists():
        shutil.rmtree(pkg)
    pkg.mkdir(parents=True)
    shutil.copytree(root / "PadCommander" / "Sources", pkg / "Sources")
    shutil.copytree(root / "PadCommander" / "Resources" / "Assets.xcassets", pkg / "Assets.xcassets")
    manifest = MANIFEST.replace("@VERSION@", version).replace("@BUILD@", build)
    (pkg / "Package.swift").write_text(manifest, encoding="utf-8")
    files = sorted(p.relative_to(pkg).as_posix() for p in pkg.rglob("*") if p.is_file())
    print(f"{pkg.name}: {len(files)} Dateien")
    for f in files:
        print("  " + f)


if __name__ == "__main__":
    main()
