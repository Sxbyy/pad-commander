import UIKit
import SwiftUI

/// Einstieg der App. Dieselben Quellen laufen als installierte App (IPA) und als App in „Swift Playground“ auf dem iPad.
@main
struct PadCommanderApp: App {
    @Environment(\.scenePhase) private var phase

    var body: some Scene {
        WindowGroup {
            RootScene()
                .onOpenURL { url in AppModel.shared.receive(url: url) }
                .onChange(of: phase) { _, now in
                    if now == .active { AppModel.shared.reloadBoth() }
                }
        }
    }
}

/// Fenster-Inhalt: der RootViewController (Tastatur, UIKit-Fenster) mit der SwiftUI-Oberflaeche darin.
struct RootScene: View {
    let model = AppModel.shared

    var body: some View {
        RootControllerView()
            .ignoresSafeArea()
            .preferredColorScheme(model.themeKind == .classic ? .light : .dark)
    }
}

struct RootControllerView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> RootViewController { RootViewController() }
    func updateUIViewController(_ controller: RootViewController, context: Context) {}
}

/// Haelt die SwiftUI-Oberflaeche und nimmt die Tastaturbefehle entgegen.
final class RootViewController: UIViewController {
    private let model = AppModel.shared
    private var timer: Timer?

    override func viewDidLoad() {
        super.viewDidLoad()
        let host = UIHostingController(rootView: RootView(model: model))
        addChild(host)
        host.view.frame = view.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(host.view)
        host.didMove(toParent: self)
        Bridges.root = self
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.claimKeyboard() }
        }
    }

    override var canBecomeFirstResponder: Bool { true }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        becomeFirstResponder()
    }

    /// Holt sich die Tastatur zurueck, sobald kein Textfeld und kein anderes Fenster sie braucht.
    private func claimKeyboard() {
        guard presentedViewController == nil, !model.blocksKeys, !isFirstResponder else { return }
        becomeFirstResponder()
    }

    override var keyCommands: [UIKeyCommand]? {
        if presentedViewController != nil || model.sheet != nil { return nil }
        if model.dialog != nil { return KeyMap.dialogCommands }
        return KeyMap.commands
    }

    @objc func keyPressed(_ sender: UIKeyCommand) {
        model.handleKey(sender.input ?? "", sender.modifierFlags)
    }

    /// Esc und Enter kommen nicht zuverlaessig als Tastaturbefehl an, daher direkt ueber den Tastencode.
    /// Bei offenem Dialog (ohne Textfeld) schliessen bzw. bestaetigen sie ihn.
    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        guard presentedViewController == nil, model.sheet == nil else {
            super.pressesBegan(presses, with: event)
            return
        }
        var handled = false
        for press in presses {
            guard let key = press.key else { continue }
            switch key.keyCode {
            case .keyboardEscape:
                model.handleKey(UIKeyCommand.inputEscape, key.modifierFlags)
                handled = true
            case .keyboardReturnOrEnter, .keypadEnter:
                model.handleKey("\r", key.modifierFlags)
                handled = true
            default:
                break
            }
        }
        if !handled { super.pressesBegan(presses, with: event) }
    }
}

@MainActor
enum KeyMap {
    static let commands: [UIKeyCommand] = build()

    /// Waehrend ein Dialog offen ist: nur Cmd+. (wie Esc).
    static let dialogCommands: [UIKeyCommand] = {
        let c = UIKeyCommand(title: "Abbrechen", action: #selector(RootViewController.keyPressed(_:)), input: ".", modifierFlags: [.command])
        c.wantsPriorityOverSystemBehavior = true
        return [c]
    }()

    private static func build() -> [UIKeyCommand] {
        let sel = #selector(RootViewController.keyPressed(_:))
        var list: [UIKeyCommand] = []
        func add(_ input: String, _ flags: UIKeyModifierFlags, _ title: String, hidden: Bool = false) {
            let c = UIKeyCommand(title: title, action: sel, input: input, modifierFlags: flags)
            c.wantsPriorityOverSystemBehavior = true
            if hidden { c.attributes = .hidden }
            list.append(c)
        }
        add(UIKeyCommand.inputUpArrow, [], "Cursor hoch")
        add(UIKeyCommand.inputDownArrow, [], "Cursor runter")
        add(UIKeyCommand.inputLeftArrow, [], "Ordner hoch")
        add(UIKeyCommand.inputRightArrow, [], "Ordner öffnen")
        add(UIKeyCommand.inputPageUp, [], "Seite hoch")
        add(UIKeyCommand.inputPageDown, [], "Seite runter")
        add(UIKeyCommand.inputHome, [], "Anfang")
        add(UIKeyCommand.inputEnd, [], "Ende")

        add(UIKeyCommand.inputDelete, [], "Löschen")

        add("\t", [], "Fenster wechseln")
        add(" ", [], "Markieren")
        add("\u{8}", [], "Ordner hoch")
        add(UIKeyCommand.f1, [], "Hilfe")
        add(UIKeyCommand.f1, [.alternate], "Ort links wechseln")
        add(UIKeyCommand.f2, [], "Umbenennen")
        add(UIKeyCommand.f2, [.alternate], "Ort rechts wechseln")
        add(UIKeyCommand.f3, [], "Ansehen")
        add(UIKeyCommand.f4, [], "Bearbeiten")
        add(UIKeyCommand.f4, [.shift], "Neue Textdatei")
        add(UIKeyCommand.f5, [], "Kopieren")
        add(UIKeyCommand.f5, [.alternate], "Packen")
        add(UIKeyCommand.f6, [], "Verschieben")
        add(UIKeyCommand.f6, [.shift], "Umbenennen")
        add(UIKeyCommand.f7, [], "Neuer Ordner")
        add(UIKeyCommand.f7, [.alternate], "Suchen")
        add(UIKeyCommand.f8, [], "Löschen")
        add(UIKeyCommand.f9, [], "Teilen")
        add(UIKeyCommand.f9, [.alternate], "Entpacken")
        add(UIKeyCommand.f10, [], "Einstellungen")

        // Ersatz fuer Tastaturen ohne F-Tasten (z. B. Apple Magic Keyboard): Cmd+1 ... Cmd+0 = F1 ... F10
        let titles = ["Hilfe", "Umbenennen", "Ansehen", "Bearbeiten", "Kopieren", "Verschieben",
                      "Neuer Ordner", "Löschen", "Teilen", "Einstellungen"]
        for (i, d) in AppModel.digits.enumerated() {
            add(d, [.command], "\(titles[i]) (F\(i + 1))")
        }
        add("1", [.command, .alternate], "Ort links wechseln")
        add("2", [.command, .alternate], "Ort rechts wechseln")
        add("5", [.command, .alternate], "Packen")
        add("7", [.command, .alternate], "Suchen")
        add("9", [.command, .alternate], "Entpacken")
        add(".", [.command], "Abbrechen / Markierung aufheben")
        add("+", [.command], "Schrift größer")
        add("+", [.command, .shift], "Schrift größer", hidden: true)
        add("=", [.command], "Schrift größer", hidden: true)
        add("-", [.command], "Schrift kleiner")

        add("u", [.control], "Fenster tauschen")
        add("r", [.control], "Neu einlesen")
        add("h", [.control], "Versteckte Dateien")
        add("a", [.control], "Alles markieren")
        add("t", [.control], "Design wechseln")
        add("e", [.control], "Gleicher Ordner im anderen Fenster")
        add("+", [.control], "Gruppe markieren")
        add("-", [.control], "Gruppe demarkieren")
        return list
    }
}
