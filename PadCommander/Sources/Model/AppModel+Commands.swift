import Foundation
import UIKit

typealias OpProgress = Progress

extension AppModel {
    // MARK: Tastatur

    /// F1 ... F10 in der Reihenfolge der Ziffern 1 ... 0 (Cmd+Ziffer ersetzt die F-Taste).
    static let fKeys: [String] = [UIKeyCommand.f1, UIKeyCommand.f2, UIKeyCommand.f3, UIKeyCommand.f4, UIKeyCommand.f5,
                                  UIKeyCommand.f6, UIKeyCommand.f7, UIKeyCommand.f8, UIKeyCommand.f9, UIKeyCommand.f10]
    static let digits = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]

    func handleKey(_ rawInput: String, _ rawFlags: UIKeyModifierFlags) {
        var input = rawInput
        var flags = rawFlags.intersection([.shift, .control, .alternate, .command])
        // Apple-Tastaturen haben keine F-Tasten und oft kein Esc: Cmd+1 ... Cmd+0 = F1 ... F10, Cmd+. = Esc
        if flags.contains(.command) {
            if let i = Self.digits.firstIndex(of: input) {
                input = Self.fKeys[i]
                flags.remove(.command)
            } else if input == "." {
                input = UIKeyCommand.inputEscape
                flags.remove(.command)
            }
        }
        if isUITest { lastKey += Self.keyName(input, flags) + " " }
        if keyLogOnly { return }
        if busy != nil {
            if input == UIKeyCommand.inputEscape { busy?.cancel?() }
            return
        }
        // Dieselbe Enter-/Esc-Taste, die gerade einen Dialog geschlossen hat, nicht noch einmal auswerten
        if input == "\r" || input == UIKeyCommand.inputEscape, Date().timeIntervalSince(dialogClosedAt) < 0.35 { return }
        if let d = dialog {
            dialogKey(input, d)
            return
        }
        guard sheet == nil else { return }
        let p = active
        let shift = flags.contains(.shift)
        let alt = flags.contains(.alternate)
        let ctrl = flags.contains(.control)
        let cmd = flags.contains(.command)
        switch input {
        case UIKeyCommand.inputUpArrow: p.moveCursor(by: -1)
        case UIKeyCommand.inputDownArrow: p.moveCursor(by: 1)
        case UIKeyCommand.inputPageUp: p.moveCursor(by: -20)
        case UIKeyCommand.inputPageDown: p.moveCursor(by: 20)
        case UIKeyCommand.inputHome: p.cursorToStart()
        case UIKeyCommand.inputEnd: p.cursorToEnd()
        case UIKeyCommand.inputLeftArrow: p.goUp()
        case UIKeyCommand.inputRightArrow:
            if let c = p.cursorItem, c.isDirectory { p.enter(c) }
        case "\r":
            if alt { properties() } else if let c = p.cursorItem { open(c, in: p) }
        case "\t": activate(activeSide.other)
        case " ":
            if let c = p.cursorItem {
                p.toggleMark(c)
                if c.isDirectory && !c.isParent && p.marked.contains(c.url) { computeSize(c, in: p) }
                p.moveCursor(by: 1)
            }
        case "\u{8}": p.goUp()
        case UIKeyCommand.inputEscape: p.unmarkAll()
        case UIKeyCommand.inputDelete: deleteSelection()
        case UIKeyCommand.f1:
            if alt { cycleLocation(.left) } else { sheet = .help }
        case UIKeyCommand.f2:
            if alt { cycleLocation(.right) } else { rename() }
        case UIKeyCommand.f3: view()
        case UIKeyCommand.f4:
            if shift { newFile() } else { edit() }
        case UIKeyCommand.f5:
            if alt { packSelection() } else { copy() }
        case UIKeyCommand.f6:
            if shift { rename() } else { move() }
        case UIKeyCommand.f7:
            if alt { sheet = .search } else { newFolder() }
        case UIKeyCommand.f8: deleteSelection()
        case UIKeyCommand.f9:
            if alt { unpackSelection() } else { share() }
        case UIKeyCommand.f10: sheet = .settings
        case "u" where ctrl: swapPanels()
        case "r" where ctrl: reloadBoth(); flash("Neu eingelesen")
        case "h" where ctrl: setShowHidden(!showHidden)
        case "a" where ctrl: p.markAll()
        case "t" where ctrl: cycleTheme()
        case "e" where ctrl: sameDirInOther()
        case "+" where ctrl: markGroup(select: true)
        case "-" where ctrl: markGroup(select: false)
        case "+" where cmd, "=" where cmd: stepTextSize(1)
        case "-" where cmd: stepTextSize(-1)
        default:
            break
        }
    }

    /// Enter / Esc, solange ein eigener Dialog offen ist und kein Textfeld die Taste bekommt.
    private func dialogKey(_ input: String, _ d: Dialog) {
        let esc = input == UIKeyCommand.inputEscape
        guard esc || input == "\r" else { return }
        switch d {
        case .confirm(let c):
            dialog = nil
            if !esc { c.action() }
        case .message, .properties:
            dialog = nil
        case .conflict(let c):
            if esc { c.resolve(.cancel) }
        case .input, .transfer:
            if esc { dialog = nil }
        }
    }

    static func keyName(_ input: String, _ flags: UIKeyModifierFlags) -> String {
        let names: [String: String] = [
            UIKeyCommand.f1: "F1", UIKeyCommand.f2: "F2", UIKeyCommand.f3: "F3", UIKeyCommand.f4: "F4",
            UIKeyCommand.f5: "F5", UIKeyCommand.f6: "F6", UIKeyCommand.f7: "F7", UIKeyCommand.f8: "F8",
            UIKeyCommand.f9: "F9", UIKeyCommand.f10: "F10", "\t": "Tab", "\r": "Enter", " ": "Space",
            UIKeyCommand.inputEscape: "Esc", UIKeyCommand.inputUpArrow: "Up", UIKeyCommand.inputDownArrow: "Down",
            UIKeyCommand.inputLeftArrow: "Left", UIKeyCommand.inputRightArrow: "Right", "\u{8}": "Backspace"
        ]
        var mods = ""
        if flags.contains(.control) { mods += "Ctrl+" }
        if flags.contains(.alternate) { mods += "Alt+" }
        if flags.contains(.shift) { mods += "Shift+" }
        if flags.contains(.command) { mods += "Cmd+" }
        return mods + (names[input] ?? input)
    }

    // MARK: Antippen

    /// Einmal tippen setzt den Cursor, zweimal schnell oeffnet.
    func tap(_ item: FileItem, in panel: PanelModel) {
        activate(panel.side)
        let now = Date()
        if lastTapURL == item.url, now.timeIntervalSince(lastTapTime) < 0.45, panel.cursor == item.url {
            lastTapURL = nil
            open(item, in: panel)
        } else {
            lastTapURL = item.url
            lastTapTime = now
            panel.cursor = item.url
        }
    }

    func toggleMarkByTap(_ item: FileItem, in panel: PanelModel) {
        activate(panel.side)
        panel.cursor = item.url
        panel.toggleMark(item)
        if item.isDirectory && panel.marked.contains(item.url) { computeSize(item, in: panel) }
    }

    func open(_ item: FileItem, in panel: PanelModel) {
        if item.isParent { panel.goUp(); return }
        if item.isDirectory { panel.enter(item); return }
        if item.isCloudOnly {
            try? FileManager.default.startDownloadingUbiquitousItem(at: item.url)
            flash("„\(item.name)“ wird aus iCloud geladen …")
            return
        }
        if item.isZip {
            dialog = .confirm(ConfirmDialog(title: "ZIP-Archiv", message: "„\(item.name)“ hier entpacken?", okTitle: "Entpacken") { [weak self] in
                self?.unpack(item, into: panel)
            })
            return
        }
        quickLook(in: panel, start: item)
    }

    // MARK: F3 / F4

    func view() {
        let p = active
        guard let c = p.cursorItem else { return }
        if c.isDirectory {
            if !c.isParent { computeSize(c, in: p) }
            return
        }
        quickLook(in: p, start: c)
    }

    func quickLook(in p: PanelModel, start: FileItem) {
        let markedFiles = p.items.filter { p.marked.contains($0.url) && !$0.isDirectory }
        let files = markedFiles.count > 1 ? markedFiles : p.items.filter { !$0.isDirectory && !$0.isCloudOnly }
        guard !files.isEmpty else { return }
        let index = files.firstIndex(where: { $0.url == start.url }) ?? 0
        Bridges.showQuickLook(urls: files.map { $0.url }, index: index) { [weak p] in p?.reload() }
    }

    func edit() {
        let p = active
        guard let c = p.cursorItem, !c.isDirectory else { return }
        openEditor(c.url)
    }

    func openEditor(_ url: URL, isNew: Bool = false) {
        do {
            let (data, date) = try FileOps.coordinatedRead(url) { u -> (Data, Date?) in
                let attrs = try FileManager.default.attributesOfItem(atPath: u.path)
                let size = (attrs[.size] as? NSNumber)?.int64Value ?? 0
                if size > 8 * 1024 * 1024 { throw OpError("Die Datei ist zu groß für den Editor (über 8 MB).") }
                return (try Data(contentsOf: u), attrs[.modificationDate] as? Date)
            }
            var encoding = String.Encoding.utf8
            var text = String(data: data, encoding: .utf8)
            if text == nil {
                if data.prefix(8000).contains(0) { throw OpError("„\(url.lastPathComponent)“ ist keine Textdatei.") }
                encoding = .windowsCP1252
                text = String(data: data, encoding: .windowsCP1252)
            }
            guard let t = text else { throw OpError("Der Text konnte nicht gelesen werden.") }
            sheet = .editor(EditorDoc(url: url, text: t, encoding: encoding, modified: date, isNew: isNew))
        } catch {
            showError(error, title: "Bearbeiten")
        }
    }

    func saveEditor(_ doc: EditorDoc, text: String) -> Bool {
        guard let data = text.data(using: doc.encoding, allowLossyConversion: false) ?? text.data(using: .utf8) else {
            showMessage("Speichern", "Der Text lässt sich nicht speichern.")
            return false
        }
        do {
            try FileOps.coordinatedWrite(doc.url) { u in try data.write(to: u, options: .atomic) }
            flash("„\(doc.url.lastPathComponent)“ gespeichert")
            reloadBoth()
            return true
        } catch {
            showError(error, title: "Speichern")
            return false
        }
    }

    // MARK: F5 / F6

    func copy() { prepareTransfer(.copy) }
    func move() { prepareTransfer(.move) }

    func prepareTransfer(_ op: TransferJob.Op, sources explicit: [URL]? = nil, targetSide: Side? = nil) {
        let src = active
        let sources = explicit ?? src.selection.map { $0.url }
        guard !sources.isEmpty else { flash("Nichts ausgewählt"); return }
        let side = targetSide ?? activeSide.other
        let target = panel(side)
        var text = target.relativePath
        if sources.count == 1 { text += sources[0].lastPathComponent }
        dialog = .transfer(TransferDialog(op: op, sources: sources, targetSide: side, targetText: text))
    }

    func startTransfer(_ d: TransferDialog) {
        dialog = nil
        let target = panel(d.targetSide)
        guard let root = target.root else { showMessage("Ziel", "Das Ziel ist nicht erreichbar."); return }
        var text = d.targetText.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty { text = "/" }
        let endsWithSlash = text.hasSuffix("/")
        let comps = text.split(separator: "/").map(String.init).filter { !$0.isEmpty && $0 != "." }
        if comps.contains("..") { showMessage("Ziel", "„..“ ist im Zielpfad nicht erlaubt."); return }
        let full = comps.reduce(root) { $0.appendingPathComponent($1) }
        var targetDir = full
        var renameTo: String?
        if d.sources.count == 1 && !endsWithSlash && !comps.isEmpty {
            let isSelf = full.standardizedFileURL.path == d.sources[0].standardizedFileURL.path
            if !FileOps.isDir(full) || isSelf {
                targetDir = full.deletingLastPathComponent()
                renameTo = comps.last
            }
        }
        let job = TransferJob(op: d.op, sources: d.sources, targetDir: targetDir, renameTo: renameTo, policy: d.policy)
        run(title: d.op == .copy ? "Kopieren" : "Verschieben", cancel: { job.cancel() }, select: renameTo ?? (d.sources.count == 1 ? d.sources[0].lastPathComponent : nil), in: target) { [weak self] in
            job.report = { p in Task { @MainActor in self?.busy?.progress = p } }
            job.ask = { name in await self?.askConflict(name) ?? .cancel }
            try await job.run()
        }
        if d.op == .move { active.unmarkAll() } else { panel(d.targetSide.other).unmarkAll() }
    }

    func askConflict(_ name: String) async -> ConflictChoice {
        await withCheckedContinuation { (cont: CheckedContinuation<ConflictChoice, Never>) in
            dialog = .conflict(ConflictDialog(name: name) { [weak self] choice in
                self?.dialog = nil
                cont.resume(returning: choice)
            })
        }
    }

    /// Fuehrt eine laengere Arbeit aus und zeigt dabei das Fortschrittsfenster.
    func run(title: String, cancel: (() -> Void)?, select: String? = nil, in panelToSelect: PanelModel? = nil,
             work: @escaping () async throws -> Void) {
        busy = BusyState(progress: OpProgress(title: title, detail: "", fraction: nil), cancel: cancel)
        Task { @MainActor in
            var failure: Error?
            do { try await work() } catch { failure = error }
            busy = nil
            reloadBoth()
            if let name = select, let p = panelToSelect { p.reload(select: name); p.requestScroll() }
            if let e = failure {
                if e is CancellationError { flash("Abgebrochen") } else { showError(e, title: title) }
            }
        }
    }

    // MARK: F7 / F8 / Umbenennen / Neue Datei

    func newFolder() {
        let p = active
        guard let dir = p.dir else { return }
        dialog = .input(InputDialog(title: "Neuer Ordner", prompt: "Neuer Ordner (Verzeichnis):", text: "") { [weak self] text in
            guard let self else { return }
            guard let name = FileOps.validName(text) else { self.flash("Ungültiger Name"); return }
            do {
                let url = dir.appendingPathComponent(name, isDirectory: true)
                try FileOps.coordinatedWrite(url) { u in try FileManager.default.createDirectory(at: u, withIntermediateDirectories: true) }
                p.reload(select: name)
                p.requestScroll()
            } catch { self.showError(error, title: "Neuer Ordner") }
        })
    }

    func newFile() {
        let p = active
        guard let dir = p.dir else { return }
        dialog = .input(InputDialog(title: "Neue Textdatei", prompt: "Name der neuen Datei:", text: "Neu.txt", selectBaseName: true) { [weak self] text in
            guard let self else { return }
            guard let name = FileOps.validName(text) else { self.flash("Ungültiger Name"); return }
            let url = dir.appendingPathComponent(name)
            if !FileOps.exists(url) {
                do { try FileOps.coordinatedWrite(url) { u in try Data().write(to: u) } } catch { self.showError(error); return }
            }
            p.reload(select: name)
            p.requestScroll()
            self.openEditor(url, isNew: true)
        })
    }

    func rename() {
        let p = active
        guard let c = p.cursorItem, !c.isParent else { return }
        dialog = .input(InputDialog(title: "Umbenennen", prompt: "Neuer Name für „\(c.name)“:", text: c.name, okTitle: "Umbenennen", selectBaseName: true) { [weak self] text in
            guard let self else { return }
            guard let name = FileOps.validName(text), name != c.name else { return }
            let dst = c.url.deletingLastPathComponent().appendingPathComponent(name)
            if FileOps.exists(dst) && name.lowercased() != c.name.lowercased() {
                self.showMessage("Umbenennen", "„\(name)“ gibt es hier schon.")
                return
            }
            do {
                try FileOps.coordinatedWrite(c.url, options: [.forMoving]) { u in try FileManager.default.moveItem(at: u, to: dst) }
                p.reload(select: name)
                self.panel(p.side.other).reload()
            } catch { self.showError(error, title: "Umbenennen") }
        })
    }

    func deleteSelection() {
        let p = active
        let items = p.selection
        guard !items.isEmpty else { return }
        let what: String
        if items.count == 1 {
            what = items[0].isDirectory ? "den Ordner „\(items[0].name)“ mit allem Inhalt" : "die Datei „\(items[0].name)“"
        } else {
            let d = items.filter { $0.isDirectory }.count
            what = "\(items.count - d) Datei(en) und \(d) Ordner"
        }
        let doIt = { [weak self] in
            guard let self else { return }
            let job = DeleteJob(urls: items.map { $0.url })
            self.run(title: "Löschen", cancel: { job.cancel() }) { [weak self] in
                job.report = { pr in Task { @MainActor in self?.busy?.progress = pr } }
                try await Task.detached { try job.run() }.value
            }
            p.unmarkAll()
        }
        if confirmDelete {
            dialog = .confirm(ConfirmDialog(title: "Löschen", message: "Wirklich \(what) löschen? Das lässt sich nicht rückgängig machen.", okTitle: "Löschen", destructive: true, action: doIt))
        } else {
            doIt()
        }
    }

    // MARK: Markieren

    func markGroup(select: Bool) {
        let p = active
        dialog = .input(InputDialog(title: select ? "Gruppe markieren" : "Gruppe demarkieren",
                                    prompt: "Platzhalter wie *.jpg oder *.pdf;*.txt:", text: "*.*") { text in
            p.mark(pattern: text, select: select, includeDirs: text == "*" || text == "*.*")
        })
    }

    /// Markiert in beiden Fenstern, was im anderen fehlt oder neuer ist.
    func compareDirs() {
        let l = left, r = right
        func files(_ p: PanelModel) -> [String: FileItem] {
            var d: [String: FileItem] = [:]
            for i in p.items where !i.isParent && !i.isDirectory { d[i.name.lowercased()] = i }
            return d
        }
        let lf = files(l), rf = files(r)
        l.marked = []
        r.marked = []
        for (k, a) in lf {
            if let b = rf[k] {
                let da = a.modified ?? .distantPast, db = b.modified ?? .distantPast
                if abs(da.timeIntervalSince(db)) > 2 {
                    if da > db { l.marked.insert(a.url) } else { r.marked.insert(b.url) }
                } else if a.size != b.size {
                    l.marked.insert(a.url); r.marked.insert(b.url)
                }
            } else {
                l.marked.insert(a.url)
            }
        }
        for (k, b) in rf where lf[k] == nil { r.marked.insert(b.url) }
        let n = l.marked.count + r.marked.count
        flash(n == 0 ? "Beide Ordner sind gleich" : "\(n) unterschiedliche Datei(en) markiert")
    }

    // MARK: Fenster

    func swapPanels() {
        let lLoc = left.location, lComps = left.components
        let rLoc = right.location, rComps = right.components
        left.setLocation(rLoc, components: rComps)
        right.setLocation(lLoc, components: lComps)
    }

    func sameDirInOther() {
        inactive.setLocation(active.location, components: active.components)
    }

    func computeSize(_ item: FileItem, in p: PanelModel) {
        let url = item.url
        Task.detached {
            let s = FileOps.size(of: url)
            await MainActor.run { p.dirSizes[url] = s }
        }
    }

    func computeAllSizes() {
        let p = active
        for i in p.items where i.isDirectory && !i.isParent { computeSize(i, in: p) }
    }

    // MARK: Teilen / Importieren / Orte

    func share() {
        let urls = active.selection.filter { !$0.isCloudOnly }.map { $0.url }
        guard !urls.isEmpty else { flash("Nichts ausgewählt"); return }
        Bridges.share(urls)
    }

    func importFiles() {
        let p = active
        Bridges.pickFiles { [weak self] urls in
            guard let self, let dir = p.dir, !urls.isEmpty else { return }
            let job = TransferJob(op: .move, sources: urls, targetDir: dir, renameTo: nil, policy: .rename)
            self.run(title: "Importieren", cancel: { job.cancel() }, select: urls.count == 1 ? urls[0].lastPathComponent : nil, in: p) { [weak self] in
                job.report = { pr in Task { @MainActor in self?.busy?.progress = pr } }
                try await job.run()
            }
        }
    }

    func addLocationFromPicker() {
        Bridges.pickFolder { [weak self] url in
            guard let self, let url else { return }
            self.addLocation(url: url)
        }
    }

    // MARK: Eigenschaften

    func properties() {
        let p = active
        guard let c = p.cursorItem, !c.isParent else { return }
        let created = (try? c.url.resourceValues(forKeys: [.creationDateKey]))?.creationDate
        let info = PropertiesInfo(item: c, location: p.location.name, path: p.relativePath, size: c.isDirectory ? nil : c.size, itemCount: nil, created: created)
        dialog = .properties(info)
        if c.isDirectory {
            let url = c.url
            Task.detached {
                let s = FileOps.size(of: url)
                let n = (FileManager.default.enumerator(atPath: url.path)?.allObjects.count) ?? 0
                await MainActor.run {
                    if case .properties(var cur)? = AppModel.shared.dialog, cur.item.url == url {
                        cur.size = s
                        cur.itemCount = n
                        AppModel.shared.dialog = .properties(cur)
                    }
                    p.dirSizes[url] = s
                }
            }
        }
    }
}
