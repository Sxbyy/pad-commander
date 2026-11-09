import SwiftUI

struct SheetHost: View {
    let model: AppModel
    let kind: SheetKind

    var body: some View {
        Group {
            switch kind {
            case .editor(let doc): EditorView(model: model, doc: doc)
            case .search: SearchView(model: model)
            case .settings: SettingsView(model: model)
            case .help: HelpView(model: model)
            }
        }
        .preferredColorScheme(model.theme.classic ? .light : .dark)
        .tint(model.theme.classic ? Color(hex: 0x000080) : model.theme.accent)
    }
}

// MARK: Editor (F4)

struct EditorView: View {
    let model: AppModel
    let doc: EditorDoc
    @State private var text: String
    @State private var dirty = false
    @State private var askDiscard = false
    @State private var saveFailed = false

    init(model: AppModel, doc: EditorDoc) {
        self.model = model
        self.doc = doc
        _text = State(initialValue: doc.text)
    }

    private func save() -> Bool {
        if model.saveEditor(doc, text: text) {
            dirty = false
            return true
        }
        saveFailed = true
        return false
    }

    var body: some View {
        NavigationStack {
            TextEditor(text: $text)
                .font(.system(size: 15, design: .monospaced))
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .padding(.horizontal, 8)
                .onChange(of: text) { dirty = true }
                .navigationTitle(doc.url.lastPathComponent + (dirty ? " •" : ""))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Schließen") {
                            if dirty { askDiscard = true } else { model.sheet = nil }
                        }
                        .accessibilityIdentifier("editor-close")
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Speichern") { _ = save() }
                            .keyboardShortcut("s", modifiers: .command)
                            .accessibilityIdentifier("editor-save")
                    }
                }
                .alert("Änderungen speichern?", isPresented: $askDiscard) {
                    Button("Speichern") { if save() { model.sheet = nil } }
                    Button("Verwerfen", role: .destructive) { model.sheet = nil }
                    Button("Abbrechen", role: .cancel) {}
                } message: {
                    Text("„\(doc.url.lastPathComponent)“ wurde geändert.")
                }
                .alert("Speichern fehlgeschlagen", isPresented: $saveFailed) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text("Die Datei konnte nicht gespeichert werden. Details stehen nach dem Schließen im Hauptfenster.")
                }
        }
        .interactiveDismissDisabled(dirty)
    }
}

// MARK: Suchen (Alt+F7)

enum Searcher {
    static func run(dir: URL, pattern: String, text: String, subdirs: Bool) -> [URL] {
        var out: [URL] = []
        let fm = FileManager.default
        let opts: FileManager.DirectoryEnumerationOptions = subdirs ? [] : [.skipsSubdirectoryDescendants]
        guard let en = fm.enumerator(at: dir, includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey], options: opts) else { return [] }
        for case let u as URL in en {
            if Task.isCancelled || out.count >= 2000 { break }
            guard Lister.matches(u.lastPathComponent, pattern: pattern) else { continue }
            if !text.isEmpty {
                let v = try? u.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey])
                if v?.isDirectory == true { continue }
                if (v?.fileSize ?? 0) > 20_000_000 { continue }
                guard let data = try? Data(contentsOf: u),
                      let s = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .windowsCP1252),
                      s.range(of: text, options: [.caseInsensitive, .diacriticInsensitive]) != nil else { continue }
            }
            out.append(u)
        }
        return out
    }
}

struct SearchView: View {
    let model: AppModel
    @State private var pattern = "*.*"
    @State private var contains = ""
    @State private var subdirs = true
    @State private var results: [URL] = []
    @State private var running = false
    @State private var searched = false
    @State private var job: Task<[URL], Never>?

    private var baseDir: URL? { model.active.dir }

    private func start() {
        guard let dir = baseDir else { return }
        results = []
        running = true
        let pat = pattern, txt = contains, sub = subdirs
        let task = Task.detached(priority: .userInitiated) { Searcher.run(dir: dir, pattern: pat, text: txt, subdirs: sub) }
        job = task
        Task { @MainActor in
            let found = await task.value
            results = found
            running = false
            searched = true
        }
    }

    private func stop() {
        job?.cancel()
        running = false
    }

    private func relative(_ u: URL) -> String {
        guard let base = baseDir else { return u.path }
        let b = base.resolvingSymlinksInPath().path
        let p = u.deletingLastPathComponent().resolvingSymlinksInPath().path
        if p.hasPrefix(b) {
            let rest = String(p.dropFirst(b.count))
            return rest.isEmpty ? "(hier)" : rest
        }
        return p
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Suchen in \(model.active.location.name):\(model.active.relativePath)") {
                    TextField("Dateiname, z. B. *.pdf oder bericht", text: $pattern)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .accessibilityIdentifier("search-pattern")
                    TextField("Enthält Text (optional)", text: $contains)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    Toggle("Unterordner durchsuchen", isOn: $subdirs)
                    Button(running ? "Suche stoppen" : "Suche starten", systemImage: running ? "stop.circle" : "magnifyingglass") {
                        if running { stop() } else { start() }
                    }
                    .accessibilityIdentifier("search-start")
                }
                Section(running ? "Suche läuft …" : (searched ? "\(results.count) Treffer" : "Treffer")) {
                    if running { ProgressView() }
                    ForEach(results, id: \.self) { u in
                        Button {
                            model.sheet = nil
                            _ = model.active.reveal(u)
                        } label: {
                            HStack {
                                Image(systemName: FileOps.isDir(u) ? "folder.fill" : "doc")
                                VStack(alignment: .leading) {
                                    Text(u.lastPathComponent).foregroundStyle(.primary)
                                    Text(relative(u)).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Suchen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") { stop(); model.sheet = nil }
                }
            }
        }
    }
}

// MARK: Einstellungen (F10)

struct SettingsView: View {
    let model: AppModel

    var body: some View {
        let m = model
        NavigationStack {
            Form {
                Section("Aussehen") {
                    Picker("Design", selection: Binding(get: { m.themeKind }, set: { m.setTheme($0) })) {
                        ForEach(ThemeKind.allCases) { k in Text(k.title).tag(k) }
                    }
                    .pickerStyle(.segmented)
                    Picker("Schriftgröße", selection: Binding(get: { m.textSize }, set: { m.setTextSize($0) })) {
                        ForEach(TextSize.allCases) { s in Text(s.title).tag(s) }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("textsize")
                    Toggle("Versteckte Dateien anzeigen", isOn: Binding(get: { m.showHidden }, set: { m.setShowHidden($0) }))
                }
                Section("Sicherheit") {
                    Toggle("Vor dem Löschen nachfragen", isOn: Binding(get: { m.confirmDelete }, set: { m.setConfirmDelete($0) }))
                }
                Section {
                    ForEach(m.locations) { loc in
                        Label(loc.name, systemImage: loc.icon)
                    }
                    .onDelete { idx in
                        for i in idx where m.locations[i].kind == .bookmark { m.removeLocation(m.locations[i]) }
                    }
                    Button("Ort aus der Dateien-App hinzufügen …", systemImage: "externaldrive.badge.plus") {
                        m.addLocationFromPicker()
                    }
                } header: {
                    Text("Orte (Laufwerksleiste)")
                } footer: {
                    Text("„iPad“: " + AppInfo.homeHint + ". Weitere Orte können iCloud Drive, USB-Sticks, Netzlaufwerke oder Ordner anderer Apps sein. Zum Entfernen nach links wischen.")
                }
                Section("Über") {
                    LabeledContent("Version", value: AppInfo.versionText)
                    LabeledContent("Läuft als", value: AppInfo.runsAs)
                    Text("Pad Commander ist ein eigenständiger Dateimanager mit zwei Fenstern im Stil der klassischen Commander-Programme. Er ist nicht mit anderen Herstellern verbunden.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Einstellungen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { m.sheet = nil }
                }
            }
        }
    }
}

// MARK: Hilfe (F1)

struct HelpView: View {
    let model: AppModel

    private let keys: [(String, String)] = [
        ("F2 / Umschalt+F6", "Umbenennen"), ("F3", "Ansehen (Vorschau, Bilder, PDF, Video …)"),
        ("F4", "Textdatei bearbeiten"), ("Umschalt+F4", "Neue Textdatei"),
        ("F5", "Kopieren ins andere Fenster"), ("F6", "Verschieben ins andere Fenster"),
        ("F7", "Neuer Ordner"), ("F8 / Entf", "Löschen"), ("F9", "Teilen"), ("F10", "Einstellungen"),
        ("Alt+F5", "Packen (ZIP)"), ("Alt+F9", "Entpacken ins andere Fenster"), ("Alt+F7", "Suchen"),
        ("Alt+F1 / Alt+F2", "Ort links / rechts wechseln"), ("Alt+Enter", "Eigenschaften"),
        ("⌘1 … ⌘0", "Wie F1 … F10 (für Tastaturen ohne F-Tasten)"),
        ("⌘⌥1 / ⌘⌥2 / ⌘⌥5 / ⌘⌥7 / ⌘⌥9", "Wie Alt+F1 / Alt+F2 / Alt+F5 / Alt+F7 / Alt+F9"),
        ("⌘.", "Wie Esc: Dialog schließen, Markierung aufheben, Abbrechen"),
        ("⌘+ / ⌘-", "Schrift größer / kleiner"),
        ("Tab", "Fenster wechseln"), ("↑ ↓ Bild↑ Bild↓ Pos1 Ende", "Cursor bewegen"),
        ("Enter / →", "Öffnen"), ("← / Rücktaste", "Eine Ebene hoch"),
        ("Leertaste", "Markieren (Ordner: Größe berechnen)"), ("Esc", "Markierung aufheben"),
        ("Strg+A", "Alles markieren"), ("Strg++ / Strg+-", "Gruppe markieren / demarkieren"),
        ("Strg+U", "Fenster tauschen"), ("Strg+E", "Gleicher Ordner im anderen Fenster"),
        ("Strg+R", "Neu einlesen"), ("Strg+H", "Versteckte Dateien"), ("Strg+T", "Design wechseln")
    ]

    private let gestures: [(String, String)] = [
        ("Antippen", "Cursor setzen"), ("Zweimal antippen", "Öffnen"),
        ("Symbol antippen", "Markieren / Markierung aufheben"), ("Lange drücken", "Menü mit allen Befehlen"),
        ("Ziehen", "Ins andere Fenster ablegen = Kopieren, aus anderen Apps = Importieren"),
        ("Pfadzeile antippen", "Zu einem übergeordneten Ordner springen"),
        ("Nach unten ziehen", "Neu einlesen")
    ]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(keys.indices, id: \.self) { i in
                        LabeledContent(keys[i].0, value: keys[i].1)
                    }
                } header: {
                    Text("Tastatur")
                } footer: {
                    Text("Apple-Tastaturen haben oft keine F-Tasten und kein Esc: dann ⌘ + Ziffer und ⌘. nehmen. Bei Tastaturen mit F-Tasten muss man je nach Modell zusätzlich fn bzw. die Globus-Taste drücken. Esc lässt sich auch auf die Feststelltaste legen: Einstellungen › Allgemein › Tastatur › Hardwaretastatur › Sondertasten.")
                }
                Section("Gesten") {
                    ForEach(gestures.indices, id: \.self) { i in
                        LabeledContent(gestures[i].0, value: gestures[i].1)
                    }
                }
            }
            .navigationTitle("Tasten und Gesten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { model.sheet = nil }
                }
            }
        }
    }
}
