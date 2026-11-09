# Pad Commander

Dateimanager mit **zwei Fenstern** fürs iPad, im Stil der klassischen Commander-Programme (graue 3D-Knöpfe,
blaue Titelleiste, F-Tasten-Leiste). Zweites Design „Nacht“ (dunkel, abgerundet). Selbst geschrieben in Swift/SwiftUI,
kein umgebautes Windows-Programm und nicht mit anderen Herstellern verbunden.

<p>
<img src="https://github.com/Sxbyy/pad-commander/releases/download/latest/screen-1.png" width="49%" alt="Klassisch">
<img src="https://github.com/Sxbyy/pad-commander/releases/download/latest/screen-2.png" width="49%" alt="Nacht">
</p>

## Installieren – drei Wege

Alle Dateien liegen auf der [Release-Seite](https://github.com/Sxbyy/pad-commander/releases/latest).
Alles ist kostenlos.

| | Weg | PC nötig? | Läuft ab? | Eigenes Symbol |
|---|---|---|---|---|
| **1** | **Swift Playground** (direkt auf dem iPad) | nein | nein | nein, Start über Swift Playground |
| **2** | **SideStore** (am iPad installieren und erneuern) | einmal zum Einrichten | alle 7 Tage, erneuert sich am iPad selbst | ja |
| **3** | **Sideloadly** (Notlösung) | jedes Mal | alle 7 Tage am PC erneuern | ja |

### Weg 1: Direkt auf dem iPad mit „Swift Playground“ (ohne PC)

Swift Playground ist Apples kostenlose Programmier-App. Sie baut Pad Commander direkt auf dem iPad und startet ihn.
Es gibt keine Signatur, keine Apple-ID-Anmeldung und keinen 7-Tage-Ablauf.

1. Im App Store **„Swift Playground“** von Apple laden.
2. Auf dem iPad in Safari die Datei **`PadCommander.swiftpm.zip`** von der Release-Seite laden.
3. In der **Dateien**-App unter *Downloads* die ZIP-Datei antippen. Sie wird zu **PadCommander** entpackt.
4. **PadCommander** antippen. Es öffnet sich in Swift Playground. Falls nicht: In Swift Playground die Dateiauswahl öffnen
   und die Datei dort auswählen.
5. Oben auf **▶ (Ausführen)** tippen. Beim ersten Mal dauert das Bauen etwa eine Minute. Danach über die Vollbild-Taste
   groß machen.

Gut zu wissen:
- Gestartet wird immer über Swift Playground. Es gibt kein eigenes Symbol auf dem Home-Bildschirm.
- Der App-Ordner „iPad“ ist hier nicht in der Dateien-App sichtbar, und „Öffnen in … Pad Commander“ gibt es nicht.
  Deine Ordner (iCloud Drive, „Auf meinem iPad“, USB-Stick, Netzlaufwerk) holst du mit **„+“** in der Laufwerksleiste dazu.
- Neue Version: die neue ZIP-Datei laden und wie oben öffnen.

### Weg 2: SideStore (einmal einrichten, danach alles am iPad)

SideStore signiert Apps mit deiner kostenlosen Apple-ID direkt auf dem iPad. Nach dem ersten Einrichten am PC kannst du
Pad Commander am iPad installieren, aktualisieren und alle 7 Tage erneuern, ohne Kabel und ohne PC.

1. **Am iPad:** Einen Gerätecode muss es geben. Im App Store **„LocalDevVPN“** laden.
2. **Am Windows-PC:** **iTunes** von der Apple-Webseite installieren (wegen der Treiber). Dann **iloader** laden, und zwar nur von
   [iloader.app](https://iloader.app) oder [github.com/nab138/iloader](https://github.com/nab138/iloader).
3. iPad per Kabel anschließen, dem PC vertrauen. In iloader mit der Apple-ID anmelden und **SideStore** installieren.
   iloader legt dabei auch die nötige Kopplungsdatei aufs iPad.
4. **Am iPad:** *Einstellungen › Datenschutz & Sicherheit › Entwicklermodus* einschalten (Neustart). Dann
   *Einstellungen › Allgemein › VPN & Geräteverwaltung* › deiner Apple-ID vertrauen.
5. LocalDevVPN öffnen und verbinden, dann SideStore öffnen. Unter **Quellen › +** diese Adresse eintragen:

   ```
   https://github.com/Sxbyy/pad-commander/releases/download/latest/source.json
   ```

   Danach Pad Commander dort **installieren**. Alternativ `PadCommander.ipa` in Safari laden und in SideStore unter
   *Meine Apps › +* auswählen.
6. **Erneuern:** SideStore erneuert die Apps im Hintergrund, solange LocalDevVPN verbunden ist. Von Hand geht es mit
   *Meine Apps* und einem Tipp auf die Tage-Anzeige. Updates von Pad Commander erscheinen ebenfalls dort.

Mit kostenloser Apple-ID sind höchstens 3 selbst installierte Apps gleichzeitig aktiv, SideStore zählt mit. Nach einem
iPadOS-Update oder dem Zurücksetzen kann die Kopplungsdatei ungültig werden. Dann Schritt 3 einmal wiederholen.

### Weg 3: Sideloadly am PC (Notlösung)

1. `PadCommander.ipa` von der Release-Seite laden.
2. **Sideloadly** installieren (sideloadly.io). Es braucht iTunes und iCloud von der Apple-Webseite, nicht die
   Microsoft-Store-Versionen.
3. iPad per Kabel anschließen, IPA in Sideloadly ziehen, Apple-ID eintragen, **Start**.
4. Am iPad wie oben den Entwicklermodus einschalten und der Apple-ID vertrauen.
5. Nach **7 Tagen** in Sideloadly wieder **Start** drücken. Die Daten in der App bleiben erhalten.

### Warum es nicht noch direkter geht

Apple lässt Apps sonst nur über den App Store, TestFlight oder (in der EU) über Marktplätze wie AltStore PAL zu. All das
setzt ein **bezahltes Entwicklerkonto (99 $/Jahr)** und eine Prüfung durch Apple voraus. Sogenannte Signierdienste, die
Apps ohne PC mit fremden Firmenzertifikaten installieren, sind unsicher und werden regelmäßig gesperrt. Davon rate ich ab.
TrollStore ginge nur mit sehr alten iPadOS-Versionen, Pad Commander braucht aber iPadOS 17.

## Was er kann

- Zwei Dateifenster nebeneinander, Laufwerksleiste, Pfadzeile, Spalten Name / Erw. / Größe / Datum (antippen = sortieren)
- **F3** Ansehen (Bilder, PDF, Video, Musik, Office … mit Markieren/Zeichnen), **F4** Texteditor, **F5** Kopieren,
  **F6** Verschieben, **F7** Neuer Ordner, **F8** Löschen, **F9** Teilen, **F2** Umbenennen
- Kopieren und Verschieben mit Fortschritt und Abbrechen. Gibt es eine Datei schon, fragt die App nach: überschreiben, alle, überspringen oder umbenennen.
- **ZIP** packen und entpacken (eigene Umsetzung, auch mehrere Archive auf einmal)
- Markieren: Symbol antippen, Leertaste, Gruppe per Platzhalter (`*.jpg`), alles, umkehren, **Ordner vergleichen**
- Suchen nach Namen (Platzhalter) und Inhalt, Ordnergrößen, Eigenschaften, versteckte Dateien
- **Orte** aus der Dateien-App einbinden: iCloud Drive, USB-Stick, Netzlaufwerk (SMB), Ordner anderer Apps
- Ziehen und Ablegen zwischen den Fenstern und aus anderen Apps. „Öffnen in … Pad Commander“ legt die Datei in `iPad:\Eingang` ab (installierte App).
- **Schriftgröße** Klein / Normal / Groß (Einstellungen oder ⌘+ / ⌘-)
- Volle Tastatursteuerung. Siehe Hilfe (F1 bzw. ⌘1).

### Tastatur

| Taste | Ersatz ohne F-Tasten | Wirkung |
|---|---|---|
| F1 … F10 | **⌘1 … ⌘0** | Hilfe, Umbenennen, Ansehen, Bearbeiten, Kopieren, Verschieben, Neuer Ordner, Löschen, Teilen, Einstellungen |
| Alt+F5 / Alt+F7 / Alt+F9 | ⌘⌥5 / ⌘⌥7 / ⌘⌥9 | Packen / Suchen / Entpacken |
| Esc | **⌘.** | Dialog schließen, Markierung aufheben, Vorgang abbrechen |
| Tab, Pfeile, Enter, Leertaste, Rücktaste | | Fenster wechseln, Cursor, öffnen, markieren, eine Ebene hoch |
| Strg+U / Strg+E / Strg+R | | Fenster tauschen / gleicher Ordner / neu einlesen |

Apple-Tastaturen (Magic Keyboard) haben keine F-Tasten und kein Esc, dafür gibt es die ⌘-Tasten. Hält man ⌘ gedrückt,
zeigt das iPad alle Befehle an.

## Bauen

Ohne Mac: Jeder Push auf `main` baut über GitHub Actions (macOS-Rechner) die unsignierte IPA und das Swift-Playground-Paket.
Dazu kommt `source.json` für SideStore. Die App wird im iPad-Simulator durchgetestet, mit Bildschirmfotos auf dem Zweig
`ci-results`. Alles landet im Release `latest`. Das Xcode-Projekt entsteht mit
[XcodeGen](https://github.com/yonaskolb/XcodeGen) aus `project.yml`, das Playground-Paket mit `scripts/make_playground.py`.
