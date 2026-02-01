import SwiftUI

// MARK: - Paywall ViewModel
@MainActor
class PaywallViewModel: ObservableObject {
    @Published var packages: [SubscriptionPackage] = []
    @Published var selectedPackage: SubscriptionPackage?
    @Published var isLoading = false
    @Published var isPurchasing = false
    @Published var error: String?
    @Published var showError = false

    private let revenueCatService: RevenueCatServiceProtocol
    private let analyticsService = AnalyticsService.shared
    private let source: String?

    // Features list
    var features: [PaywallFeature] {
        [
            PaywallFeature(title: L10n.manualPlanning, isFree: true, isPremium: true),
            PaywallFeature(title: L10n.unlimitedEvents, isFree: false, isPremium: true),
            PaywallFeature(title: L10n.aiTaskGeneration, isFree: false, isPremium: true),
            PaywallFeature(title: L10n.agendaBuilder, isFree: false, isPremium: true),
            PaywallFeature(title: L10n.expenseTracker, isFree: false, isPremium: true),
            PaywallFeature(title: L10n.shareEvents, isFree: false, isPremium: true),
            PaywallFeature(title: L10n.inviteGuestsFeature, isFree: false, isPremium: true),
        ]
    }

    var annualPackage: SubscriptionPackage? {
        packages.first { $0.packageType == .annual }
    }

    var monthlyPackage: SubscriptionPackage? {
        packages.first { $0.packageType == .monthly }
    }

    var annualSavingsPercent: Int {
        guard let annual = annualPackage, let monthly = monthlyPackage else { return 0 }
        let annualMonthlyPrice = (annual.storeProduct.price as Decimal) / 12
        let monthlyCost = monthly.storeProduct.price as Decimal
        if monthlyCost == 0 { return 0 }
        let savings = ((monthlyCost - annualMonthlyPrice) / monthlyCost) * 100
        return Int(truncating: savings as NSDecimalNumber)
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
            // Select annual by default
            selectedPackage = annualPackage ?? packages.first
        } catch {
            self.error = error.localizedDescription
            showError = true
        }
    }

    func selectPackage(_ package: SubscriptionPackage) {
        selectedPackage = package
        analyticsService.logPaywallPackageSelected(
            packageType: package.packageType.stringValue,
            productId: package.storeProduct.productIdentifier
        )
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
            // User cancelled, don't show error
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

// MARK: - Paywall Feature Model
struct PaywallFeature: Identifiable {
    let id = UUID()
    let title: String
    let isFree: Bool
    let isPremium: Bool
}

// MARK: - Paywall Screen
struct PaywallScreen: View {
    @StateObject private var viewModel: PaywallViewModel
    @Environment(\.dismiss) private var dismiss

    var onPurchaseSuccess: (() -> Void)?

    init(
        source: String? = nil,
        onPurchaseSuccess: (() -> Void)? = nil
    ) {
        self.onPurchaseSuccess = onPurchaseSuccess
        _viewModel = StateObject(wrappedValue: PaywallViewModel(source: source))
    }

    var body: some View {
        ZStack {
            // Background image
            PaywallBackground()

            // Content - fills screen with button pinned to bottom
            VStack(spacing: 0) {
                // Title - Figma: pl-[24px] pr-[16px]
                PaywallTitle()
                    .padding(.top, 98)
                    .padding(.leading, 24)
                    .padding(.trailing, 16)

                // Features comparison
                FeaturesSection(features: viewModel.features)
                    .padding(.top, 16)
                    .padding(.horizontal, 24)

                // Offers - Figma: main container gap-[16px]
                OffersSection(viewModel: viewModel)
                    .padding(.top, 24)
                    .padding(.horizontal, 24)

                // Flexible spacer pushes button section to bottom
                Spacer()

                // Bottom section - button, terms, restore
                VStack(spacing: 8) {
                    // Purchase button
                    PurchaseButton(viewModel: viewModel) {
                        await handlePurchase()
                    }

                    // Privacy & Terms
                    PrivacyTermsSection()

                    // Restore button
                    RestoreButton {
                        await handleRestore()
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 34)
            }

            // Back button (simple chevron)
            VStack {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .padding(.leading, 8)

                    Spacer()
                }
                .padding(.top, 50)
                Spacer()
            }

            // Loading overlay
            if viewModel.isPurchasing {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
            }
        }
        .ignoresSafeArea(edges: .top)
        .navigationBarBackButtonHidden(true)
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

// MARK: - Paywall Background
struct PaywallBackground: View {
    var body: some View {
        Image("paywall_screen_bg")
            .resizable()
            .aspectRatio(contentMode: .fill)
            .ignoresSafeArea()
    }
}

// MARK: - Paywall Title
struct PaywallTitle: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(L10n.unlockMoreWith)
                .font(.system(size: 34, weight: .semibold, design: .rounded))
                .tracking(0.4)
            HStack(spacing: 0) {
                Text(L10n.rushDayPro)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .tracking(0.4)
                Text("!")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .tracking(0.4)
            }
        }
        .foregroundColor(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Features Section
struct FeaturesSection: View {
    let features: [PaywallFeature]

    // Figma specs
    private let iconSize: CGFloat = 20
    private let labelsGap: CGFloat = 20    // gap-[20px] for labels
    private let iconsGap: CGFloat = 32     // gap-[32px] for icons
    private let iconsPadding: CGFloat = 8  // px-[32px] - 24px external = 8px

    var body: some View {
        ZStack(alignment: .leading) {
            // Pro column highlight - 47px wide, ONLY behind Pro checkboxes
            // Position: 8px padding + 20px Free icon + 32px gap - 13.5px (to center 47px on 20px icon)
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.19))
                .frame(width: 47)
                .padding(.top, 12)
                .padding(.bottom, 4)
                .offset(x: 8 + iconSize + iconsGap - 13.5, y: -8) // Trim from top (8) and bottom

            VStack(alignment: .leading, spacing: 16) {
                // Labels row - Figma: gap-[20px]
                HStack(spacing: labelsGap) {
                    Text(L10n.free)
                        .font(.system(size: 17, weight: .semibold))
                        .tracking(-0.44)
                        .foregroundColor(.white)

                    Text(L10n.pro)
                        .font(.system(size: 17, weight: .semibold))
                        .tracking(-0.44)
                        .foregroundColor(.white)

                    Spacer()
                }

                // Features list
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(features) { feature in
                        HStack(alignment: .top, spacing: iconsGap) {
                            // Free status icon
                            FeatureStatusIcon(isAvailable: feature.isFree)
                                .frame(width: iconSize)

                            // Pro status icon
                            FeatureStatusIcon(isAvailable: feature.isPremium)
                                .frame(width: iconSize)

                            // Feature title
                            Text(feature.title)
                                .font(.system(size: 17, weight: .medium))
                                .tracking(-0.44)
                                .foregroundColor(.white)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(.leading, 8)
            }
            .padding(.top, 8)
            .padding(.bottom, 4)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Feature Status Icon
struct FeatureStatusIcon: View {
    let isAvailable: Bool

    var body: some View {
        Image(systemName: isAvailable ? "checkmark.circle.fill" : "xmark.circle")
            .font(.system(size: 20))
            .foregroundColor(.white)
    }
}

// MARK: - Offers Section
struct OffersSection: View {
    @ObservedObject var viewModel: PaywallViewModel

    var body: some View {
        VStack(spacing: 16) {
            // Annual offer
            if let annual = viewModel.annualPackage {
                OfferCard(
                    package: annual,
                    isSelected: viewModel.selectedPackage?.identifier == annual.identifier,
                    discountPercent: viewModel.annualSavingsPercent
                ) {
                    viewModel.selectPackage(annual)
                }
            }

            // Monthly offer
            if let monthly = viewModel.monthlyPackage {
                OfferCard(
                    package: monthly,
                    isSelected: viewModel.selectedPackage?.identifier == monthly.identifier
                ) {
                    viewModel.selectPackage(monthly)
                }
            }
        }
    }
}

// MARK: - Offer Card
struct OfferCard: View {
    let package: SubscriptionPackage
    let isSelected: Bool
    var discountPercent: Int = 0
    let onTap: () -> Void

    private var title: String {
        switch package.packageType {
        case .annual: return L10n.annual
        case .monthly: return L10n.monthly
        default: return package.storeProduct.localizedTitle
        }
    }

    private var yearlyPriceText: String {
        formatPrice(package.storeProduct.price) + "/yr"
    }

    private var monthlyPriceText: String {
        if package.packageType == .annual {
            let monthlyPrice = (package.storeProduct.price as Decimal) / 12
            return formatPrice(monthlyPrice) + "/mo"
        }
        return formatPrice(package.storeProduct.price) + "/mo"
    }

    private func formatPrice(_ price: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "$"
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return formatter.string(from: price as NSDecimalNumber) ?? "$\(price)"
    }

    private var trialDays: Int {
        package.freeTrialDays
    }

    // Colors - always white cards on purple gradient background
    private var cardBackground: Color {
        isSelected ? Color.white : Color.white.opacity(0.5)
    }

    private var cardTextColor: Color {
        isSelected ? Color(hex: "0D1017") : .white
    }

    private var secondaryTextColor: Color {
        isSelected ? Color(hex: "9E9EAA") : .white.opacity(0.7)
    }

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 8) {
                    // Title row
                    HStack {
                        HStack(spacing: 8) {
                            Text(title)
                                .font(.system(size: 20, weight: .medium))
                                .tracking(-0.24)

                            if package.packageType == .annual {
                                Text(yearlyPriceText)
                                    .font(.system(size: 17, weight: .medium))
                                    .tracking(-0.44)
                                    .foregroundColor(secondaryTextColor)
                            }
                        }

                        Spacer()

                        // Checkbox
                        OfferCheckbox(isSelected: isSelected)
                    }

                    // Description row
                    HStack {
                        if package.hasFreeTrial {
                            Text(L10n.tryFreeForDays(trialDays))
                                .font(.system(size: 17, weight: .medium))
                                .tracking(-0.44)
                        }

                        Spacer()

                        Text(monthlyPriceText)
                            .font(.system(size: 17, weight: .medium))
                            .tracking(-0.44)
                    }
                }
                .padding(16)
                .foregroundColor(cardTextColor)
                .background(cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(isSelected ? Color.clear : Color.rdPrimaryLight, lineWidth: 1)
                )

                // Discount badge
                if discountPercent > 0 {
                    Text(L10n.discount(discountPercent))
                        .font(.system(size: 15, weight: .medium))
                        .tracking(-0.23)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.rdSuccess)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .shadow(color: Color.black.opacity(0.25), radius: 2, x: 0, y: 4)
                        .offset(x: -40, y: -12)
                }
            }
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.3), value: isSelected)
    }
}

// MARK: - Offer Checkbox
struct OfferCheckbox: View {
    let isSelected: Bool

    var body: some View {
        ZStack {
            // Outer border circle
            Circle()
                .stroke(Color.rdPrimaryLight, lineWidth: 1)
                .frame(width: 24, height: 24)

            if isSelected {
                // Checkmark icon inside - always purple on white card
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(Color.rdPrimary)
            }
        }
    }
}

// MARK: - Purchase Button
struct PurchaseButton: View {
    @ObservedObject var viewModel: PaywallViewModel
    let onPurchase: () async -> Void

    private var buttonText: String {
        guard let package = viewModel.selectedPackage else {
            return L10n.subscribe
        }

        if package.hasFreeTrial {
            let days = package.freeTrialDays
            return L10n.startYourFreeTrial(days)
        }
        return L10n.subscribe
    }

    var body: some View {
        Button {
            Task {
                await onPurchase()
            }
        } label: {
            VStack(spacing: 2) {
                Text(buttonText)
                    .font(.system(size: 15, weight: .semibold))
                    .tracking(-0.23)

                Text(L10n.cancelAnytime)
                    .font(.system(size: 13, weight: .medium))
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

// MARK: - Privacy Terms Section
struct PrivacyTermsSection: View {
    @Environment(\.openURL) private var openURL

    private let termsURL = URL(string: "https://rush-day.io/terms-of-service")!
    private let privacyURL = URL(string: "https://rush-day.io/privacy-policy")!

    var body: some View {
        VStack(spacing: 2) {
            Text(L10n.byContinuingAgree)
                .font(.system(size: 11))
                .tracking(0.066)
                .foregroundColor(.white.opacity(0.78))

            HStack(spacing: 4) {
                Button {
                    openURL(termsURL)
                } label: {
                    Text(L10n.termsOfService)
                        .underline()
                }

                Text(L10n.and)

                Button {
                    openURL(privacyURL)
                } label: {
                    Text(L10n.privacyPolicy)
                        .underline()
                }
            }
            .font(.system(size: 11))
            .tracking(0.066)
            .foregroundColor(.white.opacity(0.78))
        }
    }
}

// MARK: - Restore Button
struct RestoreButton: View {
    let onRestore: () async -> Void

    var body: some View {
        Button {
            Task {
                await onRestore()
            }
        } label: {
            Text(L10n.restorePurchase)
                .font(.system(size: 11))
                .tracking(0.066)
                .foregroundColor(.white.opacity(0.78))
                .underline()
        }
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        PaywallScreen()
    }
}
