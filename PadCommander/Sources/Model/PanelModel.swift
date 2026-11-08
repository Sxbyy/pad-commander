import Foundation
import Observation

enum Side: String, Codable {
    case left, right
    var other: Side { self == .left ? .right : .left }
    var tag: String { self == .left ? "L" : "R" }
}

/// Zustand eines der beiden Dateifenster.
@Observable
final class PanelModel {
    let side: Side
    var location: Location
    var components: [String] = []
    var items: [FileItem] = []
    var cursor: URL?
    var marked: Set<URL> = []
    var sortKey: SortKey = .name
    var ascending = true
    var loadError: String?
    var dirSizes: [URL: Int64] = [:]
    /// Wird erhoeht, wenn die Liste zum Cursor scrollen soll.
    var scrollToken = 0
    var root: URL?
    var showHidden = false

    @ObservationIgnored private var watcher: DispatchSourceFileSystemObject?
    @ObservationIgnored private var watchedFD: Int32 = -1
    @ObservationIgnored var onBookmarkRefresh: ((Location, Data) -> Void)?
    @ObservationIgnored var onChange: (() -> Void)?

    init(side: Side, location: Location) {
        self.side = side
        self.location = location
    }

    // MARK: Pfade

    var dir: URL? {
        guard let root else { return nil }
        return components.reduce(root) { $0.appendingPathComponent($1, isDirectory: true) }
    }

    var isAtRoot: Bool { components.isEmpty }

    /// Pfadzeile im Stil "iPad:\Bilder\*.*"
    func pathLine(classic: Bool) -> String {
        if classic {
            let bs = "\\"
            let rel = components.isEmpty ? "" : components.joined(separator: bs) + bs
            return location.name + ":" + bs + rel + "*.*"
        }
        return ([location.name] + components).joined(separator: "  ›  ")
    }

    /// Relative Pfadangabe innerhalb des Orts (fuer Dialoge).
    var relativePath: String {
        components.isEmpty ? "/" : "/" + components.joined(separator: "/") + "/"
    }

    // MARK: Laden

    func resolveRoot() {
        let r = LocationAccess.shared.root(location)
        root = r.url
        if let fresh = r.refreshed {
            location.bookmark = fresh
            onBookmarkRefresh?(location, fresh)
        }
    }

    func reload(select name: String? = nil) {
        if root == nil { resolveRoot() }
        guard let dir else {
            items = []
            loadError = "Ort „\(location.name)“ ist nicht erreichbar. Ist der Datenträger verbunden?"
            return
        }
        let previous = name.map { dir.appendingPathComponent($0) } ?? cursor
        var list: [FileItem]
        do {
            list = try Lister.list(dir, showHidden: showHidden)
            loadError = nil
        } catch {
            list = []
            loadError = (error as NSError).localizedDescription
        }
        list = Lister.sort(list, by: sortKey, ascending: ascending)
        if !isAtRoot { list.insert(FileItem.parent(of: dir), at: 0) }
        items = list
        let existing = Set(list.map { $0.url })
        marked = marked.filter { existing.contains($0) }
        if let p = previous, let hit = list.first(where: { $0.url.lastPathComponent == p.lastPathComponent && $0.url.deletingLastPathComponent().path == p.deletingLastPathComponent().path }) {
            cursor = hit.url
        } else if let c = cursor, existing.contains(c) {
            // bleibt
        } else {
            cursor = list.first?.url
        }
        watch(dir)
        onChange?()
    }

    func resort() {
        let parent = items.first(where: { $0.isParent })
        var list = Lister.sort(items.filter { !$0.isParent }, by: sortKey, ascending: ascending)
        if let parent { list.insert(parent, at: 0) }
        items = list
    }

    func setSort(_ key: SortKey) {
        if sortKey == key { ascending.toggle() } else { sortKey = key; ascending = true }
        resort()
    }

    // MARK: Navigation

    func setLocation(_ loc: Location, components comps: [String] = []) {
        if loc.id != location.id { root = nil }
        location = loc
        components = comps
        marked = []
        dirSizes = [:]
        cursor = nil
        reload()
        if loadError != nil && !comps.isEmpty {
            components = []
            reload()
        }
        requestScroll()
    }

    func enter(_ item: FileItem) {
        if item.isParent { goUp(); return }
        guard item.isDirectory else { return }
        components.append(item.name)
        marked = []
        cursor = nil
        reload()
        cursor = items.first?.url
        requestScroll()
    }

    func goUp() {
        guard let last = components.popLast() else { return }
        marked = []
        cursor = nil
        reload(select: last)
        requestScroll()
    }

    func goRoot() {
        guard !components.isEmpty else { return }
        components = []
        marked = []
        cursor = nil
        reload()
        requestScroll()
    }

    /// Springt zu einer Datei (z. B. aus der Suche), wenn sie im selben Ort liegt.
    func reveal(_ url: URL) -> Bool {
        guard let root else { return false }
        let rootComps = root.resolvingSymlinksInPath().standardizedFileURL.pathComponents
        var comps = url.deletingLastPathComponent().resolvingSymlinksInPath().standardizedFileURL.pathComponents
        guard comps.count >= rootComps.count, Array(comps.prefix(rootComps.count)) == rootComps else { return false }
        comps.removeFirst(rootComps.count)
        components = comps
        marked = []
        reload(select: url.lastPathComponent)
        requestScroll()
        return true
    }

    func requestScroll() { scrollToken &+= 1 }

    // MARK: Cursor

    var cursorIndex: Int? {
        guard let c = cursor else { return nil }
        return items.firstIndex(where: { $0.url == c })
    }

    var cursorItem: FileItem? {
        guard let i = cursorIndex else { return nil }
        return items[i]
    }

    func moveCursor(by delta: Int) {
        guard !items.isEmpty else { return }
        let i = cursorIndex ?? 0
        let n = min(max(i + delta, 0), items.count - 1)
        cursor = items[n].url
        requestScroll()
    }

    func cursorToStart() { if let f = items.first { cursor = f.url; requestScroll() } }
    func cursorToEnd() { if let l = items.last { cursor = l.url; requestScroll() } }

    // MARK: Markieren

    func toggleMark(_ item: FileItem) {
        guard !item.isParent else { return }
        if marked.contains(item.url) { marked.remove(item.url) } else { marked.insert(item.url) }
    }

    func markAll() { marked = Set(items.filter { !$0.isParent }.map { $0.url }) }
    func unmarkAll() { marked = [] }
    func invertMarks() {
        let all = Set(items.filter { !$0.isParent }.map { $0.url })
        marked = all.subtracting(marked)
    }

    func mark(pattern: String, select: Bool, includeDirs: Bool = false) {
        for item in items where !item.isParent && (includeDirs || !item.isDirectory) {
            if Lister.matches(item.name, pattern: pattern) {
                if select { marked.insert(item.url) } else { marked.remove(item.url) }
            }
        }
    }

    /// Markierte Eintraege, sonst der Eintrag unter dem Cursor (wie im Commander).
    var selection: [FileItem] {
        let m = items.filter { marked.contains($0.url) }
        if !m.isEmpty { return m }
        if let c = cursorItem, !c.isParent { return [c] }
        return []
    }

    // MARK: Statuszeile

    var statusLine: String {
        let files = items.filter { !$0.isDirectory && !$0.isParent }
        let dirs = items.filter { $0.isDirectory && !$0.isParent }
        let markedFiles = files.filter { marked.contains($0.url) }
        let markedDirs = dirs.filter { marked.contains($0.url) }
        let total = files.reduce(Int64(0)) { $0 + $1.size }
        let sel = markedFiles.reduce(Int64(0)) { $0 + $1.size } + markedDirs.reduce(Int64(0)) { $0 + (dirSizes[$1.url] ?? 0) }
        return "\(Format.kilo(sel)) / \(Format.kilo(total)) in \(markedFiles.count) / \(files.count) Datei(en), \(markedDirs.count) / \(dirs.count) Ordner"
    }

    // MARK: Ueberwachen

    private func watch(_ dir: URL) {
        stopWatching()
        let fd = open(dir.path, O_EVTONLY)
        guard fd >= 0 else { return }
        watchedFD = fd
        let src = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: [.write, .delete, .rename], queue: .main)
        src.setEventHandler { [weak self] in
            guard let self else { return }
            // kurz warten, bis Schreibvorgaenge fertig sind
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in self?.reload() }
        }
        src.setCancelHandler { close(fd) }
        watcher = src
        src.resume()
    }

    private func stopWatching() {
        watcher?.cancel()
        watcher = nil
        watchedFD = -1
    }
}
