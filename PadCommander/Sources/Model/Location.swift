import Foundation

/// Ein "Laufwerk": der App-eigene Ordner auf dem iPad oder ein Ordner aus der Dateien-App
/// (iCloud Drive, USB-Stick, Netzlaufwerk, andere Apps), der per Lesezeichen gemerkt wird.
struct Location: Identifiable, Codable, Hashable {
    enum Kind: String, Codable {
        case documents
        case bookmark
    }

    var id: String
    var name: String
    var kind: Kind
    var bookmark: Data?
    var symbol: String?

    static let iPad = Location(id: "ipad", name: "iPad", kind: .documents, bookmark: nil, symbol: "ipad.landscape")

    var icon: String {
        if let s = symbol { return s }
        return kind == .documents ? "ipad.landscape" : "folder.badge.gearshape"
    }

    /// Kurzname fuer die Laufwerksleiste (wie "c:" bei Windows).
    var shortName: String {
        let n = name.count > 14 ? String(name.prefix(13)) + "…" : name
        return n
    }
}

/// Loest Lesezeichen auf und haelt den Sicherheitszugriff offen, solange die App laeuft.
final class LocationAccess {
    static let shared = LocationAccess()
    private var resolved: [String: URL] = [:]

    static var documents: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    /// Wurzelordner des Orts. Gibt ein aktualisiertes Lesezeichen zurueck, wenn das alte veraltet war.
    func root(_ loc: Location) -> (url: URL?, refreshed: Data?) {
        switch loc.kind {
        case .documents:
            return (Self.documents, nil)
        case .bookmark:
            if let u = resolved[loc.id] { return (u, nil) }
            guard let data = loc.bookmark else { return (nil, nil) }
            var stale = false
            guard let url = try? URL(resolvingBookmarkData: data, options: [], relativeTo: nil, bookmarkDataIsStale: &stale) else {
                return (nil, nil)
            }
            _ = url.startAccessingSecurityScopedResource()
            resolved[loc.id] = url
            var fresh: Data?
            if stale { fresh = try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil) }
            return (url, fresh)
        }
    }

    /// Merkt sich eine frisch ausgewaehlte, bereits freigeschaltete URL.
    func adopt(_ url: URL, for id: String) {
        resolved[id] = url
    }

    func release(_ loc: Location) {
        if let u = resolved.removeValue(forKey: loc.id) {
            u.stopAccessingSecurityScopedResource()
        }
    }
}
