import Foundation

/// Version und Art der Installation (installierte App oder Swift Playground).
enum AppInfo {
    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.1"
    }

    static var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
    }

    static var versionText: String {
        build.isEmpty || build == version ? version : "\(version) (Build \(build))"
    }

    /// Nur die installierte App zeigt ihren Ordner in der Dateien-App, in Swift Playground fehlt der Eintrag.
    static var filesAppVisible: Bool {
        Bundle.main.object(forInfoDictionaryKey: "UIFileSharingEnabled") as? Bool ?? false
    }

    static var runsAs: String {
        filesAppVisible ? "Installierte App" : "App in Swift Playground"
    }

    static var homeHint: String {
        filesAppVisible
            ? "In der Dateien-App unter Auf meinem iPad › Pad Commander"
            : "Eigener Ordner der App (in Swift Playground nicht in der Dateien-App sichtbar, Ordner über „+“ einbinden)"
    }

    static var aboutText: String {
        """
        Pad Commander \(versionText)
        Läuft als: \(runsAs)

        Eigenständiger Dateimanager mit zwei Fenstern im Stil der klassischen Commander-Programme. \
        Er ist nicht mit anderen Herstellern verbunden.

        Neue Versionen und Anleitung: github.com/Sxbyy/pad-commander
        """
    }
}
