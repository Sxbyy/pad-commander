import SwiftUI
import UniformTypeIdentifiers

struct Columns {
    static let ext: CGFloat = 50
    static let size: CGFloat = 98
    static let date: CGFloat = 134
    let showExt: Bool
    let showSize: Bool
    let showDate: Bool

    init(width: CGFloat) {
        showDate = width > 480
        showExt = width > 330
        showSize = width > 250
    }
}

struct PanelView: View {
    let model: AppModel
    let panel: PanelModel
    @State private var dropTargeted = false

    var body: some View {
        let t = model.theme
        let isActive = model.activeSide == panel.side
        GeometryReader { geo in
            let cols = Columns(width: geo.size.width)
            VStack(spacing: t.classic ? 2 : 6) {
                DriveBar(model: model, panel: panel)
                PathLine(model: model, panel: panel, active: isActive)
                VStack(spacing: 0) {
                    HeaderRow(model: model, panel: panel, cols: cols)
                    FileList(model: model, panel: panel, cols: cols, active: isActive)
                }
                .background(t.listBg)
                .bevel(t, .sunken)
                .overlay {
                    if dropTargeted {
                        RoundedRectangle(cornerRadius: t.classic ? 0 : 12)
                            .strokeBorder(t.accent2, lineWidth: 3)
                            .allowsHitTesting(false)
                    }
                }
                Text(panel.statusLine)
                    .font(t.font(12))
                    .foregroundStyle(t.classic ? Color.black : t.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
                    .frame(height: 20)
                    .accessibilityIdentifier("status-" + panel.side.tag)
            }
        }
        .simultaneousGesture(TapGesture().onEnded { model.activate(panel.side) })
        .onDrop(of: [UTType.item], isTargeted: $dropTargeted) { providers in
            model.handleDrop(providers, on: panel)
        }
    }
}

// MARK: Laufwerksleiste

struct DriveBar: View {
    let model: AppModel
    let panel: PanelModel

    var body: some View {
        let t = model.theme
        HStack(spacing: 3) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 3) {
                    ForEach(model.locations) { loc in
                        let selected = loc.id == panel.location.id
                        Button {
                            model.activate(panel.side)
                            if selected { panel.goRoot() } else { panel.setLocation(loc) }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: loc.icon).font(.system(size: 13))
                                Text(loc.shortName)
                            }
                            .foregroundStyle(selected && !t.classic ? Color.white : t.faceText)
                        }
                        .buttonStyle(DriveButtonStyle(theme: t, selected: selected))
                        .contextMenu {
                            if loc.kind == .bookmark {
                                Button("Umbenennen …", systemImage: "pencil") {
                                    model.dialog = .input(InputDialog(title: "Ort umbenennen", prompt: "Anzeigename für den Ort:", text: loc.name) { name in
                                        model.renameLocation(loc, to: name)
                                    })
                                }
                                Button("Aus der Leiste entfernen", systemImage: "minus.circle", role: .destructive) {
                                    model.removeLocation(loc)
                                }
                            } else {
                                Text("In der Dateien-App: Auf meinem iPad › Pad Commander")
                            }
                        }
                        .accessibilityIdentifier("drive-\(panel.side.tag)-\(loc.name)")
                    }
                    Button {
                        model.activate(panel.side)
                        model.addLocationFromPicker()
                    } label: {
                        Image(systemName: "plus").font(.system(size: 13, weight: .bold)).foregroundStyle(t.faceText)
                    }
                    .buttonStyle(DriveButtonStyle(theme: t, selected: false))
                    .accessibilityIdentifier("drive-\(panel.side.tag)-add")
                }
                .padding(.vertical, 1)
            }
            Text(FreeSpace.text(panel.root, classic: t.classic))
                .font(t.font(12))
                .foregroundStyle(t.classic ? Color.black : t.secondaryText)
                .lineLimit(1)
                .fixedSize()
        }
        .frame(height: 30)
    }
}

struct DriveButtonStyle: ButtonStyle {
    let theme: Theme
    let selected: Bool

    func makeBody(configuration: Configuration) -> some View {
        let down = selected || configuration.isPressed
        return configuration.label
            .font(theme.font(13))
            .lineLimit(1)
            .padding(.horizontal, 7)
            .frame(height: 26)
            .background {
                if theme.classic {
                    selected ? Color(hex: 0xDFDFDF) : theme.face
                } else if selected {
                    LinearGradient(colors: [theme.accent, theme.accent2], startPoint: .leading, endPoint: .trailing).opacity(0.85)
                } else {
                    Color.white.opacity(configuration.isPressed ? 0.14 : 0.06)
                }
            }
            .bevel(theme, down ? .sunken : .raised, radius: theme.classic ? nil : 8)
    }
}

enum FreeSpace {
    static func text(_ root: URL?, classic: Bool) -> String {
        guard let root,
              let v = try? root.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey, .volumeTotalCapacityKey]),
              let free = v.volumeAvailableCapacityForImportantUsage else { return "" }
        if classic, let total = v.volumeTotalCapacity {
            return "\(Format.kilo(free)) von \(Format.kilo(Int64(total))) frei"
        }
        return Format.human(free) + " frei"
    }
}

// MARK: Pfadzeile

struct PathLine: View {
    let model: AppModel
    let panel: PanelModel
    let active: Bool

    var body: some View {
        let t = model.theme
        HStack(spacing: 3) {
            Menu {
                Button(panel.location.name, systemImage: panel.location.icon) { panel.goRoot() }
                ForEach(Array(panel.components.enumerated()), id: \.offset) { i, name in
                    Button(String(repeating: "  ", count: i + 1) + name, systemImage: "folder") {
                        panel.setLocation(panel.location, components: Array(panel.components.prefix(i + 1)))
                    }
                }
            } label: {
                Text(panel.pathLine(classic: t.classic))
                    .font(t.classic ? t.font(14, weight: .semibold) : .system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundStyle(active ? t.pathActiveText : t.pathInactiveText)
                    .lineLimit(1)
                    .truncationMode(.head)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 6)
                    .frame(height: 26)
                    .background(active ? t.pathActiveBg : t.pathInactiveBg)
                    .clipShape(RoundedRectangle(cornerRadius: t.classic ? 0 : 8, style: .continuous))
                    .contentShape(Rectangle())
            }
            .simultaneousGesture(TapGesture().onEnded { model.activate(panel.side) })
            .accessibilityIdentifier("path-" + panel.side.tag)
            Button {
                model.activate(panel.side)
                panel.goRoot()
            } label: {
                Text(t.classic ? "\\" : "⌂").font(t.font(14, weight: .bold)).frame(width: 18)
            }
            .buttonStyle(PanelButtonStyle(theme: t, compact: true))
            Button {
                model.activate(panel.side)
                panel.goUp()
            } label: {
                Text("..").font(t.font(14, weight: .bold)).frame(width: 18)
            }
            .buttonStyle(PanelButtonStyle(theme: t, compact: true))
            .accessibilityIdentifier("up-" + panel.side.tag)
        }
    }
}

// MARK: Spaltenkoepfe

struct HeaderRow: View {
    let model: AppModel
    let panel: PanelModel
    let cols: Columns

    private func head(_ key: SortKey, width: CGFloat?, align: Alignment) -> some View {
        let t = model.theme
        let arrow = panel.sortKey == key ? (panel.ascending ? " ▲" : " ▼") : ""
        return Button {
            model.activate(panel.side)
            panel.setSort(key)
        } label: {
            Text(key.title + arrow)
                .font(t.font(13, weight: t.classic ? .regular : .semibold))
                .foregroundStyle(t.classic ? Color.black : t.secondaryText)
                .lineLimit(1)
                .frame(maxWidth: width ?? .infinity, alignment: align)
                .frame(width: width)
                .padding(.horizontal, 4)
                .frame(height: 24)
                .background(t.headerBg)
                .overlay { if t.classic { BevelLines(theme: t, style: .raised) } }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    var body: some View {
        HStack(spacing: 0) {
            head(.name, width: nil, align: .leading)
            if cols.showExt { head(.ext, width: Columns.ext, align: .leading) }
            if cols.showSize { head(.size, width: Columns.size, align: .trailing) }
            if cols.showDate { head(.date, width: Columns.date, align: .trailing) }
        }
        .padding(model.theme.classic ? 2 : 0)
    }
}

// MARK: Liste

struct FileList: View {
    let model: AppModel
    let panel: PanelModel
    let cols: Columns
    let active: Bool

    var body: some View {
        let t = model.theme
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(panel.items) { item in
                        FileRow(model: model, panel: panel, item: item, cols: cols, active: active)
                            .id(item.url)
                    }
                    if let err = panel.loadError {
                        Text(err)
                            .font(t.font(14))
                            .foregroundStyle(t.markedText)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else if panel.items.filter({ !$0.isParent }).isEmpty {
                        Text("(leer)")
                            .font(t.font(14))
                            .foregroundStyle(t.secondaryText)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, t.classic ? 2 : 4)
                .padding(.vertical, 2)
            }
            .refreshable { panel.reload() }
            .onChange(of: panel.scrollToken) {
                if let c = panel.cursor { proxy.scrollTo(c) }
            }
        }
        .accessibilityIdentifier("list-" + panel.side.tag)
    }
}

// MARK: Zeile

struct FileRow: View {
    let model: AppModel
    let panel: PanelModel
    let item: FileItem
    let cols: Columns
    let active: Bool

    private var displayName: String {
        let t = model.theme
        if item.isParent { return t.classic ? "[..]" : ".." }
        if item.isDirectory && t.classic { return "[" + item.name + "]" }
        if t.classic && !item.ext.isEmpty && cols.showExt { return item.baseName }
        return item.name
    }

    private var sizeText: String {
        if item.isParent { return "" }
        let t = model.theme
        if item.isDirectory {
            if let s = panel.dirSizes[item.url] { return t.classic ? Format.bytes(s) : Format.human(s) }
            return t.classic ? "<DIR>" : "Ordner"
        }
        if item.isCloudOnly { return "iCloud" }
        return t.classic ? Format.bytes(item.size) : Format.human(item.size)
    }

    var body: some View {
        let t = model.theme
        let isCursor = panel.cursor == item.url
        let isMarked = panel.marked.contains(item.url)
        let filled = isCursor && active
        let color: Color = filled ? (isMarked ? t.cursorMarkedText : t.cursorText) : (isMarked ? t.markedText : t.listText)
        let iconColor: Color = isMarked ? color : (item.isDirectory && !item.isParent ? t.folder : (filled ? t.cursorText : t.secondaryText))
        HStack(spacing: 6) {
            Image(systemName: isMarked ? "checkmark.circle.fill" : item.symbol)
                .font(.system(size: 15))
                .foregroundStyle(iconColor)
                .frame(width: 30, height: t.rowHeight)
                .contentShape(Rectangle())
                .onTapGesture { model.toggleMarkByTap(item, in: panel) }
                .accessibilityIdentifier("mark-\(panel.side.tag)-\(item.name)")
            Text(displayName)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
            if cols.showExt {
                Text(item.ext)
                    .lineLimit(1)
                    .frame(width: Columns.ext, alignment: .leading)
            }
            if cols.showSize {
                Text(sizeText)
                    .lineLimit(1)
                    .monospacedDigit()
                    .frame(width: Columns.size, alignment: .trailing)
            }
            if cols.showDate {
                Text(Format.date(item.modified))
                    .lineLimit(1)
                    .monospacedDigit()
                    .frame(width: Columns.date, alignment: .trailing)
            }
        }
        .font(t.font())
        .foregroundStyle(color)
        .padding(.trailing, 6)
        .frame(height: t.rowHeight)
        .background {
            if filled {
                if t.classic {
                    t.cursorBg
                } else {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(LinearGradient(colors: [t.accent.opacity(0.55), t.accent2.opacity(0.35)], startPoint: .leading, endPoint: .trailing))
                }
            }
        }
        .overlay {
            if isCursor && !active {
                if t.classic {
                    Rectangle().strokeBorder(t.inactiveCursor, style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
                } else {
                    RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(t.inactiveCursor, lineWidth: 1)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { model.tap(item, in: panel) }
        .contextMenu { RowMenu(model: model, panel: panel, item: item) }
        .onDrag {
            model.beginDrag(item, in: panel)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("row-\(panel.side.tag)-\(item.name)")
        .accessibilityAddTraits(isCursor ? .isSelected : [])
    }
}

struct RowMenu: View {
    let model: AppModel
    let panel: PanelModel
    let item: FileItem

    private func prep() {
        model.activate(panel.side)
        if !panel.marked.contains(item.url) { panel.marked = [] }
        panel.cursor = item.url
    }

    var body: some View {
        let m = model
        let marked = panel.marked.contains(item.url)
        let n = marked ? panel.marked.count : 1
        let suffix = n > 1 ? " (\(n))" : ""
        if !item.isParent {
            Button(item.isDirectory ? "Öffnen" : "Ansehen", systemImage: item.isDirectory ? "folder" : "eye") {
                prep(); m.open(item, in: panel)
            }
            if !item.isDirectory && item.isText {
                Button("Bearbeiten (F4)", systemImage: "square.and.pencil") { prep(); m.edit() }
            }
            Button(marked ? "Markierung aufheben" : "Markieren", systemImage: marked ? "circle" : "checkmark.circle") {
                m.toggleMarkByTap(item, in: panel)
            }
            Divider()
            Button("Kopieren ins andere Fenster" + suffix, systemImage: "doc.on.doc") { prep(); m.copy() }
            Button("Verschieben ins andere Fenster" + suffix, systemImage: "arrow.right.doc.on.clipboard") { prep(); m.move() }
            Button("Umbenennen", systemImage: "pencil") { prep(); m.rename() }
            Divider()
            if item.isZip {
                Button("Hier entpacken", systemImage: "archivebox.circle") { prep(); m.unpack(item, into: panel) }
                Button("Ins andere Fenster entpacken", systemImage: "archivebox.circle") { prep(); m.unpack(item, into: m.panel(panel.side.other)) }
            }
            Button("Packen …" + suffix, systemImage: "archivebox") { prep(); m.packSelection() }
            Button("Teilen" + suffix, systemImage: "square.and.arrow.up") { prep(); m.share() }
            if item.isDirectory {
                Button("Ordnergröße berechnen", systemImage: "sum") { m.computeSize(item, in: panel) }
            }
            Button("Eigenschaften", systemImage: "info.circle") { prep(); m.properties() }
            Divider()
            Button("Löschen" + suffix, systemImage: "trash", role: .destructive) { prep(); m.deleteSelection() }
        } else {
            Button("Eine Ebene hoch", systemImage: "arrow.turn.left.up") { panel.goUp() }
        }
    }
}
