import Foundation
import UniformTypeIdentifiers

/// Ein Eintrag in einem Dateifenster.
struct FileItem: Identifiable, Hashable {
    let url: URL
    let name: String
    let isDirectory: Bool
    let isParent: Bool
    let size: Int64
    let modified: Date?
    let isHidden: Bool
    /// Datei liegt nur in iCloud und ist noch nicht geladen.
    let isCloudOnly: Bool

    var id: URL { url }

    var ext: String {
        if isDirectory || isParent { return "" }
        return (name as NSString).pathExtension
    }

    var baseName: String {
        if isDirectory || isParent || ext.isEmpty { return name }
        return (name as NSString).deletingPathExtension
    }

    var type: UTType? {
        if isDirectory { return .folder }
        return UTType(filenameExtension: ext.lowercased())
    }

    var isText: Bool {
        let e = ext.lowercased()
        if Self.textExtensions.contains(e) { return true }
        guard let t = type else { return e.isEmpty }
        return t.conforms(to: .text) || t.conforms(to: .sourceCode) || t.conforms(to: .json) || t.conforms(to: .xml)
    }

    var isZip: Bool { ext.lowercased() == "zip" }

    static let textExtensions: Set<String> = [
        "txt", "md", "log", "ini", "cfg", "conf", "csv", "tsv", "json", "xml", "html", "htm", "css", "js", "ts",
        "swift", "py", "sh", "bat", "ps1", "yml", "yaml", "toml", "c", "h", "cpp", "java", "kt", "rb", "php", "sql",
        "plist", "srt", "vtt", "tex", "rtf", "nfo", "gpx", "kml"
    ]

    static func parent(of dir: URL) -> FileItem {
        FileItem(url: dir.deletingLastPathComponent(), name: "..", isDirectory: true, isParent: true,
                 size: 0, modified: nil, isHidden: false, isCloudOnly: false)
    }

    /// SF-Symbol fuer den Eintrag.
    var symbol: String {
        if isParent { return "arrow.turn.left.up" }
        if isDirectory { return "folder.fill" }
        if isCloudOnly { return "icloud.and.arrow.down" }
        let e = ext.lowercased()
        if ["zip", "rar", "7z", "gz", "tar", "bz2", "xz"].contains(e) { return "archivebox.fill" }
        if e == "pdf" { return "doc.richtext.fill" }
        guard let t = type else { return "doc" }
        if t.conforms(to: .image) { return "photo" }
        if t.conforms(to: .movie) || t.conforms(to: .video) { return "film" }
        if t.conforms(to: .audio) { return "music.note" }
        if t.conforms(to: .spreadsheet) { return "tablecells" }
        if t.conforms(to: .presentation) { return "rectangle.on.rectangle" }
        if isText { return "doc.text" }
        if t.conforms(to: .executable) || e == "exe" || e == "apk" || e == "ipa" { return "gearshape" }
        return "doc"
    }
}

enum SortKey: String, CaseIterable, Codable {
    case name, ext, size, date

    var title: String {
        switch self {
        case .name: return "Name"
        case .ext: return "Erw."
        case .size: return "Größe"
        case .date: return "Datum"
        }
    }
}

enum Lister {
    static let keys: [URLResourceKey] = [
        .isDirectoryKey, .fileSizeKey, .contentModificationDateKey, .isHiddenKey, .isPackageKey
    ]

    /// Liest einen Ordner. Wirft, wenn der Ordner nicht lesbar ist.
    static func list(_ dir: URL, showHidden: Bool) throws -> [FileItem] {
        let fm = FileManager.default
        let names = try fm.contentsOfDirectory(atPath: dir.path)
        var out: [FileItem] = []
        out.reserveCapacity(names.count)
        for raw in names {
            var name = raw
            var cloudOnly = false
            if name.hasPrefix("."), name.hasSuffix(".icloud"), name.count > 8 {
                cloudOnly = true
                name = String(name.dropFirst().dropLast(7))
            }
            let stored = dir.appendingPathComponent(raw)
            let values = try? stored.resourceValues(forKeys: Set(keys))
            let hidden = !cloudOnly && (values?.isHidden ?? false || name.hasPrefix("."))
            if hidden && !showHidden { continue }
            let isPackage = values?.isPackage ?? false
            let isDir = (values?.isDirectory ?? false) && !isPackage
            let url = dir.appendingPathComponent(name, isDirectory: isDir)
            out.append(FileItem(url: url, name: name, isDirectory: isDir, isParent: false,
                                size: Int64(values?.fileSize ?? 0), modified: values?.contentModificationDate,
                                isHidden: hidden, isCloudOnly: cloudOnly))
        }
        return out
    }

    static func sort(_ items: [FileItem], by key: SortKey, ascending: Bool) -> [FileItem] {
        let dirs = items.filter { $0.isDirectory }
        let files = items.filter { !$0.isDirectory }
        func byName(_ a: FileItem, _ b: FileItem) -> Bool {
            a.name.localizedStandardCompare(b.name) == .orderedAscending
        }
        let sortedDirs: [FileItem]
        switch key {
        case .date:
            sortedDirs = dirs.sorted { a, b in
                let da = a.modified ?? .distantPast, db = b.modified ?? .distantPast
                if da == db { return byName(a, b) }
                return ascending ? da < db : da > db
            }
        default:
            sortedDirs = dirs.sorted { ascending || key != .name ? byName($0, $1) : byName($1, $0) }
        }
        let sortedFiles = files.sorted { a, b in
            switch key {
            case .name:
                return ascending ? byName(a, b) : byName(b, a)
            case .ext:
                let c = a.ext.localizedStandardCompare(b.ext)
                if c == .orderedSame { return byName(a, b) }
                return ascending ? c == .orderedAscending : c == .orderedDescending
            case .size:
                if a.size == b.size { return byName(a, b) }
                return ascending ? a.size < b.size : a.size > b.size
            case .date:
                let da = a.modified ?? .distantPast, db = b.modified ?? .distantPast
                if da == db { return byName(a, b) }
                return ascending ? da < db : da > db
            }
        }
        return sortedDirs + sortedFiles
    }

    /// Platzhalter-Muster wie *.pdf oder bild??.jpg; ohne Platzhalter gilt "enthaelt".
    static func matches(_ name: String, pattern: String) -> Bool {
        let p = pattern.trimmingCharacters(in: .whitespaces)
        if p.isEmpty || p == "*" || p == "*.*" { return true }
        let parts = p.split(separator: ";").map { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        for part in parts {
            if part.contains("*") || part.contains("?") {
                let pred = NSPredicate(format: "SELF LIKE[cd] %@", part)
                if pred.evaluate(with: name) { return true }
                // *.* soll auch Dateien ohne Endung treffen
                if part.hasSuffix(".*"), NSPredicate(format: "SELF LIKE[cd] %@", String(part.dropLast(2))).evaluate(with: name) {
                    return true
                }
            } else if name.range(of: part, options: [.caseInsensitive, .diacriticInsensitive]) != nil {
                return true
            }
        }
        return false
    }
}
