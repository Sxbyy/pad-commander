import Foundation
import UniformTypeIdentifiers

/// Dateien, die von aussen kommen: "Oeffnen in" / Teilen an die App und Ziehen und Ablegen.
extension AppModel {
    /// Uebernimmt eine Datei aus einer anderen App in den Ordner "Eingang".
    func receive(url: URL) {
        guard url.isFileURL else { return }
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        let inbox = LocationAccess.documents.appendingPathComponent("Eingang", isDirectory: true)
        if url.standardizedFileURL.path.hasPrefix(LocationAccess.documents.standardizedFileURL.path + "/"),
           !url.path.contains("/Inbox/") {
            // liegt schon in unserem Ordner
            left.setLocation(.iPad, components: [])
            _ = left.reveal(url)
            activate(.left)
            return
        }
        do {
            try FileManager.default.createDirectory(at: inbox, withIntermediateDirectories: true)
            let dst = FileOps.uniqueURL(inbox.appendingPathComponent(url.lastPathComponent))
            try FileOps.coordinatedRead(url) { u in try FileManager.default.copyItem(at: u, to: dst) }
            if url.path.contains("/Inbox/") { try? FileManager.default.removeItem(at: url) }
            active.setLocation(.iPad, components: ["Eingang"])
            active.reload(select: dst.lastPathComponent)
            active.requestScroll()
            flash("„\(dst.lastPathComponent)“ liegt jetzt in iPad:\\Eingang")
        } catch {
            showError(error, title: "Datei übernehmen")
        }
    }

    /// Beginn eines Ziehvorgangs aus einem Fenster.
    func beginDrag(_ item: FileItem, in panel: PanelModel) -> NSItemProvider {
        activate(panel.side)
        if !panel.marked.contains(item.url) { panel.marked = [] }
        panel.cursor = item.url
        let sources = panel.selection.map { $0.url }
        dragSources = sources
        dragSide = panel.side
        dragTime = Date()
        if item.isDirectory {
            let p = NSItemProvider()
            p.suggestedName = item.name
            p.registerObject(item.url as NSURL, visibility: .all)
            return p
        }
        let provider = NSItemProvider(contentsOf: item.url) ?? NSItemProvider(object: item.url as NSURL)
        provider.suggestedName = item.name
        return provider
    }

    /// Ablegen in einem Fenster.
    func handleDrop(_ providers: [NSItemProvider], on panel: PanelModel) -> Bool {
        let internalDrag = !dragSources.isEmpty && Date().timeIntervalSince(dragTime) < 120
        if internalDrag {
            let sources = dragSources
            let from = dragSide
            dragSources = []
            guard from != panel.side else { return false }
            activate(from)
            prepareTransfer(.copy, sources: sources, targetSide: panel.side)
            return true
        }
        guard let dir = panel.dir else { return false }
        activate(panel.side)
        var count = 0
        for provider in providers {
            let type = provider.registeredTypeIdentifiers.first(where: { UTType($0)?.conforms(to: .item) == true }) ?? UTType.item.identifier
            let name = provider.suggestedName
            count += 1
            provider.loadFileRepresentation(forTypeIdentifier: type) { url, error in
                guard let url else { return }
                var fileName = name ?? url.lastPathComponent
                if (fileName as NSString).pathExtension.isEmpty, !url.pathExtension.isEmpty {
                    fileName += "." + url.pathExtension
                }
                let dst = FileOps.uniqueURL(dir.appendingPathComponent(fileName))
                let ok = (try? FileManager.default.copyItem(at: url, to: dst)) != nil
                Task { @MainActor in
                    panel.reload(select: ok ? dst.lastPathComponent : nil)
                    if ok { AppModel.shared.flash("„\(dst.lastPathComponent)“ abgelegt") }
                }
            }
        }
        return count > 0
    }
}
