import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var showDebugView = false

    var body: some View {
        ZStack {
            Group {
                switch appState.authState {
                case .unknown:
                    SplashView()
                case .unauthenticated:
                    unauthenticatedContent
                case .authenticated:
                    authenticatedContent
                }
            }
            .animation(.easeInOut, value: appState.authState)

            // Connection Lost Banner - shown globally
            ConnectionLostBanner()

        }
        .alert("Join as Co-Host", isPresented: $appState.showInvitationDialog) {
            Button("Accept", role: .cancel) {
                appState.acceptInvitation()
            }
            Button("Decline", role: .destructive) {
                appState.declineInvitation()
            }
        } message: {
            if let event = appState.invitationEvent {
                Text("Welcome! You've been invited to co-organize \(event.name). Accept this invitation to start planning and collaborating on the event.")
            } else {
                Text("Welcome! You've been invited to co-organize this event. Accept this invitation to start planning and collaborating on the event.")
            }
        }
        .alert(L10n.error, isPresented: $appState.showErrorAlert) {
            Button(L10n.ok, role: .cancel) {}
        } message: {
            Text(appState.errorAlertMessage ?? L10n.error)
        }
        #if DEBUG
        .onShake {
            showDebugView = true
        }
        .sheet(isPresented: $showDebugView) {
            NavigationStack {
                DebugView()
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button(L10n.done) {
                                showDebugView = false
                            }
                        }
                    }
            }
        }
        // Debug deep link: rushday://debug/paywall
        .fullScreenCover(isPresented: $appState.showDebugPaywall) {
            PaywallScreen(source: "debug_deeplink") {
                appState.showDebugPaywall = false
            }
        }
        // Debug deep link: rushday://debug/feature-paywall
        .sheet(isPresented: $appState.showDebugFeaturePaywall) {
            FeaturePaywallSheet(
                source: "debug_deeplink",
                onPurchaseSuccess: {
                    appState.showDebugFeaturePaywall = false
                }
            )
        }
        // Debug deep link: rushday://debug/onboarding
        .fullScreenCover(isPresented: $appState.showDebugOnboarding) {
            OnboardingView()
        }
        // Debug deep link: rushday://debug/ai-planner
        .fullScreenCover(isPresented: $appState.showDebugAIPlanner) {
            AIEventPlannerView(
                onComplete: { _ in appState.showDebugAIPlanner = false },
                onDismiss: { appState.showDebugAIPlanner = false }
            )
        }
        // Debug deep link: rushday://debug/auth
        .fullScreenCover(isPresented: $appState.showDebugAuth) {
            AuthView()
                .environmentObject(appState)
        }
        // Debug deep link: rushday://debug/profile
        .sheet(isPresented: $appState.showDebugProfile) {
            NavigationStack {
                ProfileView()
            }
        }
        // Debug deep link: rushday://debug/console
        .sheet(isPresented: $appState.showDebugConsole) {
            NavigationStack {
                DebugView()
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button(L10n.done) {
                                appState.showDebugConsole = false
                            }
                        }
                    }
            }
        }
        // Debug deep link: rushday://debug/notification-settings
        .sheet(isPresented: $appState.showDebugNotificationSettings) {
            NavigationStack {
                NotificationSettingsView(
                    configuration: appState.currentUser?.notificationConfiguration
                )
            }
        }
        // Debug deep link: rushday://debug/guests
        .sheet(isPresented: $appState.showDebugGuests) {
            if let event = appState.debugEvent {
                NavigationStack {
                    GuestsListView(eventId: event.id, appState: appState)
                }
            }
        }
        // Debug deep link: rushday://debug/tasks
        .sheet(isPresented: $appState.showDebugTasks) {
            if let event = appState.debugEvent {
                NavigationStack {
                    TasksListView(eventId: event.id)
                }
            }
        }
        // Debug deep link: rushday://debug/edit-task
        .sheet(isPresented: $appState.showDebugEditTask) {
            if let event = appState.debugEvent {
                let mockTask = EventTask(
                    id: "debug-task-1",
                    eventId: event.id,
                    title: "Find Venue",
                    description: nil,
                    status: .pending,
                    dueDate: Date().addingTimeInterval(86400 * 3),
                    createdBy: "debug-user"
                )
                EditTaskSheet(
                    task: mockTask,
                    onSave: { _ in appState.showDebugEditTask = false },
                    onCancel: { appState.showDebugEditTask = false }
                )
            }
        }
        // Debug deep link: rushday://debug/agenda
        .sheet(isPresented: $appState.showDebugAgenda) {
            if let event = appState.debugEvent {
                NavigationStack {
                    AgendaListView(eventId: event.id, eventDate: event.startDate)
                }
            }
        }
        // Debug deep link: rushday://debug/expenses
        .sheet(isPresented: $appState.showDebugExpenses) {
            if let event = appState.debugEvent {
                NavigationStack {
                    ExpensesListView(eventId: event.id)
                }
            }
        }
        // Debug deep link: rushday://debug/budget-editor
        .sheet(isPresented: $appState.showDebugBudgetEditor) {
            BudgetEditorSheet(
                currentBudget: 1500,
                onSave: { budget in
                    print("Debug: Budget saved: \(budget)")
                    appState.showDebugBudgetEditor = false
                }
            )
        }
        // Debug deep link: rushday://debug/invitation-preview
        .fullScreenCover(isPresented: $appState.showDebugInvitationPreview) {
            if let event = appState.debugEvent {
                InvitationPreviewScreen(
                    event: event,
                    owner: appState.currentUser,
                    isViewOnly: false,
                    onSave: { _, _ in appState.showDebugInvitationPreview = false }
                )
            }
        }
        // Debug deep link: rushday://debug/edit-event
        .sheet(isPresented: $appState.showDebugEditEvent) {
            if let event = appState.debugEvent {
                NavigationStack {
                    EditEventView(event: event)
                }
            }
        }
        #endif
    }

    // MARK: - Unauthenticated Content

    @ViewBuilder
    private var unauthenticatedContent: some View {
        if !appState.hasCompletedOnboarding {
            // Step 1: Show onboarding first
            OnboardingView()
        } else if appState.showAIEventPlanner && !hasPendingDeepLink {
            // Step 2: Show AI Event Planner after onboarding (skip if there's a pending deep link)
            AIEventPlannerView(
                onComplete: { pendingData in
                    appState.completeAIPlanner(with: pendingData)
                },
                onDismiss: {
                    appState.cancelAIPlannerFlow()
                }
            )
        } else {
            // Step 3: Show auth screen (also shown when there's a pending deep link)
            AuthView()
        }
    }

    /// Check if there's a pending deep link that requires authentication first
    private var hasPendingDeepLink: Bool {
        appState.pendingDeepLink != nil || appState.pendingCoHostSecret != nil
    }

    // MARK: - Authenticated Content

    @ViewBuilder
    private var authenticatedContent: some View {
        if appState.showAIEventPlanner {
            // Continue showing AI Event Planner after auth (user signed in from within the wizard)
            AIEventPlannerView(
                onComplete: { pendingData in
                    appState.completeAIPlanner(with: pendingData)
                },
                onDismiss: {
                    appState.cancelAIPlannerFlow()
                }
            )
        } else if appState.showAIEventPreviewAfterAuth {
            // Show AI Plan Detail after auth (when user has pending event from wizard)
            AIPlanDetailView()
        } else {
            HomeScreen()
        }
    }
}

// MARK: - Splash View
/// Matches the native iOS launch screen exactly (gradient + centered icon)
struct SplashView: View {
    var body: some View {
        GeometryReader { geometry in
            if let uiImage = UIImage(named: "LaunchScreenBackground") {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
            } else {
                Color(red: 0.631, green: 0.482, blue: 0.957)
            }
        }
        .ignoresSafeArea()
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
