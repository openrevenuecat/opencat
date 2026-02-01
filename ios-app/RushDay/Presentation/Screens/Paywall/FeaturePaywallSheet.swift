import SwiftUI

// MARK: - Feature Paywall ViewModel
@MainActor
class FeaturePaywallViewModel: ObservableObject {
    @Published var packages: [SubscriptionPackage] = []
    @Published var selectedPackage: SubscriptionPackage?
    @Published var isLoading = false
    @Published var isPurchasing = false
    @Published var error: String?
    @Published var showError = false

    private let revenueCatService: RevenueCatServiceProtocol
    private let analyticsService = AnalyticsService.shared
    private let source: String?

    var annualPackage: SubscriptionPackage? {
        packages.first { $0.packageType == .annual }
    }

    var trialDays: Int {
        selectedPackage?.freeTrialDays ?? 7
    }

    init(source: String? = nil) {
        self.revenueCatService = DIContainer.shared.revenueCatService
        self.source = source
    }

    func loadOfferings() async {
        isLoading = true
        defer { isLoading = false }

        // Log paywall view
        analyticsService.logPaywallView(source: source)

        do {
            packages = try await revenueCatService.getOfferings()
            // Select annual by default (feature paywall always promotes annual)
            selectedPackage = annualPackage ?? packages.first
        } catch {
            self.error = error.localizedDescription
            showError = true
        }
    }

    func purchase() async -> Bool {
        guard let package = selectedPackage else { return false }

        isPurchasing = true
        defer { isPurchasing = false }

        do {
            let status = try await revenueCatService.purchase(package: package)

            // Log analytics (Firebase)
            if package.hasFreeTrial {
                analyticsService.logTrialStart(
                    packageType: package.packageType.stringValue,
                    productId: package.storeProduct.productIdentifier
                )
                // Log to AppsFlyer
                AppsFlyerService.shared.logTrialStart(
                    productId: package.storeProduct.productIdentifier
                )
            } else {
                analyticsService.logSubscriptionPurchase(
                    packageType: package.packageType.stringValue,
                    productId: package.storeProduct.productIdentifier,
                    price: package.storeProduct.price as Decimal,
                    currency: package.storeProduct.currencyCode ?? "USD"
                )
                // Log to AppsFlyer
                AppsFlyerService.shared.logSubscriptionPurchase(
                    productId: package.storeProduct.productIdentifier,
                    price: package.storeProduct.price as Decimal,
                    currency: package.storeProduct.currencyCode ?? "USD"
                )
            }

            return status.isActive
        } catch RevenueCatError.purchaseCancelled {
            return false
        } catch {
            self.error = error.localizedDescription
            showError = true
            return false
        }
    }

    func restorePurchases() async -> Bool {
        isLoading = true
        defer { isLoading = false }

        do {
            let status = try await revenueCatService.restorePurchases()
            return status.isActive
        } catch RevenueCatError.noActiveSubscription {
            self.error = L10n.noActiveSubscription
            showError = true
            return false
        } catch {
            self.error = error.localizedDescription
            showError = true
            return false
        }
    }
}

// MARK: - Feature Paywall Sheet
struct FeaturePaywallSheet: View {
    @StateObject private var viewModel: FeaturePaywallViewModel
    @Environment(\.dismiss) private var dismiss

    let source: String?
    var onPurchaseSuccess: (() -> Void)?

    init(
        source: String? = nil,
        onPurchaseSuccess: (() -> Void)? = nil
    ) {
        self.source = source
        self.onPurchaseSuccess = onPurchaseSuccess
        _viewModel = StateObject(wrappedValue: FeaturePaywallViewModel(source: source))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Content - Figma: VStack with gap-24px, px-24px, vertically centered
                VStack(spacing: 24) {
                    // Title Section
                    FeaturePaywallTitleSection()

                    // Subtitle
                    FeaturePaywallSubtitleSection()

                    // Feature Cards - Figma: gap-8px between cards
                    FeatureCardsSection()

                    // Promo Text
                    FeaturePromoSection(
                        price: viewModel.annualPackage?.storeProduct.price,
                        currencyCode: viewModel.annualPackage?.storeProduct.currencyCode
                    )

                    // Button Section - Figma: gap-[12px] pb-[16px]
                    VStack(spacing: 12) {
                        // Purchase button
                        FeaturePurchaseButton(viewModel: viewModel) {
                            await handlePurchase()
                        }

                        // Privacy & Terms
                        PrivacyTermsSection()

                        // Restore button
                        RestoreButton {
                            await handleRestore()
                        }
                    }
                    .padding(.bottom, 16)
                }
                .padding(.horizontal, 24)
                .frame(maxHeight: .infinity)

                // Loading overlay
                if viewModel.isPurchasing {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                }
            }
            .background(
                ZStack {
                    // Purple gradient background matching PaywallScreen
                    LinearGradient(
                        colors: [Color(hex: "A17BF4"), Color(hex: "8251EB")],
                        startPoint: .topTrailing,
                        endPoint: .bottomLeading
                    )

                    // Decorative floating checkmarks from Figma
                    FeaturePaywallDecorations()
                }
                .ignoresSafeArea()
            )
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.black)
                    }
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .task {
            await viewModel.loadOfferings()
        }
        .alert(L10n.error, isPresented: $viewModel.showError) {
            Button(L10n.ok, role: .cancel) {}
        } message: {
            Text(viewModel.error ?? L10n.error)
        }
    }

    private func handlePurchase() async {
        let success = await viewModel.purchase()
        if success {
            onPurchaseSuccess?()
            dismiss()
        }
    }

    private func handleRestore() async {
        let success = await viewModel.restorePurchases()
        if success {
            onPurchaseSuccess?()
            dismiss()
        }
    }
}


// MARK: - Feature Paywall Title Section
struct FeaturePaywallTitleSection: View {
    var body: some View {
        Text(L10n.featurePaywallTitle)
            .font(.system(size: 34, weight: .bold, design: .rounded))
            .tracking(0.4)
            .lineSpacing(2) // Tighter spacing between title lines
            .foregroundColor(.white)
            .multilineTextAlignment(.center)
    }
}

// MARK: - Feature Paywall Subtitle Section
struct FeaturePaywallSubtitleSection: View {
    var body: some View {
        Text(L10n.featurePaywallSubtitle)
            .font(.system(size: 20, weight: .medium))
            .tracking(-0.24)
            .lineSpacing(5) // Figma: leading-[25px] for 20px font = 5px extra
            .foregroundColor(.white)
            .multilineTextAlignment(.center)
            .textCase(.none) // Figma shows capitalize but localized string already handles it
    }
}

// MARK: - Feature Cards Section
struct FeatureCardsSection: View {
    private let features: [(key: String, icon: String)] = [
        ("featureTaskLists", "star.fill"),
        ("featureAutoScheduling", "star.fill"),
        ("featureBudgetTracking", "star.fill"),
        ("featureTeamSharing", "star.fill")
    ]

    var body: some View {
        VStack(spacing: 8) {
            ForEach(features, id: \.key) { feature in
                FeatureCard(
                    title: getLocalizedTitle(for: feature.key),
                    icon: feature.icon
                )
            }
        }
    }

    private func getLocalizedTitle(for key: String) -> String {
        switch key {
        case "featureTaskLists": return L10n.featureTaskLists
        case "featureAutoScheduling": return L10n.featureAutoScheduling
        case "featureBudgetTracking": return L10n.featureBudgetTracking
        case "featureTeamSharing": return L10n.featureTeamSharing
        default: return ""
        }
    }
}

// MARK: - Feature Card
struct FeatureCard: View {
    let title: String
    let icon: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(Color.rdSuccess)

            Text(title)
                .font(.system(size: 17, weight: .medium))
                .tracking(-0.44)
                .foregroundColor(Color(hex: "0D1017"))

            Spacer()
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Feature Promo Section
struct FeaturePromoSection: View {
    let price: Decimal?
    let currencyCode: String?

    private var formattedPrice: String {
        guard let price = price else {
            return "$29.99" // Fallback
        }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode ?? "USD"
        formatter.maximumFractionDigits = 2
        return formatter.string(from: price as NSDecimalNumber) ?? "$\(price)"
    }

    private var priceText: String {
        "Just \(formattedPrice)/Year"
    }

    var body: some View {
        // Figma: Single text with line break, 20px medium, leading-25px, tracking -0.24px
        Text("\(L10n.featurePromoTitle)\n\(priceText)")
            .font(.system(size: 20, weight: .medium))
            .tracking(-0.24)
            .lineSpacing(5) // Figma: leading-[25px] for 20px = 5px extra
            .foregroundColor(.white)
            .multilineTextAlignment(.center)
    }
}

// MARK: - Feature Purchase Button
struct FeaturePurchaseButton: View {
    @ObservedObject var viewModel: FeaturePaywallViewModel
    let onPurchase: () async -> Void

    private var buttonText: String {
        L10n.startYourFreeTrial(viewModel.trialDays)
    }

    var body: some View {
        Button {
            Task {
                await onPurchase()
            }
        } label: {
            VStack(spacing: 2) {
                Text(buttonText)
                    .font(.system(size: 17, weight: .bold))
                    .tracking(-0.23)

                Text(L10n.cancelAnytime)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background(Color.rdSuccess)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .shadow(color: Color(red: 23/255, green: 15/255, blue: 13/255).opacity(0.08), radius: 9, x: 0, y: 12)
            .shadow(color: Color(red: 23/255, green: 15/255, blue: 13/255).opacity(0.04), radius: 4, x: 0, y: 4)
        }
        .disabled(viewModel.selectedPackage == nil || viewModel.isPurchasing)
    }
}

// MARK: - Feature Paywall Decorations
struct FeaturePaywallDecorations: View {
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height

            // Figma modal content: 393x770 (starts at y=82 of 852 total)
            // Adjust Y positions: (figmaY - 82) / 770

            // Left decoration - Figma: left:-48, top:394, size:229x179
            // Positioned to show ~75% of decoration on screen
            Image("paywall_decoration_left")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: width * 0.58)
                .rotationEffect(.degrees(16.4))
                .position(x: width * 0.12, y: height * 0.54)

            // Right decoration - Figma: left:196, top:124, size:195x201
            // Using left decoration mirrored as fallback (right asset was corrupted)
            Image("paywall_decoration_left")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: width * 0.50)
                .rotationEffect(.degrees(-15))
                .scaleEffect(x: -1, y: 1) // Mirror horizontally
                .position(x: width * 0.78, y: height * 0.22)

            // Floating stars - adjusted Y positions
            // Star 1: Figma top:111 -> (111-82)/770 = 3.8%
            FloatingStar(size: 36, rotation: 12.6, opacity: 0.20)
                .position(x: width * 0.27, y: height * 0.06)

            // Star 2: Figma top:147 -> (147-82)/770 = 8.4%
            FloatingStar(size: 36, rotation: -25.2, opacity: 0.20)
                .position(x: width * 0.81, y: height * 0.11)

            // Star 3: Figma top:208 -> (208-82)/770 = 16.4%
            FloatingStar(size: 36, rotation: 13, opacity: 0.05)
                .position(x: width * 0.15, y: height * 0.16)

            // Star 4: Figma top:247 -> (247-82)/770 = 21.4%
            FloatingStar(size: 36, rotation: -14.5, opacity: 0.30)
                .position(x: width * 0.37, y: height * 0.24)

            // Star 5: Figma top:743 -> (743-82)/770 = 85.8%
            FloatingStar(size: 36, rotation: 13.5, opacity: 0.05)
                .position(x: width * 0.13, y: height * 0.86)

            // Star 6: Figma top:768 -> (768-82)/770 = 89%
            FloatingStar(size: 36, rotation: -22, opacity: 0.05)
                .position(x: width * 0.81, y: height * 0.89)

            // Party popper - Figma: center at (311.5, 639.5)
            // Adjusted Y: (639.5-82)/770 = 72.4%
            Image("paywall_party_popper")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: width * 0.41, height: width * 0.40)
                .rotationEffect(.degrees(-13.6))
                .position(x: width * 0.79, y: height * 0.72)
        }
    }
}

// MARK: - Floating Star
struct FloatingStar: View {
    let size: CGFloat
    let rotation: Double
    let opacity: Double

    var body: some View {
        Image(systemName: "star.fill")
            .font(.system(size: size, weight: .medium))
            .foregroundColor(Color.rdPrimaryLight)
            .opacity(opacity)
            .rotationEffect(.degrees(rotation))
            .blur(radius: 2)
    }
}

// MARK: - Preview
#Preview {
    FeaturePaywallSheet()
}
