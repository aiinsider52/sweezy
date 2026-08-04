import SwiftUI
import UIKit

private struct InteractivePopGestureBridge: UIViewControllerRepresentable {
    let onFallbackDismiss: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onFallbackDismiss: onFallbackDismiss)
    }

    func makeUIViewController(context: Context) -> BridgeViewController {
        BridgeViewController(coordinator: context.coordinator)
    }

    func updateUIViewController(_ uiViewController: BridgeViewController, context: Context) {
        uiViewController.enableGestureWhenPossible()
    }

    static func dismantleUIViewController(_ uiViewController: BridgeViewController, coordinator: Coordinator) {
        coordinator.cleanUp()
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        weak var navigationController: UINavigationController?
        weak var fallbackHostView: UIView?
        private var fallbackGesture: UIScreenEdgePanGestureRecognizer?
        private let onFallbackDismiss: () -> Void

        init(onFallbackDismiss: @escaping () -> Void) {
            self.onFallbackDismiss = onFallbackDismiss
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            if gestureRecognizer === fallbackGesture { return true }
            guard let navigationController else { return false }
            return navigationController.viewControllers.count > 1
                && navigationController.transitionCoordinator == nil
        }

        func configure(from bridge: UIViewController) {
            if let navigationController = bridge.navigationController,
               navigationController.viewControllers.count > 1 {
                removeFallbackGesture()
                self.navigationController = navigationController
                navigationController.interactivePopGestureRecognizer?.delegate = self
                navigationController.interactivePopGestureRecognizer?.isEnabled = true
                return
            }

            navigationController = nil
            var host = bridge
            while let parent = host.parent { host = parent }
            guard host.presentingViewController != nil else {
                removeFallbackGesture()
                return
            }
            installFallbackGesture(on: host.view)
        }

        func cleanUp() {
            if navigationController?.interactivePopGestureRecognizer?.delegate === self {
                navigationController?.interactivePopGestureRecognizer?.delegate = nil
            }
            removeFallbackGesture()
        }

        private func installFallbackGesture(on view: UIView) {
            guard fallbackHostView !== view else { return }
            removeFallbackGesture()
            let gesture = UIScreenEdgePanGestureRecognizer(target: self, action: #selector(handleFallbackGesture(_:)))
            gesture.edges = .left
            gesture.cancelsTouchesInView = false
            gesture.delegate = self
            view.addGestureRecognizer(gesture)
            fallbackHostView = view
            fallbackGesture = gesture
        }

        private func removeFallbackGesture() {
            if let fallbackGesture {
                fallbackHostView?.removeGestureRecognizer(fallbackGesture)
            }
            fallbackGesture = nil
            fallbackHostView = nil
        }

        @objc private func handleFallbackGesture(_ gesture: UIScreenEdgePanGestureRecognizer) {
            guard gesture.state == .ended,
                  gesture.translation(in: gesture.view).x > 72,
                  gesture.velocity(in: gesture.view).x > 0 else { return }
            onFallbackDismiss()
        }
    }

    final class BridgeViewController: UIViewController {
        private let coordinator: Coordinator

        init(coordinator: Coordinator) {
            self.coordinator = coordinator
            super.init(nibName: nil, bundle: nil)
            view.isUserInteractionEnabled = false
            view.backgroundColor = .clear
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            enableGestureWhenPossible()
        }

        func enableGestureWhenPossible() {
            coordinator.configure(from: self)
        }
    }
}

extension View {
    /// Restores native navigation pop and adds leading-edge dismissal for presented screens.
    func interactiveSwipeBackEnabled(onFallbackDismiss: (() -> Void)? = nil) -> some View {
        modifier(InteractiveSwipeBackModifier(onFallbackDismiss: onFallbackDismiss))
    }
}

private struct InteractiveSwipeBackModifier: ViewModifier {
    @Environment(\.dismiss) private var dismiss
    let onFallbackDismiss: (() -> Void)?

    func body(content: Content) -> some View {
        content.background {
            InteractivePopGestureBridge {
                if let onFallbackDismiss {
                    onFallbackDismiss()
                } else {
                    dismiss()
                }
            }
                .frame(width: 0, height: 0)
                .accessibilityHidden(true)
        }
    }
}
