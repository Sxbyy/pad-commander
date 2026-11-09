import SwiftUI
import UIKit

/// Legt Fortschritt und Dialoge ueber die Oberflaeche.
struct DialogLayer: View {
    let model: AppModel

    var body: some View {
        ZStack {
            if let busy = model.busy {
                Color.black.opacity(0.25).ignoresSafeArea()
                BusyDialog(model: model, busy: busy)
            }
            if let d = model.dialog {
                Color.black.opacity(model.theme.classic ? 0.15 : 0.45).ignoresSafeArea()
                    .onTapGesture { }
                dialogView(d)
                    .padding(16)
            }
        }
    }

    @ViewBuilder
    private func dialogView(_ d: Dialog) -> some View {
        switch d {
        case .input(let i): InputDialogView(model: model, dialog: i)
        case .confirm(let c): ConfirmDialogView(model: model, dialog: c)
        case .transfer(let tr): TransferDialogView(model: model, dialog: tr)
        case .conflict(let c): ConflictDialogView(model: model, dialog: c)
        case .message(let title, let text): MessageDialogView(model: model, title: title, text: text)
        case .properties(let p): PropertiesDialogView(model: model, info: p)
        }
    }
}

struct DialogFrame<Content: View>: View {
    let theme: Theme
    let title: String
    var width: CGFloat = 480
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(title)
                    .font(theme.font(15, weight: .bold))
                    .foregroundStyle(theme.classic ? theme.captionText : theme.faceText)
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, theme.classic ? 8 : 18)
            .frame(height: theme.classic ? 28 : 44)
            .background {
                if theme.classic { theme.captionGradient } else { Color.clear }
            }
            .padding(theme.classic ? 3 : 0)
            VStack(alignment: .leading, spacing: 12) {
                content()
            }
            .padding(.horizontal, theme.classic ? 14 : 18)
            .padding(.top, theme.classic ? 10 : 2)
            .padding(.bottom, theme.classic ? 14 : 18)
        }
        .frame(maxWidth: width)
        .background {
            if theme.classic {
                theme.face
            } else {
                Color(hex: 0x161B27)
            }
        }
        .bevel(theme, .raised, radius: theme.classic ? nil : 20)
        .background {
            RoundedRectangle(cornerRadius: theme.classic ? 0 : 20, style: .continuous)
                .fill(Color.black.opacity(theme.classic ? 0.35 : 0.6))
                .blur(radius: theme.classic ? 0 : 30)
                .offset(x: theme.classic ? 4 : 0, y: theme.classic ? 4 : 10)
        }
        .foregroundStyle(theme.faceText)
        .font(theme.font())
    }
}

struct DialogButtons: View {
    let theme: Theme
    let okTitle: String
    var destructive = false
    var okEnabled = true
    let ok: () -> Void
    let cancel: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Spacer()
            Button(action: ok) {
                Text(okTitle)
                    .foregroundStyle(destructive && !theme.classic ? Color(hex: 0xFF7A7A) : (theme.classic ? Color.black : Color.white))
                    .frame(minWidth: 90)
            }
            .buttonStyle(PanelButtonStyle(theme: theme, prominent: !destructive))
            .keyboardShortcut(.defaultAction)
            .disabled(!okEnabled)
            .accessibilityIdentifier("dialog-ok")
            Button(action: cancel) {
                Text("Abbrechen").frame(minWidth: 90)
            }
            .buttonStyle(PanelButtonStyle(theme: theme))
            .keyboardShortcut(.cancelAction)
            .accessibilityIdentifier("dialog-cancel")
        }
    }
}

/// Eingabefeld, das sofort den Fokus bekommt und den Namen ohne Endung markiert.
struct SelectingTextField: UIViewRepresentable {
    @Binding var text: String
    var selectBaseName = false
    var classic = true
    var identifier = "dialog-field"
    var onSubmit: () -> Void
    var onCancel: (() -> Void)? = nil

    func makeUIView(context: Context) -> UITextField {
        let tf = EscTextField()
        let coordinator = context.coordinator
        tf.onEscape = { [weak coordinator] in coordinator?.parent.onCancel?() }
        tf.text = text
        tf.font = UIFont.systemFont(ofSize: 16)
        tf.borderStyle = .none
        tf.autocorrectionType = .no
        tf.autocapitalizationType = .none
        tf.spellCheckingType = .no
        tf.smartQuotesType = .no
        tf.smartDashesType = .no
        tf.returnKeyType = .done
        tf.clearButtonMode = .whileEditing
        tf.accessibilityIdentifier = identifier
        tf.textColor = classic ? .black : .white
        tf.tintColor = classic ? UIColor(red: 0, green: 0, blue: 0.5, alpha: 1) : UIColor(red: 0.55, green: 0.48, blue: 1, alpha: 1)
        tf.delegate = context.coordinator
        tf.addTarget(context.coordinator, action: #selector(Coordinator.changed(_:)), for: .editingChanged)
        let select = selectBaseName
        DispatchQueue.main.async {
            tf.becomeFirstResponder()
            guard let t = tf.text, !t.isEmpty else { return }
            if select, let dot = t.lastIndex(of: "."), dot != t.startIndex {
                let n = t.distance(from: t.startIndex, to: dot)
                if let end = tf.position(from: tf.beginningOfDocument, offset: n) {
                    tf.selectedTextRange = tf.textRange(from: tf.beginningOfDocument, to: end)
                }
            } else {
                tf.selectAll(nil)
            }
        }
        return tf
    }

    func updateUIView(_ tf: UITextField, context: Context) {
        context.coordinator.parent = self
        if tf.text != text { tf.text = text }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: SelectingTextField
        init(_ p: SelectingTextField) { parent = p }

        @objc func changed(_ tf: UITextField) { parent.text = tf.text ?? "" }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            parent.text = textField.text ?? ""
            parent.onSubmit()
            return false
        }
    }
}

/// Textfeld, das Esc selbst behandelt (sonst schluckt UIKit die Taste).
final class EscTextField: UITextField {
    var onEscape: (() -> Void)?

    override var keyCommands: [UIKeyCommand]? {
        let esc = UIKeyCommand(input: UIKeyCommand.inputEscape, modifierFlags: [], action: #selector(escapePressed))
        esc.wantsPriorityOverSystemBehavior = true
        let dot = UIKeyCommand(input: ".", modifierFlags: .command, action: #selector(escapePressed))
        dot.wantsPriorityOverSystemBehavior = true
        return [esc, dot]
    }

    @objc func escapePressed() { onEscape?() }

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        if presses.contains(where: { $0.key?.keyCode == .keyboardEscape }) {
            onEscape?()
            return
        }
        super.pressesBegan(presses, with: event)
    }
}

struct FieldBox<Content: View>: View {
    let theme: Theme
    @ViewBuilder var content: () -> Content
    var body: some View {
        content()
            .padding(.horizontal, 6)
            .frame(height: 34)
            .background(theme.classic ? Color.white : Color.white.opacity(0.06))
            .bevel(theme, .field, radius: theme.classic ? nil : 10)
    }
}

// MARK: Eingabe

struct InputDialogView: View {
    let model: AppModel
    let dialog: InputDialog
    @State private var text: String

    init(model: AppModel, dialog: InputDialog) {
        self.model = model
        self.dialog = dialog
        _text = State(initialValue: dialog.text)
    }

    private func ok() {
        guard model.dialog != nil else { return }
        let value = text
        model.dialog = nil
        dialog.action(value)
    }

    var body: some View {
        let t = model.theme
        DialogFrame(theme: t, title: dialog.title) {
            Text(dialog.prompt)
            FieldBox(theme: t) {
                SelectingTextField(text: $text, selectBaseName: dialog.selectBaseName, classic: t.classic, onSubmit: ok, onCancel: { model.dialog = nil })
            }
            DialogButtons(theme: t, okTitle: dialog.okTitle, ok: ok, cancel: { model.dialog = nil })
        }
    }
}

// MARK: Bestaetigen / Meldung

struct ConfirmDialogView: View {
    let model: AppModel
    let dialog: ConfirmDialog

    var body: some View {
        let t = model.theme
        DialogFrame(theme: t, title: dialog.title) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: dialog.destructive ? "exclamationmark.triangle.fill" : "questionmark.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(dialog.destructive ? Color.orange : t.accent2)
                Text(dialog.message).fixedSize(horizontal: false, vertical: true)
            }
            DialogButtons(theme: t, okTitle: dialog.okTitle, destructive: dialog.destructive, ok: {
                guard model.dialog != nil else { return }
                model.dialog = nil
                dialog.action()
            }, cancel: { model.dialog = nil })
        }
    }
}

struct MessageDialogView: View {
    let model: AppModel
    let title: String
    let text: String

    var body: some View {
        let t = model.theme
        DialogFrame(theme: t, title: title) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "info.circle.fill").font(.system(size: 30)).foregroundStyle(t.accent2)
                Text(text).fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
            }
            HStack {
                Spacer()
                Button { model.dialog = nil } label: { Text("OK").frame(minWidth: 90) }
                    .buttonStyle(PanelButtonStyle(theme: t, prominent: true))
                    .keyboardShortcut(.defaultAction)
                    .accessibilityIdentifier("dialog-ok")
            }
        }
    }
}

// MARK: Kopieren / Verschieben

struct TransferDialogView: View {
    let model: AppModel
    let dialog: TransferDialog
    @State private var text: String
    @State private var policy: ConflictPolicy

    init(model: AppModel, dialog: TransferDialog) {
        self.model = model
        self.dialog = dialog
        _text = State(initialValue: dialog.targetText)
        _policy = State(initialValue: dialog.policy)
    }

    private var verb: String { dialog.op == .copy ? "Kopieren" : "Verschieben" }

    private var what: String {
        if dialog.sources.count == 1 { return "„\(dialog.sources[0].lastPathComponent)“" }
        return "\(dialog.sources.count) Dateien/Ordner"
    }

    private func ok() {
        guard model.dialog != nil else { return }
        var d = dialog
        d.targetText = text
        d.policy = policy
        model.startTransfer(d)
    }

    var body: some View {
        let t = model.theme
        let target = model.panel(dialog.targetSide)
        DialogFrame(theme: t, title: verb, width: 560) {
            Text("\(what) \(dialog.op == .copy ? "kopieren" : "verschieben") nach:")
            HStack(spacing: 6) {
                Text(target.location.name + ":")
                    .font(t.font(15, weight: .semibold))
                FieldBox(theme: t) {
                    SelectingTextField(text: $text, selectBaseName: false, classic: t.classic, onSubmit: ok, onCancel: { model.dialog = nil })
                }
            }
            HStack(spacing: 8) {
                Text("Wenn schon vorhanden:")
                Picker("Wenn schon vorhanden", selection: $policy) {
                    ForEach(ConflictPolicy.allCases) { p in Text(p.title).tag(p) }
                }
                .pickerStyle(.menu)
                .accessibilityIdentifier("policy")
            }
            Text("Tipp: Bei einer Datei kannst du hinten einen neuen Namen eintippen.")
                .font(t.font(12))
                .foregroundStyle(t.secondaryText)
            DialogButtons(theme: t, okTitle: verb, ok: ok, cancel: { model.dialog = nil })
        }
    }
}

// MARK: Konflikt

struct ConflictDialogView: View {
    let model: AppModel
    let dialog: ConflictDialog

    var body: some View {
        let t = model.theme
        DialogFrame(theme: t, title: "Datei existiert bereits", width: 560) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 30)).foregroundStyle(.orange)
                Text("„\(dialog.name)“ gibt es im Ziel schon. Was soll passieren?")
                    .fixedSize(horizontal: false, vertical: true)
            }
            let choices: [(String, ConflictChoice)] = [
                ("Überschreiben", .overwrite), ("Alle überschreiben", .overwriteAll),
                ("Überspringen", .skip), ("Alle überspringen", .skipAll),
                ("Umbenennen", .rename), ("Abbrechen", .cancel)
            ]
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(choices.indices, id: \.self) { i in
                    Button { dialog.resolve(choices[i].1) } label: {
                        Text(choices[i].0).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PanelButtonStyle(theme: t, prominent: i == 0))
                    .accessibilityIdentifier("conflict-\(i)")
                }
            }
        }
    }
}

// MARK: Eigenschaften

struct PropertiesDialogView: View {
    let model: AppModel
    let info: PropertiesInfo

    private func row(_ k: String, _ v: String) -> some View {
        HStack(alignment: .top) {
            Text(k).foregroundStyle(model.theme.secondaryText).frame(width: 110, alignment: .leading)
            Text(v).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    var body: some View {
        let t = model.theme
        let item = info.item
        DialogFrame(theme: t, title: "Eigenschaften", width: 560) {
            HStack(spacing: 12) {
                Image(systemName: item.symbol).font(.system(size: 34)).foregroundStyle(item.isDirectory ? t.folder : t.accent2)
                Text(item.name).font(t.font(17, weight: .bold)).lineLimit(2)
            }
            row("Ort", info.location + ":" + info.path)
            row("Art", item.isDirectory ? "Ordner" : (item.type?.localizedDescription ?? "Datei"))
            if let s = info.size {
                row("Größe", "\(Format.human(s))  (\(Format.bytes(s)) Bytes)")
            } else {
                row("Größe", "wird berechnet …")
            }
            if let n = info.itemCount { row("Inhalt", "\(n) Elemente") }
            if let c = info.created { row("Erstellt", Format.longDate.string(from: c)) }
            if let m = item.modified { row("Geändert", Format.longDate.string(from: m)) }
            if item.isHidden { row("Attribut", "versteckt") }
            HStack {
                Spacer()
                Button { model.dialog = nil } label: { Text("OK").frame(minWidth: 90) }
                    .buttonStyle(PanelButtonStyle(theme: t, prominent: true))
                    .keyboardShortcut(.defaultAction)
                    .accessibilityIdentifier("dialog-ok")
            }
        }
    }
}

// MARK: Fortschritt

struct BusyDialog: View {
    let model: AppModel
    let busy: BusyState

    var body: some View {
        let t = model.theme
        DialogFrame(theme: t, title: busy.progress.title, width: 520) {
            Text(busy.progress.detail.isEmpty ? "Bitte warten …" : busy.progress.detail)
                .lineLimit(2)
                .truncationMode(.middle)
            ProgressBar(theme: t, fraction: busy.progress.fraction)
            if let cancel = busy.cancel {
                HStack {
                    Spacer()
                    Button(action: cancel) { Text("Abbrechen").frame(minWidth: 90) }
                        .buttonStyle(PanelButtonStyle(theme: t))
                        .accessibilityIdentifier("busy-cancel")
                }
            }
        }
        .padding(16)
    }
}

/// Fortschrittsbalken: klassisch aus blauen Bloecken, sonst als Verlauf.
struct ProgressBar: View {
    let theme: Theme
    let fraction: Double?

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width - 6
            let f = CGFloat(min(max(fraction ?? 0, 0), 1))
            ZStack(alignment: .leading) {
                if theme.classic {
                    Color.white
                    if fraction != nil {
                        let block: CGFloat = 12
                        let count = Int((w * f) / (block + 2))
                        HStack(spacing: 2) {
                            ForEach(0..<max(count, 0), id: \.self) { _ in
                                Rectangle().fill(Color(hex: 0x000080)).frame(width: block)
                            }
                        }
                        .padding(3)
                    } else {
                        ProgressView().padding(.leading, 8)
                    }
                } else {
                    Color.white.opacity(0.06)
                    if fraction != nil {
                        LinearGradient(colors: [theme.accent, theme.accent2], startPoint: .leading, endPoint: .trailing)
                            .frame(width: max(8, w * f))
                            .clipShape(Capsule())
                            .padding(3)
                    } else {
                        ProgressView().padding(.leading, 8)
                    }
                }
            }
        }
        .frame(height: 26)
        .bevel(theme, .field, radius: theme.classic ? nil : 13)
    }
}
