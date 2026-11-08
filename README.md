# Pad Commander

Dateimanager mit **zwei Fenstern** fürs iPad, im Stil der klassischen Commander-Programme (graue 3D-Knöpfe,
blaue Titelleiste, F-Tasten-Leiste). Zweites Design „Nacht“ (dunkel, abgerundet). Selbst geschrieben in Swift/SwiftUI,
kein umgebautes Windows-Programm.

## Was er kann

- Zwei Dateifenster nebeneinander, Laufwerksleiste, Pfadzeile, Spalten Name / Erw. / Größe / Datum (antippen = sortieren)
- **F3** Ansehen (Bilder, PDF, Video, Musik, Office … mit Markieren/Zeichnen), **F4** Texteditor, **F5** Kopieren,
  **F6** Verschieben, **F7** Neuer Ordner, **F8** Löschen, **F9** Teilen, **F2** Umbenennen
- Kopieren/Verschieben mit Fortschritt, Abbrechen und Nachfrage bei vorhandenen Dateien (überschreiben, alle, überspringen, umbenennen)
- **ZIP** packen und entpacken (eigene Umsetzung, ohne Fremdbibliothek)
- Markieren: Symbol antippen, Leertaste, Gruppe per Platzhalter (`*.jpg`), alles, umkehren, **Ordner vergleichen**
- Suchen nach Namen (Platzhalter) und Inhalt, Ordnergrößen, Eigenschaften, versteckte Dateien
- **Orte** aus der Dateien-App einbinden: iCloud Drive, USB-Stick, Netzlaufwerk (SMB), Ordner anderer Apps
- Ziehen und Ablegen zwischen den Fenstern und aus anderen Apps, „Öffnen in … Pad Commander“ (landet in `iPad:\Eingang`)
- Volle Tastatursteuerung mit Hardware-Tastatur (Pfeile, Tab, Enter, F-Tasten, Strg+U …), siehe Hilfe (F1)
- Der App-Ordner ist in der Dateien-App unter **Auf meinem iPad › Pad Commander** sichtbar

## Installieren (kostenlos, ohne App Store)

Apple erlaubt Apps außerhalb des App Stores nur mit einer Signatur. Mit einer **kostenlosen Apple-ID** geht das so:

1. Die neueste `PadCommander.ipa` von der [Release-Seite](https://github.com/Sxbyy/pad-commander/releases/latest) laden.
2. Auf dem Windows-PC **Sideloadly** installieren (sideloadly.io, kostenlos). Sideloadly braucht iTunes und iCloud
   von der Apple-Webseite (nicht die Microsoft-Store-Version).
3. iPad per USB-Kabel anschließen, dem PC vertrauen.
4. In Sideloadly die IPA hineinziehen, Apple-ID eintragen, **Start**.
5. Auf dem iPad: *Einstellungen › Datenschutz & Sicherheit › Entwicklermodus* einschalten (Neustart), dann
   *Einstellungen › Allgemein › VPN & Geräteverwaltung* › deiner Apple-ID vertrauen.

**Wichtig:** Mit kostenloser Apple-ID läuft die Signatur nach **7 Tagen** ab. Dann in Sideloadly einfach wieder
„Start“ drücken (die Daten in der App bleiben erhalten). Sideloadly kann das auch automatisch über WLAN erneuern.

## Bauen

Ohne Mac: Jeder Push auf `main` baut über GitHub Actions (macOS-Rechner) eine unsignierte IPA, testet die App im
iPad-Simulator (mit Bildschirmfotos auf dem Zweig `ci-results`) und legt die IPA als Release `latest` ab.
Projekt wird mit [XcodeGen](https://github.com/yonaskolb/XcodeGen) aus `project.yml` erzeugt.
