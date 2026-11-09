// SPDX-License-Identifier: GPL-2.0-or-later
import SwiftUI
import UIKit

// The iOS 15 support layer. Henge's app target deploys to iOS 15.0 (see
// project.yml), and the SwiftUI it was written against needs 16.0 and 17.0.
// Everything here stands in for one of those, so the call sites read as
// ordinary Henge code rather than as availability checks.
//
// What is deliberately NOT here:
//
//   * The JIT helper. HengeJITHelper keeps its 26.0 floor (Built-in StikJIT
//     needs it) and StikJIT keeps its 17.4 floor. Both are embedded in the app
//     and simply fail to load below their own floor -- a plugin above the
//     host's version is legal, pluginkit just never registers it. On iOS 15
//     there is no TXM, so the debugger-assisted path is not what gets JIT
//     there anyway.
//
//   * The external display scene. `UISceneSession.Role.windowExternalDisplayNonInteractive`
//     is iOS 16, but its raw value has been the same string since iOS 13, so
//     HengeAppDelegate compares rawValue instead of naming the constant.
//
// The one genuine behaviour loss is `NavigationLink(value:)` +
// `.navigationDestination(for:)`, which needs a path-based stack that only
// exists from iOS 16. `HengeNavStack` below replaces it; see the note there.

// MARK: - Navigation (iOS 16.0)

/// A stack of a root page and at most one pushed page.
///
/// `NavigationView(path:)` and `.navigationDestination(for:)` are both iOS 16,
/// and iOS 15's `NavigationView` has no path at all. Henge never stacks deeper
/// than one level -- a step opens the next page and Back returns to the list --
/// so the whole thing collapses to "the head of the path, or nothing", with
/// Back in the toolbar doing what the system's chevron did.
///
/// `path` stays a `[T]` rather than a `T?` so the call sites keep their one
/// shape: JITSetupFlow sets it from outside (a failed enable lands on the step
/// that can fix it), and this reads it as a binding.
struct HengeNavStack<T: Hashable, Root: View, Page: View>: View {
    @Binding private var path: [T]
    private let backTitle: String
    private let makeRoot: () -> Root
    private let makePage: (T) -> Page

    // Explicit rather than a memberwise initialiser, so the two closures are
    // unambiguously `@ViewBuilder` parameters. They are stored and called from
    // `body`, never built eagerly: `page` is handed the route only once there
    // is a route to hand it.
    init(path: Binding<[T]>, backTitle: String,
         @ViewBuilder root: @escaping () -> Root,
         @ViewBuilder page: @escaping (T) -> Page) {
        self._path = path
        self.backTitle = backTitle
        self.makeRoot = root
        self.makePage = page
    }

    var body: some View {
        NavigationView {
            Group {
                if let head = path.first {
                    makePage(head)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarLeading) {
                                Button(backTitle) { path.removeAll() }
                            }
                        }
                } else {
                    makeRoot()
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

// MARK: - LabeledContent (iOS 16.0)

/// Henge's `LabeledContent`: a label leading, its value trailing.
///
/// Deliberately NOT generic, and that is the whole point of the shape. The
/// constrained-extension version of this does not compile: a constrained
/// extension cannot make the solver substitute an unbound generic parameter,
/// so `Text` will not convert to an abstract `Label`. Two `AnyView` boxes and a
/// `StringProtocol` pair sidestep the whole problem: nothing is abstract, so
/// there is nothing to substitute. These rows are a label and a leaf value, so
/// the erasure costs nothing worth measuring.
struct HengeLabeledContent: View {
    private let label: AnyView
    private let value: AnyView

    init<S: StringProtocol, V: StringProtocol>(_ title: S, value: V) {
        self.label = AnyView(Text(title))
        self.value = AnyView(Text(value))
    }

    init<S: StringProtocol, V: View>(_ title: S, @ViewBuilder value: () -> V) {
        self.label = AnyView(Text(title))
        self.value = AnyView(value())
    }

    // `value` comes first, exactly as SwiftUI declares it: with more than one
    // trailing closure the first binds to the first parameter.
    init(@ViewBuilder value: () -> some View, @ViewBuilder label: () -> some View) {
        self.value = AnyView(value())
        self.label = AnyView(label())
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            label
                .frame(maxWidth: .infinity, alignment: .leading)
            value
                .multilineTextAlignment(.trailing)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - ShareLink (iOS 16.0)

/// `ShareLink(item:)`, built on the `ShareSheet` UIKit already provides.
///
/// Rendered as a plain `Button` so whatever `.buttonStyle` the caller chained
/// onto `ShareLink` keeps working.
struct HengeShareButton<Label: View>: View {
    let items: [Any]
    private let label: Label
    @State private var showing = false

    init(items: [Any], @ViewBuilder label: () -> Label) {
        self.items = items
        self.label = label()
    }

    var body: some View {
        Button { showing = true } label: { label }
            .sheet(isPresented: $showing) { ShareSheet(items: items) }
    }
}

/// The activity sheet `HengeShareButton` presents.
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Persistent system overlays (iOS 16.0)

extension View {
    /// `.persistentSystemOverlays(.hidden)`, which is iOS 16.
    ///
    /// A no-op, and it cannot be anything else below iOS 16. The home
    /// indicator's auto-hide is `UIViewController.prefersHomeIndicatorAutoHidden`,
    /// which is get-only: a controller overrides it, and nothing can assign it
    /// on another controller. A view modifier has no way to arrange that, so
    /// the home indicator stays visible over a running Mac on iOS 15. The
    /// status bar is `.statusBarHidden(...)`'s job and is unaffected.
    func hengePersistentOverlaysHidden() -> some View { self }
}

// MARK: - Scroll content background (iOS 16.0)

extension View {
    /// `.scrollContentBackground(.hidden)`, which is iOS 16. Below it the Form
    /// keeps the system background, and the page colour behind it does not
    /// show; the rows' own backgrounds still do.
    @ViewBuilder
    func hengeScrollContentBackgroundHidden() -> some View {
        if #available(iOS 16.0, *) {
            self.scrollContentBackground(.hidden)
        } else {
            self
        }
    }
}

// MARK: - File mover (iOS 16.0)

extension View {
    /// `.fileMover(isPresented:file:onCompletion:)`, which is iOS 16.
    ///
    /// Below it the same thing exists as `UIDocumentPickerViewController` in
    /// export mode, which is what `HengeFileMover` presents. Both move the file
    /// rather than copy it, so the exported Mac leaves Henge's folder.
    @ViewBuilder
    func hengeFileMover(isPresented: Binding<Bool>, file: URL?,
                        onCompletion: @escaping (Result<URL, Error>) -> Void) -> some View {
        if #available(iOS 16.0, *) {
            self.fileMover(isPresented: isPresented, file: file, onCompletion: onCompletion)
        } else {
            self.sheet(isPresented: isPresented) {
                if let file {
                    // The picker is the sheet, so it does not dismiss itself the
                    // way a presented one does; the sheet goes away here.
                    HengeFileMover(file: file, onCompletion: { result in
                        isPresented.wrappedValue = false
                        onCompletion(result)
                    }, onCancel: {
                        isPresented.wrappedValue = false
                    })
                }
            }
        }
    }
}

/// The iOS 15 stand-in for `.fileMover`: a Files picker in export (move) mode.
struct HengeFileMover: UIViewControllerRepresentable {
    let file: URL
    let onCompletion: (Result<URL, Error>) -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onCompletion: onCompletion, onCancel: onCancel)
    }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forExporting: [file], asCopy: false)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ picker: UIDocumentPickerViewController, context: Context) {}

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        private let onCompletion: (Result<URL, Error>) -> Void
        private let onCancel: () -> Void

        init(onCompletion: @escaping (Result<URL, Error>) -> Void, onCancel: @escaping () -> Void) {
            self.onCompletion = onCompletion
            self.onCancel = onCancel
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            if let url = urls.first { onCompletion(.success(url)) }
        }

        // Cancelling moves nothing, so `lastExport` stays and the row remains.
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) { onCancel() }
    }
}

// MARK: - Circular button border (iOS 17.0)

extension View {
    /// `.buttonBorderShape(.circle)`, whose `.circle` case is iOS 17. Below it
    /// the platform's default shape is kept; the paste button's frame is
    /// square, so the difference is only cosmetic.
    @ViewBuilder
    func hengeCircleBorder() -> some View {
        if #available(iOS 17.0, *) {
            self.buttonBorderShape(.circle)
        } else {
            self
        }
    }
}
