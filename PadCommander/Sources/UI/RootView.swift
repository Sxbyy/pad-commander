import SwiftUI

struct RootView: View {
    @Bindable var model: AppModel

    var body: some View {
        let t = model.theme
        VStack(spacing: 0) {
            CaptionBar(model: model)
            MenuBar(model: model)
            ToolBar(model: model)
            HStack(spacing: t.classic ? 3 : 10) {
                PanelView(model: model, panel: model.left)
                PanelView(model: model, panel: model.right)
            }
            .padding(.horizontal, t.classic ? 3 : 10)
            .padding(.vertical, t.classic ? 3 : 6)
            FunctionBar(model: model)
        }
        .background(BackgroundView(theme: t).ignoresSafeArea())
        .overlay(alignment: .bottom) {
            if let msg = model.toast {
                Text(msg)
                    .font(t.font(14))
                    .foregroundStyle(t.classic ? Color.black : Color.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(t.classic ? Color(hex: 0xFFFFE1) : Color(hex: 0x1C2233))
                    .bevel(t, .raised, radius: 12)
                    .padding(.bottom, 64)
                    .transition(.opacity)
                    .accessibilityIdentifier("toast")
            }
        }
        .overlay(alignment: .topTrailing) {
            if model.isUITest {
                Text("Tasten: " + model.lastKey)
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
                    .padding(4)
                    .accessibilityIdentifier("lastkey")
            }
        }
        .overlay { DialogLayer(model: model) }
        .sheet(item: $model.sheet) { kind in
            SheetHost(model: model, kind: kind)
        }
        .preferredColorScheme(t.classic ? .light : .dark)
        .tint(t.accent)
        .animation(.easeOut(duration: 0.15), value: model.toast)
    }
}

struct BackgroundView: View {
    let theme: Theme
    var body: some View {
        if theme.classic {
            theme.face
        } else {
            ZStack {
                theme.face
                RadialGradient(colors: [theme.accent.opacity(0.28), .clear], center: .topLeading, startRadius: 10, endRadius: 700)
                RadialGradient(colors: [theme.accent2.opacity(0.18), .clear], center: .bottomTrailing, startRadius: 10, endRadius: 700)
            }
        }
    }
}

// MARK: Titelleiste

struct CaptionBar: View {
    let model: AppModel
    var body: some View {
        let t = model.theme
        let p = model.active
        let where_ = p.components.last ?? p.location.name
        HStack(spacing: 8) {
            Image(systemName: "rectangle.split.2x1.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(t.classic ? Color.white : t.accent2)
            if t.classic {
                Text("Pad Commander 1.0 – \(where_)")
                    .font(t.font(15, weight: .bold))
                    .foregroundStyle(t.captionText)
            } else {
                Text("Pad Commander")
                    .font(t.font(17, weight: .bold))
                    .foregroundStyle(LinearGradient(colors: [t.accent, t.accent2], startPoint: .leading, endPoint: .trailing))
                Text(where_)
                    .font(t.font(15))
                    .foregroundStyle(t.secondaryText)
            }
            Spacer()
            if let busy = model.busy {
                Text(busy.progress.title + " …")
                    .font(t.font(13))
                    .foregroundStyle(t.classic ? Color.white : t.secondaryText)
            }
        }
        .lineLimit(1)
        .padding(.horizontal, 8)
        .frame(height: t.classic ? 30 : 40)
        .background {
            if t.classic { t.captionGradient } else { Color.clear }
        }
        .padding(.horizontal, t.classic ? 3 : 10)
        .padding(.top, t.classic ? 3 : 4)
    }
}

// MARK: Menueleiste

struct MenuBar: View {
    let model: AppModel

    private func title(_ s: String) -> Text {
        Text(String(s.prefix(1))).underline() + Text(String(s.dropFirst()))
    }

    private func menu<C: View>(_ s: String, @ViewBuilder _ content: () -> C) -> some View {
        let items = content()
        return Menu {
            items
        } label: {
            title(s)
                .font(model.theme.font(15))
                .foregroundStyle(model.theme.faceText)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .contentShape(Rectangle())
        }
        .tint(model.theme.faceText)
        .accessibilityIdentifier("menu-" + s)
    }

    var body: some View {
        let m = model
        HStack(spacing: 0) {
            menu("Dateien") {
                Button("Umbenennen (F2)", systemImage: "pencil") { m.rename() }
                Button("Ansehen (F3)", systemImage: "eye") { m.view() }
                Button("Bearbeiten (F4)", systemImage: "square.and.pencil") { m.edit() }
                Button("Neue Textdatei (Umschalt+F4)", systemImage: "doc.badge.plus") { m.newFile() }
                Divider()
                Button("Kopieren (F5)", systemImage: "doc.on.doc") { m.copy() }
                Button("Verschieben (F6)", systemImage: "arrow.right.doc.on.clipboard") { m.move() }
                Button("Neuer Ordner (F7)", systemImage: "folder.badge.plus") { m.newFolder() }
                Button("Löschen (F8)", systemImage: "trash", role: .destructive) { m.deleteSelection() }
                Divider()
                Button("Packen … (Alt+F5)", systemImage: "archivebox") { m.packSelection() }
                Button("Entpacken (Alt+F9)", systemImage: "archivebox.circle") { m.unpackSelection() }
                Button("Teilen (F9)", systemImage: "square.and.arrow.up") { m.share() }
                Button("Aus Dateien-App importieren …", systemImage: "square.and.arrow.down") { m.importFiles() }
                Button("Eigenschaften (Alt+Enter)", systemImage: "info.circle") { m.properties() }
            }
            menu("Markieren") {
                Button("Gruppe markieren … (Strg++)", systemImage: "plus.circle") { m.markGroup(select: true) }
                Button("Gruppe demarkieren … (Strg+-)", systemImage: "minus.circle") { m.markGroup(select: false) }
                Button("Alles markieren (Strg+A)", systemImage: "checkmark.circle") { m.active.markAll() }
                Button("Alles demarkieren (Esc)", systemImage: "circle") { m.active.unmarkAll() }
                Button("Markierung umkehren", systemImage: "circle.lefthalf.filled") { m.active.invertMarks() }
                Divider()
                Button("Ordner vergleichen", systemImage: "rectangle.split.2x1") { m.compareDirs() }
            }
            menu("Befehle") {
                Button("Suchen … (Alt+F7)", systemImage: "magnifyingglass") { m.sheet = .search }
                Button("Alle Ordnergrößen berechnen", systemImage: "sum") { m.computeAllSizes() }
                Divider()
                Button("Fenster tauschen (Strg+U)", systemImage: "arrow.left.arrow.right") { m.swapPanels() }
                Button("Gleicher Ordner im anderen Fenster (Strg+E)", systemImage: "equal.square") { m.sameDirInOther() }
                Button("Neu einlesen (Strg+R)", systemImage: "arrow.clockwise") { m.reloadBoth() }
                Divider()
                Button("Ort aus Dateien-App hinzufügen …", systemImage: "externaldrive.badge.plus") { m.addLocationFromPicker() }
            }
            menu("Ansicht") {
                Picker("Sortieren", selection: Binding(get: { m.active.sortKey }, set: { m.active.sortKey = $0; m.active.resort() })) {
                    ForEach(SortKey.allCases, id: \.self) { k in Text("Nach " + k.title).tag(k) }
                }
                Button(m.active.ascending ? "Absteigend sortieren" : "Aufsteigend sortieren", systemImage: "arrow.up.arrow.down") {
                    m.active.ascending.toggle(); m.active.resort()
                }
                Divider()
                Toggle("Versteckte Dateien (Strg+H)", isOn: Binding(get: { m.showHidden }, set: { m.setShowHidden($0) }))
                Picker("Design", selection: Binding(get: { m.themeKind }, set: { m.setTheme($0) })) {
                    ForEach(ThemeKind.allCases) { k in Text(k.title).tag(k) }
                }
            }
            menu("Konfiguration") {
                Button("Einstellungen … (F10)", systemImage: "gearshape") { m.sheet = .settings }
                Button("Ort hinzufügen …", systemImage: "externaldrive.badge.plus") { m.addLocationFromPicker() }
            }
            menu("Hilfe") {
                Button("Tasten und Gesten (F1)", systemImage: "keyboard") { m.sheet = .help }
            }
            Spacer()
        }
        .padding(.horizontal, model.theme.classic ? 3 : 10)
        .frame(height: 34)
    }
}

// MARK: Werkzeugleiste

struct ToolBar: View {
    let model: AppModel

    private func tool(_ symbol: String, _ id: String, _ action: @escaping () -> Void) -> some View {
        let t = model.theme
        return Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(t.classic ? Color.black : t.faceText)
                .frame(width: 26, height: 22)
        }
        .buttonStyle(PanelButtonStyle(theme: t, compact: true))
        .accessibilityIdentifier("tool-" + id)
    }

    private var sep: some View {
        Rectangle()
            .fill(model.theme.classic ? model.theme.shadow : Color.white.opacity(0.1))
            .frame(width: 1, height: 26)
            .padding(.horizontal, 4)
    }

    var body: some View {
        let m = model
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 3) {
                tool("arrow.clockwise", "reload") { m.reloadBoth(); m.flash("Neu eingelesen") }
                tool("arrow.left.arrow.right", "swap") { m.swapPanels() }
                tool("equal.square", "same") { m.sameDirInOther() }
                sep
                tool("checkmark.circle", "markall") { m.active.markAll() }
                tool("plus.circle", "markgroup") { m.markGroup(select: true) }
                tool("rectangle.split.2x1", "compare") { m.compareDirs() }
                sep
                tool("magnifyingglass", "search") { m.sheet = .search }
                tool("sum", "sizes") { m.computeAllSizes() }
                sep
                tool("square.and.arrow.down", "import") { m.importFiles() }
                tool("square.and.arrow.up", "share") { m.share() }
                tool("archivebox", "pack") { m.packSelection() }
                tool("archivebox.circle", "unpack") { m.unpackSelection() }
                sep
                tool("externaldrive.badge.plus", "addloc") { m.addLocationFromPicker() }
                tool(m.showHidden ? "eye" : "eye.slash", "hidden") { m.setShowHidden(!m.showHidden) }
                tool("paintpalette", "theme") { m.cycleTheme() }
                tool("gearshape", "settings") { m.sheet = .settings }
            }
            .padding(.horizontal, model.theme.classic ? 4 : 10)
            .padding(.vertical, 3)
        }
        .frame(height: 42)
        .overlay(alignment: .bottom) {
            if model.theme.classic {
                VStack(spacing: 0) {
                    Rectangle().fill(model.theme.shadow).frame(height: 1)
                    Rectangle().fill(Color.white).frame(height: 1)
                }
            }
        }
    }
}

// MARK: Funktionstasten

struct FunctionBar: View {
    let model: AppModel

    var body: some View {
        let t = model.theme
        let m = model
        let keys: [(String, String, () -> Void)] = [
            ("F2", "Umbenennen", { m.rename() }),
            ("F3", "Ansehen", { m.view() }),
            ("F4", "Bearbeiten", { m.edit() }),
            ("F5", "Kopieren", { m.copy() }),
            ("F6", "Verschieben", { m.move() }),
            ("F7", "Neuer Ordner", { m.newFolder() }),
            ("F8", "Löschen", { m.deleteSelection() }),
            ("F9", "Teilen", { m.share() })
        ]
        HStack(spacing: t.classic ? 2 : 6) {
            ForEach(keys, id: \.0) { k in
                Button(action: k.2) {
                    HStack(spacing: 4) {
                        Text(k.0).fontWeight(.bold)
                            .foregroundStyle(t.classic ? Color.black : t.accent2)
                        Text(k.1)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(PanelButtonStyle(theme: t, compact: true))
                .accessibilityIdentifier("fkey-" + k.0)
            }
        }
        .padding(.horizontal, t.classic ? 3 : 10)
        .padding(.top, 2)
        .padding(.bottom, 4)
    }
}
