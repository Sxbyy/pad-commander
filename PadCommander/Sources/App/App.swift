import UIKit
import SwiftUI

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        true
    }

    func application(_ application: UIApplication,
                     configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let config = UISceneConfiguration(name: "Default", sessionRole: connectingSceneSession.role)
        config.delegateClass = SceneDelegate.self
        return config
    }
}

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let ws = scene as? UIWindowScene else { return }
        let w = UIWindow(windowScene: ws)
        w.rootViewController = RootViewController()
        w.makeKeyAndVisible()
        window = w
        for ctx in connectionOptions.urlContexts { AppModel.shared.receive(url: ctx.url) }
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        for ctx in URLContexts { AppModel.shared.receive(url: ctx.url) }
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        AppModel.shared.reloadBoth()
    }
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

    private func claimKeyboard() {
        guard presentedViewController == nil, !model.blocksKeys, !isFirstResponder else { return }
        becomeFirstResponder()
    }

    override var keyCommands: [UIKeyCommand]? {
        if presentedViewController != nil || model.blocksKeys { return nil }
        return KeyMap.commands
    }

    @objc func keyPressed(_ sender: UIKeyCommand) {
        model.handleKey(sender.input ?? "", sender.modifierFlags)
    }
}

@MainActor
enum KeyMap {
    static let commands: [UIKeyCommand] = build()

    private static func build() -> [UIKeyCommand] {
        let sel = #selector(RootViewController.keyPressed(_:))
        var list: [UIKeyCommand] = []
        func add(_ input: String, _ flags: UIKeyModifierFlags, _ title: String) {
            let c = UIKeyCommand(title: title, action: sel, input: input, modifierFlags: flags)
            c.wantsPriorityOverSystemBehavior = true
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
        add(UIKeyCommand.inputEscape, [], "Markierung aufheben")
        add(UIKeyCommand.inputDelete, [], "Löschen")
        add("\r", [], "Öffnen")
        add("\r", [.alternate], "Eigenschaften")
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
