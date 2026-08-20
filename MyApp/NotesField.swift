import SwiftUI
import UIKit

/// A multiline notes field that shows the end of long text while idle and
/// puts the cursor at the absolute end when the user taps into it.
/// SwiftUI's `TextField` can do neither (no scroll control while unfocused,
/// and a tap places the caret at the tap point), so this wraps `UITextView`.
struct NotesField: UIViewRepresentable {
    @Binding var text: String
    let placeholder: String
    var minLines: Int = 3
    var maxLines: Int = 8

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.delegate = context.coordinator
        view.font = .preferredFont(forTextStyle: .body)
        view.adjustsFontForContentSizeCategory = true
        view.backgroundColor = .clear
        view.textContainerInset = .zero
        view.textContainer.lineFragmentPadding = 0

        let label = context.coordinator.placeholderLabel
        label.text = placeholder
        label.font = view.font
        label.textColor = .placeholderText
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: view.topAnchor),
            label.leadingAnchor.constraint(equalTo: view.leadingAnchor),
        ])
        return view
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        context.coordinator.placeholderLabel.isHidden = !text.isEmpty
        guard uiView.text != text else { return }
        uiView.text = text
        // Idle fields show the latest notes, i.e. the end of the text.
        // Deferred so the jump happens after the new text is laid out.
        if !uiView.isFirstResponder {
            DispatchQueue.main.async {
                Self.jumpToEnd(uiView)
            }
        }
    }

    /// Positions the view at the end of the text instantly, no scroll animation.
    static func jumpToEnd(_ textView: UITextView) {
        textView.layoutIfNeeded()
        let offset = max(0, textView.contentSize.height - textView.bounds.height)
        UIView.performWithoutAnimation {
            textView.setContentOffset(CGPoint(x: 0, y: offset), animated: false)
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        guard let width = proposal.width, width.isFinite, width > 0 else { return nil }
        let fitting = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        let lineHeight = uiView.font?.lineHeight ?? 22
        let minHeight = ceil(lineHeight * CGFloat(minLines))
        let maxHeight = ceil(lineHeight * CGFloat(maxLines))
        return CGSize(width: width, height: min(max(fitting.height, minHeight), maxHeight))
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        let text: Binding<String>
        let placeholderLabel = UILabel()

        init(text: Binding<String>) {
            self.text = text
        }

        func textViewDidChange(_ textView: UITextView) {
            text.wrappedValue = textView.text
            placeholderLabel.isHidden = !textView.text.isEmpty
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            // Deferred so it wins over the caret position set by the tap.
            DispatchQueue.main.async {
                let end = textView.endOfDocument
                textView.selectedTextRange = textView.textRange(from: end, to: end)
                NotesField.jumpToEnd(textView)
            }
        }
    }
}
