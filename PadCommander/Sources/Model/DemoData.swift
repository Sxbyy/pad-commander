import UIKit

/// Beispieldateien: einmal eine Willkommensdatei, fuer UI-Tests ein ganzer Beispielbaum.
@MainActor
enum DemoData {
    static func ensureWelcome() {
        let d = UserDefaults.standard
        guard !d.bool(forKey: "welcomed") else { return }
        d.set(true, forKey: "welcomed")
        let url = LocationAccess.documents.appendingPathComponent("Willkommen.txt")
        guard !FileOps.exists(url) else { return }
        try? welcomeText.data(using: .utf8)?.write(to: url)
    }

    private static var homeLine: String {
        AppInfo.filesAppVisible
            ? "Dieser Ordner hier („iPad“) ist in der Dateien-App unter\n„Auf meinem iPad › Pad Commander“ zu finden."
            : "In Swift Playground ist dieser Ordner („iPad“) nicht in der Dateien-App\nsichtbar – hol dir deine Ordner einfach über „+“ dazu."
    }

    static let welcomeText = """
    Willkommen beim Pad Commander!

    Zwei Fenster, Funktionstasten unten, wie beim klassischen Commander:
      F3 Ansehen   F4 Bearbeiten   F5 Kopieren   F6 Verschieben
      F7 Neuer Ordner   F8 Löschen   F9 Teilen

    Antippen = Cursor setzen, zweimal antippen = öffnen,
    auf das Symbol tippen = markieren, lange drücken = Menü.

    Mit „+“ in der Laufwerksleiste holst du Ordner aus der Dateien-App
    dazu: iCloud Drive, USB-Sticks, Netzlaufwerke oder andere Apps.
    \(homeLine)

    Mit Tastatur: F1 … F10 oder ⌘1 … ⌘0 (für Tastaturen ohne F-Tasten).
    Alle Tasten und Gesten zeigt die Hilfe (F1 bzw. ⌘1).
    """

    private static var root: URL { LocationAccess.documents }

    private static func makeDir(_ path: String) {
        try? FileManager.default.createDirectory(at: root.appendingPathComponent(path, isDirectory: true), withIntermediateDirectories: true)
    }

    private static func setDate(_ u: URL, _ daysAgo: Double) {
        try? FileManager.default.setAttributes([.modificationDate: Date().addingTimeInterval(-daysAgo * 86_400)], ofItemAtPath: u.path)
    }

    private static func text(_ path: String, _ s: String, daysAgo: Double) {
        let u = root.appendingPathComponent(path)
        try? s.data(using: .utf8)?.write(to: u)
        setDate(u, daysAgo)
    }

    private static func image(_ path: String, colors: [UIColor], daysAgo: Double) {
        let size = CGSize(width: 800, height: 500)
        let img = UIGraphicsImageRenderer(size: size).image { ctx in
            let cg = ctx.cgContext
            let cols = colors.map { $0.cgColor } as CFArray
            if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: cols, locations: [0, 1]) {
                cg.drawLinearGradient(g, start: .zero, end: CGPoint(x: 0, y: size.height), options: [])
            }
            UIColor.white.withAlphaComponent(0.85).setFill()
            cg.fillEllipse(in: CGRect(x: 560, y: 80, width: 140, height: 140))
        }
        let u = root.appendingPathComponent(path)
        try? img.pngData()?.write(to: u)
        setDate(u, daysAgo)
    }

    private static func pdf(_ path: String, daysAgo: Double) {
        let u = root.appendingPathComponent(path)
        let r = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 595, height: 842))
        try? r.writePDF(to: u) { ctx in
            ctx.beginPage()
            let attrs: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 28)]
            ("Monatsbericht" as NSString).draw(at: CGPoint(x: 60, y: 80), withAttributes: attrs)
            let body: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 15)]
            ("Erstellt vom Pad Commander als Beispiel." as NSString).draw(at: CGPoint(x: 60, y: 130), withAttributes: body)
        }
        setDate(u, daysAgo)
    }

    static func reset() {
        let fm = FileManager.default
        for name in (try? fm.contentsOfDirectory(atPath: root.path)) ?? [] {
            try? fm.removeItem(at: root.appendingPathComponent(name))
        }
        makeDir("Bilder")
        makeDir("Dokumente")
        makeDir("Musik")
        makeDir("Projekte/Website")
        text("Willkommen.txt", welcomeText, daysAgo: 0.2)
        text("Dokumente/Notizen.txt", "Einkauf: Milch, Brot, Käse\nTermin: Dienstag 14 Uhr Werkstatt\n", daysAgo: 3)
        text("Dokumente/Einkaufsliste.md", "# Einkauf\n\n- Milch\n- Brot\n- Äpfel\n", daysAgo: 1)
        text("Dokumente/Tabelle.csv", "Monat;Stunden;Lohn\nOktober;42;546\nNovember;38;494\n", daysAgo: 9)
        text("Projekte/Website/index.html", "<!doctype html><title>Test</title><h1>Hallo</h1>\n", daysAgo: 30)
        text("Projekte/Liesmich.txt", "Projektordner\n", daysAgo: 12)
        image("Bilder/Sonnenuntergang.png", colors: [UIColor.systemOrange, UIColor.systemPurple], daysAgo: 5)
        image("Bilder/Berge.png", colors: [UIColor.systemTeal, UIColor.systemIndigo], daysAgo: 40)
        image("Bilder/Wiese.png", colors: [UIColor.systemGreen, UIColor.systemYellow], daysAgo: 2)
        pdf("Dokumente/Bericht.pdf", daysAgo: 6)
        for p in ["Bilder", "Dokumente", "Musik", "Projekte"] { setDate(root.appendingPathComponent(p), 2) }
    }
}
