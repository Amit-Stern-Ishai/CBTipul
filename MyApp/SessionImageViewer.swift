import SwiftUI

/// Full-screen viewer for a session image with native pinch/pan zooming.
/// Editing: rotate left/right and crop, with Save; optionally AI text
/// extraction via `onTranscribed`.
struct SessionImageViewer: View {
    let image: UIImage
    /// Called with the edited image when the user saves changes.
    var onSave: (UIImage) -> Void
    /// When set, a transcribe button extracts the image's text via AI and
    /// hands it here (the viewer dismisses on success).
    var onTranscribed: ((String) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss

    @State private var workingImage: UIImage
    @State private var hasEdits = false
    @State private var isTranscribing = false
    @State private var transcriptionError: String?

    @State private var isCropping = false
    @State private var cropRect: CGRect = .zero
    /// The displayed (aspect-fitted) image frame in container coordinates.
    @State private var imageFrame: CGRect = .zero

    init(image: UIImage,
         onSave: @escaping (UIImage) -> Void,
         onTranscribed: ((String) -> Void)? = nil) {
        self.image = image
        self.onSave = onSave
        self.onTranscribed = onTranscribed
        _workingImage = State(initialValue: image)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if isCropping {
                    cropContent
                } else {
                    ZoomableImageView(image: workingImage)
                        .ignoresSafeArea(edges: .horizontal)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.cancel) { dismiss() }
                        .disabled(isCropping)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.save) {
                        onSave(workingImage)
                        dismiss()
                    }
                    .disabled(!hasEdits || isCropping)
                }
                ToolbarItemGroup(placement: .bottomBar) {
                    if isCropping {
                        Button {
                            isCropping = false
                        } label: {
                            Image(systemName: "xmark")
                        }
                        Spacer()
                        Button {
                            applyCrop()
                        } label: {
                            Image(systemName: "checkmark")
                        }
                    } else {
                        Button {
                            rotate(clockwise: false)
                        } label: {
                            Image(systemName: "rotate.left")
                        }
                        Spacer()
                        Button {
                            isCropping = true
                        } label: {
                            Image(systemName: "crop")
                        }
//                        if onTranscribed != nil {
//                            Spacer()
//                            if isTranscribing {
//                                ProgressView()
//                            } else {
//                                Button {
//                                    transcribeImage()
//                                } label: {
//                                    Image(systemName: "text.viewfinder")
//                                }
//                            }
//                        }
                        Spacer()
                        Button {
                            rotate(clockwise: true)
                        } label: {
                            Image(systemName: "rotate.right")
                        }
                        .disabled(isTranscribing)
                    }
                }
            }
            .toolbarBackground(.visible, for: .navigationBar, .bottomBar)
            .toolbarColorScheme(.dark, for: .navigationBar, .bottomBar)
            .overlay(alignment: .bottom) {
                if let transcriptionError {
                    Text(transcriptionError)
                        .font(.footnote)
                        .foregroundStyle(Theme.textBright)
                        .padding(10)
                        .background(.red.opacity(0.85), in: RoundedRectangle(cornerRadius: 10))
                        .padding()
                }
            }
        }
    }

    /// The fitted image with the adjustable crop box on top.
    private var cropContent: some View {
        GeometryReader { proxy in
            let frame = fittedFrame(for: workingImage.size, in: proxy.size)
            ZStack {
                Image(uiImage: workingImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: proxy.size.width, height: proxy.size.height)

                CropBox(rect: $cropRect, bounds: frame)
            }
            .onAppear {
                imageFrame = frame
                cropRect = frame
            }
            .onChange(of: frame) { _, newFrame in
                imageFrame = newFrame
                cropRect = newFrame
            }
        }
    }

    // MARK: - Editing

    private func rotate(clockwise: Bool) {
        workingImage = workingImage.rotated90(clockwise: clockwise) ?? workingImage
        hasEdits = true
    }

    /// Maps the crop box from view coordinates to image pixels and crops.
    private func applyCrop() {
        defer { isCropping = false }
        guard imageFrame.width > 0, imageFrame.height > 0,
              let cgImage = workingImage.cgImage else { return }

        let normalized = CGRect(
            x: (cropRect.minX - imageFrame.minX) / imageFrame.width,
            y: (cropRect.minY - imageFrame.minY) / imageFrame.height,
            width: cropRect.width / imageFrame.width,
            height: cropRect.height / imageFrame.height
        )
        let pixelRect = CGRect(
            x: normalized.minX * CGFloat(cgImage.width),
            y: normalized.minY * CGFloat(cgImage.height),
            width: normalized.width * CGFloat(cgImage.width),
            height: normalized.height * CGFloat(cgImage.height)
        ).integral

        guard let cropped = cgImage.cropping(to: pixelRect) else { return }
        workingImage = UIImage(cgImage: cropped, scale: workingImage.scale, orientation: .up)
        hasEdits = true
    }

    /// Sends the current image to the AI for text extraction and hands the
    /// result to the caller.
//    private func transcribeImage() {
//        guard let onTranscribed else { return }
//        transcriptionError = nil
//        isTranscribing = true
//        Task {
//            do {
//                guard let jpeg = workingImage.jpegData(compressionQuality: 0.8) else {
//                    throw OpenAIChatError.emptyResponse
//                }
//                let text = try await OpenAIChatService.extractText(fromJPEG: jpeg)
//                onTranscribed(text)
//                dismiss()
//            } catch {
//                transcriptionError = error.localizedDescription
//            }
//            isTranscribing = false
//        }
//    }

    /// The aspect-fitted frame of an image inside a container.
    private func fittedFrame(for imageSize: CGSize, in container: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0,
              container.width > 0, container.height > 0 else { return .zero }
        let fitScale = min(container.width / imageSize.width, container.height / imageSize.height)
        let size = CGSize(width: imageSize.width * fitScale, height: imageSize.height * fitScale)
        return CGRect(
            x: (container.width - size.width) / 2,
            y: (container.height - size.height) / 2,
            width: size.width,
            height: size.height
        )
    }
}

/// The adjustable crop rectangle: drag inside to move, drag a corner handle
/// to resize. The area outside the crop is dimmed and rule-of-thirds guides
/// are shown inside.
private struct CropBox: View {
    @Binding var rect: CGRect
    let bounds: CGRect

    private let minSize: CGFloat = 60

    @State private var dragStartRect: CGRect?

    private enum Corner: CaseIterable {
        case topLeft, topRight, bottomLeft, bottomRight
    }

    var body: some View {
        ZStack {
            // Dim everything inside the image except the crop area.
            Path { path in
                path.addRect(bounds)
                path.addRect(rect)
            }
            .fill(Color.black.opacity(0.55), style: FillStyle(eoFill: true))

            // Rule-of-thirds guides.
            Path { path in
                for fraction in [1.0 / 3.0, 2.0 / 3.0] {
                    let x = rect.minX + rect.width * fraction
                    path.move(to: CGPoint(x: x, y: rect.minY))
                    path.addLine(to: CGPoint(x: x, y: rect.maxY))
                    let y = rect.minY + rect.height * fraction
                    path.move(to: CGPoint(x: rect.minX, y: y))
                    path.addLine(to: CGPoint(x: rect.maxX, y: y))
                }
            }
            .stroke(.white.opacity(0.35), lineWidth: 0.7)

            Path { $0.addRect(rect) }
                .stroke(.white, lineWidth: 1.5)

            // Move the whole box.
            Rectangle()
                .fill(Color.clear)
                .contentShape(Rectangle())
                .frame(width: max(rect.width, 1), height: max(rect.height, 1))
                .position(x: rect.midX, y: rect.midY)
                .gesture(moveGesture)

            ForEach(Corner.allCases, id: \.self) { corner in
                Circle()
                    .fill(.white)
                    .frame(width: 16, height: 16)
                    .frame(width: 44, height: 44)
                    .contentShape(Circle())
                    .position(position(of: corner))
                    .gesture(resizeGesture(for: corner))
            }
        }
    }

    private func position(of corner: Corner) -> CGPoint {
        switch corner {
        case .topLeft: return CGPoint(x: rect.minX, y: rect.minY)
        case .topRight: return CGPoint(x: rect.maxX, y: rect.minY)
        case .bottomLeft: return CGPoint(x: rect.minX, y: rect.maxY)
        case .bottomRight: return CGPoint(x: rect.maxX, y: rect.maxY)
        }
    }

    private var moveGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if dragStartRect == nil { dragStartRect = rect }
                guard let start = dragStartRect else { return }
                var moved = start
                moved.origin.x = start.origin.x + value.translation.width
                moved.origin.y = start.origin.y + value.translation.height
                moved.origin.x = min(max(moved.origin.x, bounds.minX), bounds.maxX - moved.width)
                moved.origin.y = min(max(moved.origin.y, bounds.minY), bounds.maxY - moved.height)
                rect = moved
            }
            .onEnded { _ in dragStartRect = nil }
    }

    private func resizeGesture(for corner: Corner) -> some Gesture {
        DragGesture()
            .onChanged { value in
                if dragStartRect == nil { dragStartRect = rect }
                guard let start = dragStartRect else { return }

                var minX = start.minX
                var minY = start.minY
                var maxX = start.maxX
                var maxY = start.maxY

                switch corner {
                case .topLeft:
                    minX += value.translation.width
                    minY += value.translation.height
                case .topRight:
                    maxX += value.translation.width
                    minY += value.translation.height
                case .bottomLeft:
                    minX += value.translation.width
                    maxY += value.translation.height
                case .bottomRight:
                    maxX += value.translation.width
                    maxY += value.translation.height
                }

                // Keep inside the image and above the minimum size.
                minX = min(max(minX, bounds.minX), maxX - minSize)
                minY = min(max(minY, bounds.minY), maxY - minSize)
                maxX = max(min(maxX, bounds.maxX), minX + minSize)
                maxY = max(min(maxY, bounds.maxY), minY + minSize)

                rect = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
            }
            .onEnded { _ in dragStartRect = nil }
    }
}

private extension UIImage {
    /// The image rotated by 90 degrees, rendered upright.
    func rotated90(clockwise: Bool) -> UIImage? {
        let newSize = CGSize(width: size.height, height: size.width)
        return UIGraphicsImageRenderer(size: newSize).image { context in
            let cg = context.cgContext
            cg.translateBy(x: newSize.width / 2, y: newSize.height / 2)
            cg.rotate(by: (clockwise ? .pi : -.pi) / 2)
            draw(in: CGRect(x: -size.width / 2, y: -size.height / 2,
                            width: size.width, height: size.height))
        }
    }
}

#Preview {
    SessionImageViewer(image: UIImage(systemName: "photo")!) { _ in }
}
