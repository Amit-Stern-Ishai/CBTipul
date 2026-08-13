import SwiftUI
import UIKit

/// Native zoom-and-pan image viewing backed by `UIScrollView`: pinch zooms
/// around the fingers, panning has momentum and rubber-banding, and
/// double-tap zooms in at the tap point (or back out).
struct ZoomableImageView: UIViewRepresentable {
    let image: UIImage

    func makeUIView(context: Context) -> ImageScrollView {
        let scrollView = ImageScrollView()
        scrollView.delegate = context.coordinator
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.bouncesZoom = true
        scrollView.alwaysBounceVertical = false
        scrollView.alwaysBounceHorizontal = false
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.backgroundColor = .black

        let imageView = UIImageView(image: image)
        scrollView.addSubview(imageView)
        context.coordinator.imageView = imageView

        let doubleTap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleDoubleTap(_:))
        )
        doubleTap.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTap)

        scrollView.onLayout = { [weak coordinator = context.coordinator, weak scrollView] in
            guard let coordinator, let scrollView else { return }
            coordinator.configure(scrollView)
        }
        return scrollView
    }

    func updateUIView(_ scrollView: ImageScrollView, context: Context) {
        if context.coordinator.imageView?.image !== image {
            context.coordinator.imageView?.image = image
            context.coordinator.resetOnNextLayout()
            scrollView.setNeedsLayout()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    /// Scroll view that reports layout passes so zoom limits can follow the
    /// container size.
    final class ImageScrollView: UIScrollView {
        var onLayout: (() -> Void)?

        override func layoutSubviews() {
            super.layoutSubviews()
            onLayout?()
        }
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        var imageView: UIImageView?

        private var configuredBoundsSize: CGSize = .zero
        private var configuredImageSize: CGSize = .zero

        func resetOnNextLayout() {
            configuredBoundsSize = .zero
            configuredImageSize = .zero
        }

        /// Sets the zoom range so minimum = aspect fit, starting fitted.
        /// Re-runs only when the container or image actually changed.
        func configure(_ scrollView: UIScrollView) {
            guard let imageView, let image = imageView.image else { return }
            let boundsSize = scrollView.bounds.size
            guard boundsSize.width > 0, boundsSize.height > 0,
                  image.size.width > 0, image.size.height > 0 else { return }

            guard boundsSize != configuredBoundsSize || image.size != configuredImageSize else {
                centerContent(scrollView)
                return
            }
            configuredBoundsSize = boundsSize
            configuredImageSize = image.size

            imageView.frame = CGRect(origin: .zero, size: image.size)
            scrollView.contentSize = image.size

            let fitScale = min(boundsSize.width / image.size.width,
                               boundsSize.height / image.size.height)
            scrollView.minimumZoomScale = fitScale
            scrollView.maximumZoomScale = fitScale * 8
            scrollView.zoomScale = fitScale
            centerContent(scrollView)
        }

        /// Keeps the image centered while it is smaller than the viewport.
        private func centerContent(_ scrollView: UIScrollView) {
            let insetX = max((scrollView.bounds.width - scrollView.contentSize.width) / 2, 0)
            let insetY = max((scrollView.bounds.height - scrollView.contentSize.height) / 2, 0)
            scrollView.contentInset = UIEdgeInsets(top: insetY, left: insetX, bottom: insetY, right: insetX)
        }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            imageView
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            centerContent(scrollView)
        }

        @objc func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
            guard let scrollView = gesture.view as? UIScrollView, let imageView else { return }
            if scrollView.zoomScale > scrollView.minimumZoomScale * 1.01 {
                scrollView.setZoomScale(scrollView.minimumZoomScale, animated: true)
            } else {
                let point = gesture.location(in: imageView)
                let targetScale = scrollView.minimumZoomScale * 3
                let size = CGSize(width: scrollView.bounds.width / targetScale,
                                  height: scrollView.bounds.height / targetScale)
                let rect = CGRect(x: point.x - size.width / 2,
                                  y: point.y - size.height / 2,
                                  width: size.width,
                                  height: size.height)
                scrollView.zoom(to: rect, animated: true)
            }
        }
    }
}
