import SwiftUI
import UIKit

/// A multiline notes field that shows the end of long text while idle.
/// SwiftUI's `TextField` cannot control its scroll position while unfocused,
/// so this wraps `UITextView`. Editing behaves like any text view — the
/// cursor lands wherever the user taps.
struct NotesField: UIViewRepresentable {
    @Binding var text: String
    let placeholder: String
    var minLines: Int = 3
    var maxLines: Int = 8

    /// Tracked so the field follows the in-app text size setting, which
    /// overrides the environment rather than the system content size.
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var font: UIFont {
        .preferredFont(
            forTextStyle: .body,
            compatibleWith: UITraitCollection(preferredContentSizeCategory: UIContentSizeCategory(dynamicTypeSize))
        )
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.delegate = context.coordinator
        view.font = font
        view.backgroundColor = .clear
        view.textContainerInset = .zero
        view.textContainer.lineFragmentPadding = 0

        let label = context.coordinator.placeholderLabel
        label.text = placeholder
        label.font = font
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
        if uiView.font != font {
            uiView.font = font
            context.coordinator.placeholderLabel.font = font
        }
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
    }
}

extension UIContentSizeCategory {
    /// Also used by the Settings text-size picker to preview each size.
    init(_ size: DynamicTypeSize) {
        switch size {
        case .xSmall: self = .extraSmall
        case .small: self = .small
        case .medium: self = .medium
        case .large: self = .large
        case .xLarge: self = .extraLarge
        case .xxLarge: self = .extraExtraLarge
        case .xxxLarge: self = .extraExtraExtraLarge
        case .accessibility1: self = .accessibilityMedium
        case .accessibility2: self = .accessibilityLarge
        case .accessibility3: self = .accessibilityExtraLarge
        case .accessibility4: self = .accessibilityExtraExtraLarge
        case .accessibility5: self = .accessibilityExtraExtraExtraLarge
        @unknown default: self = .large
        }
    }
}

