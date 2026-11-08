import UIKit
import QuickLook
import UniformTypeIdentifiers

/// UIKit-Fenster: Vorschau (QuickLook), Teilen, Dateiauswahl.
@MainActor
enum Bridges {
    static weak var root: UIViewController?
    private static var keep: [NSObject] = []

    static func top() -> UIViewController? {
        var t = root
        while let p = t?.presentedViewController { t = p }
        return t
    }

    static func present(_ vc: UIViewController) {
        guard let top = top() else { return }
        if let pop = vc.popoverPresentationController {
            pop.sourceView = top.view
            pop.sourceRect = CGRect(x: top.view.bounds.midX, y: top.view.bounds.maxY - 60, width: 1, height: 1)
            pop.permittedArrowDirections = [.down]
        }
        top.present(vc, animated: true)
    }

    private static func retain(_ o: NSObject) { keep.append(o) }
    fileprivate static func drop(_ o: NSObject) { keep.removeAll { $0 === o } }

    static func showQuickLook(urls: [URL], index: Int, onDismiss: @escaping () -> Void) {
        let source = QLSource(urls: urls, onDismiss: onDismiss)
        retain(source)
        let ql = QLPreviewController()
        ql.dataSource = source
        ql.delegate = source
        ql.currentPreviewItemIndex = min(max(index, 0), max(urls.count - 1, 0))
        ql.modalPresentationStyle = .fullScreen
        present(ql)
    }

    static func share(_ urls: [URL]) {
        let vc = UIActivityViewController(activityItems: urls, applicationActivities: nil)
        present(vc)
    }

    static func pickFiles(_ done: @escaping ([URL]) -> Void) {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.item], asCopy: true)
        picker.allowsMultipleSelection = true
        let d = PickerDelegate { urls in done(urls) }
        retain(d)
        picker.delegate = d
        present(picker)
    }

    static func pickFolder(_ done: @escaping (URL?) -> Void) {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder], asCopy: false)
        picker.allowsMultipleSelection = false
        let d = PickerDelegate { urls in done(urls.first) }
        retain(d)
        picker.delegate = d
        present(picker)
    }
}

@MainActor
final class QLSource: NSObject, QLPreviewControllerDataSource, QLPreviewControllerDelegate {
    let urls: [URL]
    let onDismiss: () -> Void

    init(urls: [URL], onDismiss: @escaping () -> Void) {
        self.urls = urls
        self.onDismiss = onDismiss
    }

    func numberOfPreviewItems(in controller: QLPreviewController) -> Int { urls.count }

    func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
        urls[index] as NSURL
    }

    func previewController(_ controller: QLPreviewController, editingModeFor previewItem: QLPreviewItem) -> QLPreviewItemEditingMode {
        .updateContents
    }

    func previewControllerDidDismiss(_ controller: QLPreviewController) {
        onDismiss()
        Bridges.drop(self)
    }
}

@MainActor
final class PickerDelegate: NSObject, UIDocumentPickerDelegate {
    let done: ([URL]) -> Void

    init(done: @escaping ([URL]) -> Void) {
        self.done = done
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        done(urls)
        Bridges.drop(self)
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        done([])
        Bridges.drop(self)
    }
}
