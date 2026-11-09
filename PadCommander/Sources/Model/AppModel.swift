import Foundation
import Observation

// MARK: Dialoge (eigene Fenster im Commander-Stil, keine System-Sheets)

struct InputDialog {
    var title: String
    var prompt: String
    var text: String
    var okTitle: String = "OK"
    var selectBaseName = false
    var action: (String) -> Void
}

struct ConfirmDialog {
    var title: String
    var message: String
    var okTitle: String = "OK"
    var destructive = false
    var action: () -> Void
}

struct TransferDialog {
    var op: TransferJob.Op
    var sources: [URL]
    var targetSide: Side
    var targetText: String
    var policy: ConflictPolicy = .ask
}

struct ConflictDialog {
    var name: String
    var resolve: (ConflictChoice) -> Void
}

struct PropertiesInfo {
    var item: FileItem
    var location: String
    var path: String
    var size: Int64?
    var itemCount: Int?
    var created: Date?
}

enum Dialog {
    case input(InputDialog)
    case confirm(ConfirmDialog)
    case transfer(TransferDialog)
    case conflict(ConflictDialog)
    case message(title: String, text: String)
    case properties(PropertiesInfo)
}

struct EditorDoc: Identifiable {
    let id = UUID()
    let url: URL
    var text: String
    let encoding: String.Encoding
    let modified: Date?
    let isNew: Bool
}

enum SheetKind: Identifiable {
    case editor(EditorDoc)
    case search
    case settings
    case help

    var id: String {
        switch self {
        case .editor(let d): return "editor-" + d.id.uuidString
        case .search: return "search"
        case .settings: return "settings"
        case .help: return "help"
        }
    }
}

struct BusyState {
    var progress: OpProgress
    var cancel: (() -> Void)?
}

enum ThemeKind: String, CaseIterable, Codable, Identifiable {
    case classic, nacht
    var id: String { rawValue }
    var title: String { self == .classic ? "Klassisch" : "Nacht" }
}

/// Schriftgroesse der Oberflaeche (Einstellungen, Cmd+Plus / Cmd+Minus).
enum TextSize: String, CaseIterable, Codable, Identifiable {
    case klein, normal, gross
    var id: String { rawValue }
    var title: String {
        switch self {
        case .klein: return "Klein"
        case .normal: return "Normal"
        case .gross: return "Groß"
        }
    }
    var factor: CGFloat {
        switch self {
        case .klein: return 0.88
        case .normal: return 1
        case .gross: return 1.2
        }
    }
}

private struct PanelState: Codable {
    var locationID: String
    var components: [String]
    var sortKey: SortKey
    var ascending: Bool
}

// MARK: App-Zustand

@MainActor
@Observable
final class AppModel {
    static let shared = AppModel()

    let left: PanelModel
    let right: PanelModel
    var activeSide: Side = .left
    var locations: [Location] = [.iPad]
    var themeKind: ThemeKind = .classic
    var showHidden = false
    var confirmDelete = true
    var textSize: TextSize = .normal
    /// Offener eigener Dialog. Beim Schliessen wird die Zeit gemerkt, damit dieselbe Enter-/Esc-Taste
    /// nicht gleich noch im Hauptfenster wirkt.
    var dialog: Dialog? {
        get { currentDialog }
        set {
            if newValue == nil && currentDialog != nil { dialogClosedAt = Date() }
            currentDialog = newValue
        }
    }
    private(set) var currentDialog: Dialog?
    var sheet: SheetKind?
    var busy: BusyState?
    /// Kurze Meldung unten in der Statusleiste.
    var toast: String?
    /// Nur im UI-Test: empfangene Tasten.
    var lastKey = ""

    @ObservationIgnored var lastTapURL: URL?
    @ObservationIgnored var lastTapTime = Date.distantPast
    @ObservationIgnored var dragSources: [URL] = []
    @ObservationIgnored var dragSide: Side = .left
    @ObservationIgnored var dragTime = Date.distantPast
    @ObservationIgnored var dragNames: Set<String> = []
    @ObservationIgnored var dialogClosedAt = Date.distantPast
    @ObservationIgnored private let defaults = UserDefaults.standard
    @ObservationIgnored private var toastTask: Task<Void, Never>?
    let isUITest = CommandLine.arguments.contains("-uitest")
    /// Nur im Test: Tasten nur protokollieren, nichts ausfuehren.
    let keyLogOnly = CommandLine.arguments.contains("-keylog")

    init() {
        left = PanelModel(side: .left, location: .iPad)
        right = PanelModel(side: .right, location: .iPad)
        if isUITest {
            DemoData.reset()
            for k in ["locations", "panel.left", "panel.right", "theme", "textSize", "showHidden", "activeSide"] { defaults.removeObject(forKey: k) }
        }
        DemoData.ensureWelcome()
        loadSettings()
        for p in [left, right] {
            p.showHidden = showHidden
            p.onBookmarkRefresh = { [weak self] loc, data in
                Task { @MainActor in self?.updateBookmark(loc.id, data) }
            }
            p.onChange = { [weak self] in
                Task { @MainActor in self?.savePanels() }
            }
        }
        restorePanel(left, key: "panel.left", fallback: [])
        restorePanel(right, key: "panel.right", fallback: isUITest ? ["Dokumente"] : [])
    }

    var theme: Theme { Theme.make(themeKind, scale: textSize.factor) }
    var active: PanelModel { activeSide == .left ? left : right }
    var inactive: PanelModel { activeSide == .left ? right : left }
    func panel(_ side: Side) -> PanelModel { side == .left ? left : right }

    /// Tastaturbefehle sperren, solange ein Dialog offen ist (sonst landen Eingaben nicht im Textfeld).
    var blocksKeys: Bool { dialog != nil || sheet != nil }

    // MARK: Einstellungen

    private func loadSettings() {
        if let raw = defaults.string(forKey: "theme"), let t = ThemeKind(rawValue: raw) { themeKind = t }
        if let raw = defaults.string(forKey: "textSize"), let s = TextSize(rawValue: raw) { textSize = s }
        showHidden = defaults.bool(forKey: "showHidden")
        if defaults.object(forKey: "confirmDelete") != nil { confirmDelete = defaults.bool(forKey: "confirmDelete") }
        if let raw = defaults.string(forKey: "activeSide"), let s = Side(rawValue: raw) { activeSide = s }
        if let data = defaults.data(forKey: "locations"), let list = try? JSONDecoder().decode([Location].self, from: data) {
            locations = [.iPad] + list.filter { $0.kind == .bookmark }
        }
    }

    private func saveLocations() {
        let list = locations.filter { $0.kind == .bookmark }
        if let data = try? JSONEncoder().encode(list) { defaults.set(data, forKey: "locations") }
    }

    func savePanels() {
        for (p, key) in [(left, "panel.left"), (right, "panel.right")] {
            let st = PanelState(locationID: p.location.id, components: p.components, sortKey: p.sortKey, ascending: p.ascending)
            if let data = try? JSONEncoder().encode(st) { defaults.set(data, forKey: key) }
        }
        defaults.set(activeSide.rawValue, forKey: "activeSide")
    }

    private func restorePanel(_ p: PanelModel, key: String, fallback: [String]) {
        var loc = Location.iPad
        var comps = fallback
        if let data = defaults.data(forKey: key), let st = try? JSONDecoder().decode(PanelState.self, from: data) {
            if let l = locations.first(where: { $0.id == st.locationID }) { loc = l; comps = st.components }
            p.sortKey = st.sortKey
            p.ascending = st.ascending
        }
        p.setLocation(loc, components: comps)
    }

    func setTheme(_ t: ThemeKind) {
        themeKind = t
        defaults.set(t.rawValue, forKey: "theme")
    }

    func cycleTheme() {
        let all = ThemeKind.allCases
        let i = all.firstIndex(of: themeKind) ?? 0
        setTheme(all[(i + 1) % all.count])
    }

    func setTextSize(_ s: TextSize) {
        textSize = s
        defaults.set(s.rawValue, forKey: "textSize")
    }

    /// Schrift groesser (+1) oder kleiner (-1).
    func stepTextSize(_ delta: Int) {
        let all = TextSize.allCases
        let i = all.firstIndex(of: textSize) ?? 1
        let n = min(max(i + delta, 0), all.count - 1)
        setTextSize(all[n])
        flash("Schriftgröße: " + all[n].title)
    }

    func setShowHidden(_ v: Bool) {
        showHidden = v
        defaults.set(v, forKey: "showHidden")
        for p in [left, right] { p.showHidden = v; p.reload() }
    }

    func setConfirmDelete(_ v: Bool) {
        confirmDelete = v
        defaults.set(v, forKey: "confirmDelete")
    }

    func activate(_ side: Side) {
        guard activeSide != side else { return }
        activeSide = side
        defaults.set(side.rawValue, forKey: "activeSide")
    }

    // MARK: Orte

    func addLocation(url: URL) {
        let access = url.startAccessingSecurityScopedResource()
        guard let data = try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil) else {
            if access { url.stopAccessingSecurityScopedResource() }
            showMessage("Ort hinzufügen", "Für „\(url.lastPathComponent)“ konnte kein dauerhafter Zugriff gespeichert werden.")
            return
        }
        if let existing = locations.first(where: { $0.kind == .bookmark && LocationAccess.shared.root($0).url?.standardizedFileURL == url.standardizedFileURL }) {
            if access { url.stopAccessingSecurityScopedResource() }
            active.setLocation(existing)
            return
        }
        var name = url.lastPathComponent
        if name.isEmpty { name = "Ordner" }
        let symbol = Self.symbol(for: url)
        let loc = Location(id: UUID().uuidString, name: name, kind: .bookmark, bookmark: data, symbol: symbol)
        LocationAccess.shared.adopt(url, for: loc.id)
        locations.append(loc)
        saveLocations()
        active.setLocation(loc)
        flash("Ort „\(name)“ hinzugefügt")
    }

    private static func symbol(for url: URL) -> String {
        let p = url.path.lowercased()
        if p.contains("mobile documents") || p.contains("icloud") { return "icloud" }
        if p.hasPrefix("/private/var/mobile/library/livefiles") || p.contains("/volumes/") { return "externaldrive" }
        if p.contains("smb") || p.contains("fileprovider") { return "server.rack" }
        return "folder.badge.gearshape"
    }

    func removeLocation(_ loc: Location) {
        guard loc.kind == .bookmark else { return }
        LocationAccess.shared.release(loc)
        locations.removeAll { $0.id == loc.id }
        saveLocations()
        for p in [left, right] where p.location.id == loc.id { p.setLocation(.iPad) }
    }

    func renameLocation(_ loc: Location, to name: String) {
        guard let i = locations.firstIndex(where: { $0.id == loc.id }), let n = FileOps.validName(name) else { return }
        locations[i].name = n
        saveLocations()
        for p in [left, right] where p.location.id == loc.id { p.location.name = n }
    }

    private func updateBookmark(_ id: String, _ data: Data) {
        guard let i = locations.firstIndex(where: { $0.id == id }) else { return }
        locations[i].bookmark = data
        saveLocations()
    }

    func cycleLocation(_ side: Side) {
        let p = panel(side)
        let i = locations.firstIndex(where: { $0.id == p.location.id }) ?? 0
        p.setLocation(locations[(i + 1) % locations.count])
        activate(side)
    }

    // MARK: Meldungen

    func showMessage(_ title: String, _ text: String) {
        dialog = .message(title: title, text: text)
    }

    func showError(_ error: Error, title: String = "Fehler") {
        let ns = error as NSError
        var text = ns.localizedDescription
        if let reason = ns.localizedFailureReason, !text.contains(reason) { text += "\n" + reason }
        showMessage(title, text)
    }

    func flash(_ text: String) {
        toast = text
        toastTask?.cancel()
        toastTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            if !Task.isCancelled { self?.toast = nil }
        }
    }

    func reloadBoth() {
        left.reload()
        right.reload()
    }
}
