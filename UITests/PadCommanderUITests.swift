import XCTest

/// Rundgang durch die App mit Bildschirmfotos (laeuft im iPad-Simulator auf GitHub).
final class PadCommanderUITests: XCTestCase {
    var app: XCUIApplication!

    var shotDir: URL {
        URL(fileURLWithPath: ProcessInfo.processInfo.environment["SHOTS_DIR"] ?? NSTemporaryDirectory())
    }

    override func setUp() {
        continueAfterFailure = true
        app = XCUIApplication()
        app.launchArguments = ["-uitest"]
        XCUIDevice.shared.orientation = .landscapeLeft
        app.launch()
    }

    func shot(_ name: String) {
        sleep(1)
        let s = XCUIScreen.main.screenshot()
        try? FileManager.default.createDirectory(at: shotDir, withIntermediateDirectories: true)
        try? s.pngRepresentation.write(to: shotDir.appendingPathComponent(name + ".png"))
        let a = XCTAttachment(screenshot: s)
        a.name = name
        a.lifetime = .keepAlways
        add(a)
    }

    func el(_ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    @discardableResult
    func wait(_ id: String, _ timeout: TimeInterval = 8) -> XCUIElement {
        let e = el(id)
        XCTAssertTrue(e.waitForExistence(timeout: timeout), "fehlt: \(id)")
        return e
    }

    func tapIcon(_ id: String) {
        let e = wait(id)
        e.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0.5)).withOffset(CGVector(dx: 16, dy: 0)).tap()
    }

    func testRundgang() {
        wait("row-L-Bilder", 20)
        shot("01-start")

        // Ordner oeffnen und Dateien markieren
        wait("row-L-Bilder").doubleTap()
        wait("row-L-Berge.png")
        shot("02-bilder")
        tapIcon("row-L-Berge.png")
        tapIcon("row-L-Wiese.png")
        shot("03-markiert")

        // F5 Kopieren ins rechte Fenster
        wait("fkey-F5").tap()
        wait("dialog-ok")
        shot("04-kopieren-dialog")
        el("dialog-ok").tap()
        wait("row-R-Berge.png", 15)
        wait("row-R-Wiese.png")
        shot("05-kopiert")

        // F7 Neuer Ordner
        wait("row-R-Bericht.pdf").tap()
        wait("fkey-F7").tap()
        let field = app.textFields["dialog-field"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.typeText("Testordner")
        el("dialog-ok").tap()
        wait("row-R-Testordner")
        shot("06-neuer-ordner")

        // F4 Editor
        wait("row-R-Notizen.txt").tap()
        wait("fkey-F4").tap()
        wait("editor-close", 8)
        shot("07-editor")
        el("editor-close").tap()
        sleep(1)

        // F3 Vorschau
        wait("row-R-Bericht.pdf").tap()
        wait("fkey-F3").tap()
        sleep(5)
        shot("08-vorschau")
        let done = app.buttons["Done"]
        if done.waitForExistence(timeout: 3) { done.tap() } else { app.swipeDown() }
        sleep(2)
        shot("08b-zurueck")

        // F8 Loeschen
        wait("row-R-Testordner").tap()
        wait("fkey-F8").tap()
        wait("dialog-ok")
        shot("09-loeschen")
        el("dialog-ok").tap()
        sleep(2)
        XCTAssertFalse(el("row-R-Testordner").exists, "Ordner wurde nicht geloescht")

        // Packen und Entpacken
        wait("row-L-Sonnenuntergang.png").tap()
        wait("tool-markall").tap()
        wait("tool-pack").tap()
        wait("dialog-ok")
        shot("10-packen")
        el("dialog-ok").tap()
        wait("row-R-Bilder.zip", 15)
        wait("row-R-Bilder.zip").doubleTap()
        wait("dialog-ok")
        el("dialog-ok").tap()
        wait("row-R-Bilder", 15)
        shot("11-entpackt")
        wait("row-R-Bilder").doubleTap()
        wait("row-R-Berge.png", 8)
        shot("12-entpackt-inhalt")

        // Designs und Hochformat
        wait("tool-theme").tap()
        shot("13-nacht")
        XCUIDevice.shared.orientation = .portrait
        sleep(1)
        shot("14-hochkant-nacht")
        wait("tool-theme").tap()
        shot("15-hochkant-klassisch")
        XCUIDevice.shared.orientation = .landscapeLeft
        sleep(1)

        // Suche
        wait("tool-search").tap()
        wait("search-start").tap()
        sleep(2)
        shot("16-suche")
    }
}
