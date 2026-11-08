#!/usr/bin/env python3
"""Wendet Textersetzungen aus edits/*.edit an (genau wie ein Editor: alter Text muss genau einmal vorkommen).

Format:
### EDIT pfad/zur/datei
--- OLD
alter Text
--- NEW
neuer Text
--- END

### CREATE pfad/zur/datei
--- NEW
Inhalt
--- END
"""
import pathlib
import sys

root = pathlib.Path(__file__).resolve().parent.parent
ok = True
for ef in sorted((root / "edits").glob("*.edit")):
    lines = ef.read_text(encoding="utf-8").split("\n")
    i = 0
    n = 0
    while i < len(lines):
        line = lines[i]
        if line.startswith("### EDIT ") or line.startswith("### CREATE "):
            create = line.startswith("### CREATE ")
            path = line.split(" ", 2)[2].strip()
            i += 1
            old, new, mode = [], [], None
            while i < len(lines) and lines[i] != "--- END":
                if lines[i] == "--- OLD":
                    mode = "old"
                elif lines[i] == "--- NEW":
                    mode = "new"
                elif mode == "old":
                    old.append(lines[i])
                elif mode == "new":
                    new.append(lines[i])
                i += 1
            i += 1
            n += 1
            target = root / path
            if create:
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_text("\n".join(new) + "\n", encoding="utf-8")
                print(f"{ef.name} #{n}: {path} angelegt")
                continue
            if not target.exists():
                print(f"FEHLER {ef.name} #{n}: {path} gibt es nicht")
                ok = False
                continue
            text = target.read_text(encoding="utf-8")
            o, nw = "\n".join(old), "\n".join(new)
            c = text.count(o)
            if c != 1:
                print(f"FEHLER {ef.name} #{n}: {path}: alter Text {c}x gefunden:\n{o[:400]}")
                ok = False
                continue
            target.write_text(text.replace(o, nw), encoding="utf-8")
            print(f"{ef.name} #{n}: {path} geändert")
        else:
            i += 1
    ef.unlink()
sys.exit(0 if ok else 1)
