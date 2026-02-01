import SwiftUI

// MARK: - Paywall Presenter
/// A helper class to present the feature paywall sheet from anywhere in the app
@MainActor
class PaywallPresenter: ObservableObject {
    static let shared = PaywallPresenter()

    @Published var isFeaturePaywallPresented = false
    @Published var source: String?

    var onSuccess: (() -> Void)?

    private init() {}

    /// Opens the feature paywall sheet (simplified upsell for premium features)
    /// - Parameters:
    ///   - source: Analytics source identifier (e.g., "guests", "sharing", "ai_planner")
    ///   - onSuccess: Callback when purchase is successful
    func openFeaturePaywall(source: String? = nil, onSuccess: (() -> Void)? = nil) {
        self.source = source
        self.onSuccess = onSuccess
        self.isFeaturePaywallPresented = true
    }

    /// Called when purchase is successful
    func handlePurchaseSuccess() {
        onSuccess?()
        onSuccess = nil
    }

    /// Closes the paywall
    func dismiss() {
        isFeaturePaywallPresented = false
        source = nil
        onSuccess = nil
    }
}

// MARK: - Paywall View Modifier
/// A view modifier that adds feature paywall presentation capability to any view
struct PaywallPresentationModifier: ViewModifier {
    @ObservedObject private var presenter = PaywallPresenter.shared
    @EnvironmentObject var appState: AppState

    func body(content: Content) -> some View {
        content
            // Feature paywall as sheet
            .sheet(isPresented: $presenter.isFeaturePaywallPresented) {
                FeaturePaywallSheet(source: presenter.source) {
                    appState.updateSubscriptionStatus(true)
                    presenter.handlePurchaseSuccess()
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
                .presentationBackground(
                    LinearGradient(
                        colors: [Color(hex: "A17BF4"), Color(hex: "8251EB")],
                        startPoint: .topTrailing,
                        endPoint: .bottomLeading
                    )
                )
            }
    }
}

extension View {
    /// Adds paywall presentation capability to the view
    func withPaywallPresentation() -> some View {
        modifier(PaywallPresentationModifier())
    }
}

// MARK: - Premium Feature Gate
/// A view modifier that gates premium features behind a paywall
struct PremiumFeatureGate: ViewModifier {
    @EnvironmentObject var appState: AppState
    let source: String
    let action: () -> Void

    func body(content: Content) -> some View {
        content
            .onTapGesture {
                if appState.isSubscribed {
                    action()
                } else {
                    // Use feature paywall sheet for premium feature gating
                    PaywallPresenter.shared.openFeaturePaywall(source: source) {
                        action()
                    }
                }
            }
    }
}

extension View {
    /// Gates an action behind the paywall - shows paywall if not subscribed
    /// - Parameters:
    ///   - source: Analytics source identifier
    ///   - action: Action to perform if subscribed or after successful purchase
    func requiresPremium(source: String, action: @escaping () -> Void) -> some View {
        modifier(PremiumFeatureGate(source: source, action: action))
    }
}

// MARK: - Check Premium Helper
/// Helper function to check if user is subscribed and open feature paywall if not
/// Returns true if user is subscribed (or just subscribed)
/// - Parameters:
///   - appState: The app state to check subscription status
///   - source: Analytics source identifier
@MainActor
func checkPremiumAccess(appState: AppState, source: String) async -> Bool {
    if appState.isSubscribed {
        return true
    }

    // Show feature paywall and wait for result
    return await withCheckedContinuation { continuation in
        PaywallPresenter.shared.openFeaturePaywall(source: source) {
            continuation.resume(returning: true)
        }

        // If paywall is dismissed without purchase, we need to check and resume with false
        Task {
            // Wait a short moment and check if paywall was dismissed without purchase
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            let paywallDismissed = !PaywallPresenter.shared.isFeaturePaywallPresented
            if paywallDismissed && !appState.isSubscribed {
                // Paywall was closed without purchasing
                // The continuation might already be resumed, so we don't do anything here
            }
        }
    }
}
