import SwiftUI
import UIKit

// MARK: - View Extension for Swipe-to-Go-Back Gesture
extension View {
    /// Enables swipe-to-go-back gesture even when the back button is hidden
    /// Use this when you have `.navigationBarBackButtonHidden(true)` with a custom back button
    func enableSwipeBackGesture() -> some View {
        self.background(
            SwipeBackGestureEnabler()
        )
    }
}

// MARK: - Swipe Back Gesture Enabler
private struct SwipeBackGestureEnabler: UIViewControllerRepresentable {

    func makeUIViewController(context: Context) -> UIViewController {
        SwipeBackViewController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // No update needed
    }

    private class SwipeBackViewController: UIViewController {
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)

            // Find the navigation controller and enable the interactive pop gesture
            if let navigationController = self.navigationController {
                navigationController.interactivePopGestureRecognizer?.isEnabled = true
                navigationController.interactivePopGestureRecognizer?.delegate = nil
            }
        }
    }
}
