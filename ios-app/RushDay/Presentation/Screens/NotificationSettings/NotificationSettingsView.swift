import SwiftUI
import UserNotifications

// MARK: - Notification Settings Screen

struct NotificationSettingsView: View {
    @EnvironmentObject private var appState: AppState

    @State private var configuration: NotificationConfiguration
    @State private var hasPermission = false
    @State private var showTimePickerSheet = false
    @State private var showPeriodPicker = false
    private let grpcService = GRPCClientService.shared

    init(configuration: NotificationConfiguration? = nil) {
        let config = configuration ?? NotificationConfiguration()
        _configuration = State(initialValue: config)
    }

    var body: some View {
        List {
            // MARK: - Permission Section
            if !hasPermission {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Label(L10n.notificationsDisabled, systemImage: "bell.slash.fill")
                            .font(.rdBody())
                            .foregroundColor(.rdWarning)

                        Text(L10n.enableNotificationsHint)
                            .font(.rdCaption())
                            .foregroundColor(.rdTextSecondary)

                        Button(L10n.openSettings) {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                        .font(.rdLabel())
                        .padding(.top, 4)
                    }
                }
            }

            // MARK: - All Notifications
            Section {
                Toggle(L10n.enableAllNotifications, isOn: Binding(
                    get: { configuration.enableAll },
                    set: { newValue in
                        configuration.enableAll = newValue
                        if newValue {
                            configuration.isEnableUpComingReminder = true
                            configuration.isEnableAgendaReminder = true
                            configuration.isEnableGuestUpdatesReminder = true
                        } else {
                            configuration.isEnableUpComingReminder = false
                            configuration.isEnableAgendaReminder = false
                            configuration.isEnableGuestUpdatesReminder = false
                        }
                    }
                ))
                .tint(.rdAccent)
                .disabled(!hasPermission)
            }

            // MARK: - Upcoming Reminders
            Section {
                Toggle(L10n.upcomingReminders, isOn: $configuration.isEnableUpComingReminder)
                    .tint(.rdAccent)
                    .disabled(!configuration.enableAll || !hasPermission)

                HStack {
                    Text(L10n.notifyMe)
                    Spacer()
                    Button(configuration.upComingPeriod.displayName) {
                        showPeriodPicker = true
                    }
                    .foregroundColor(.rdPrimaryDark)
                }
                .disabled(!configuration.isEnableUpComingReminder || !configuration.enableAll)

                HStack {
                    Text(L10n.alertTime)
                    Spacer()
                    Button(formattedReminderTime) {
                        showTimePickerSheet = true
                    }
                    .foregroundColor(.rdPrimaryDark)
                }
                .disabled(!configuration.isEnableUpComingReminder || !configuration.enableAll)
            } footer: {
                Text(L10n.upcomingRemindersHint)
            }

            // MARK: - Agenda Reminders
            Section {
                Toggle(L10n.agendaNotifications, isOn: $configuration.isEnableAgendaReminder)
                    .tint(.rdAccent)
                    .disabled(!configuration.enableAll || !hasPermission)

                Picker("Notify me", selection: $configuration.agendaReminderPeriod) {
                    ForEach(AgendaReminderPeriod.allCases, id: \.self) { period in
                        Text(period.displayName).tag(period)
                    }
                }
                .disabled(!configuration.isEnableAgendaReminder || !configuration.enableAll)
            } footer: {
                Text("Get notified about agenda items during your events.")
            }

            // MARK: - Guest Updates
            Section {
                Toggle("Guest Updates", isOn: $configuration.isEnableGuestUpdatesReminder)
                    .tint(.rdAccent)
                    .disabled(!configuration.enableAll || !hasPermission)
            } footer: {
                Text("Get notified when guests RSVP or update their response.")
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: configuration) { _, _ in
            Task { await saveConfiguration() }
        }
        .task {
            let center = UNUserNotificationCenter.current()
            let settings = await center.notificationSettings()
            hasPermission = settings.authorizationStatus == .authorized
        }
        .sheet(isPresented: $showTimePickerSheet) {
            TimePickerSheet(
                selectedTime: reminderTimeAsDate,
                onSave: { date in
                    let formatter = DateFormatter()
                    formatter.dateFormat = "H:mm"
                    configuration.upComingReminderTime = formatter.string(from: date)
                }
            )
            .presentationDetents([.height(300)])
        }
        .sheet(isPresented: $showPeriodPicker) {
            PeriodPickerView(
                selectedPeriod: configuration.upComingPeriod,
                onSelect: { period in
                    configuration.upComingPeriod = period
                }
            )
        }
    }

    // MARK: - Save

    private func saveConfiguration() async {
        var request = Rushday_V1_UpdateNotificationPreferencesRequest()
        request.time = configuration.upComingReminderTime
        request.agenda = configuration.isEnableAgendaReminder
        request.onTheDay = configuration.upComingPeriod == .onEventDay
        request.weekBefore = configuration.upComingPeriod == .weekBefore
        request.tasks = configuration.isEnableUpComingReminder
        request.share = configuration.isEnableGuestUpdatesReminder

        do {
            let grpcUser = try await grpcService.updateNotificationPreferences(request)
            let domainUser = User(from: grpcUser)
            appState.updateUser(domainUser)
        } catch {
            print("Failed to save notification config: \(error)")
        }
    }

    // MARK: - Helpers

    private var reminderTimeAsDate: Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "H:mm"
        return formatter.date(from: configuration.upComingReminderTime) ?? Date()
    }

    private var formattedReminderTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "H:mm"
        if let date = formatter.date(from: configuration.upComingReminderTime) {
            formatter.timeStyle = .short
            return formatter.string(from: date)
        }
        return configuration.upComingReminderTime
    }
}

// MARK: - Display Name Protocol

protocol DisplayNameConvertible {
    var displayName: String { get }
}

extension UpComingEventReminderPeriod: DisplayNameConvertible {}
extension AgendaReminderPeriod: DisplayNameConvertible {}

// MARK: - Time Picker Sheet

private struct TimePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTime: Date
    let onSave: (Date) -> Void

    init(selectedTime: Date, onSave: @escaping (Date) -> Void) {
        _selectedTime = State(initialValue: selectedTime)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            VStack {
                DatePicker(
                    "Reminder Time",
                    selection: $selectedTime,
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(.wheel)
                .labelsHidden()

                Spacer()
            }
            .padding()
            .navigationTitle("Alert Time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        onSave(selectedTime)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Period Picker View

private struct PeriodPickerView: View {
    @Environment(\.dismiss) private var dismiss
    let selectedPeriod: UpComingEventReminderPeriod
    let onSelect: (UpComingEventReminderPeriod) -> Void

    var body: some View {
        NavigationStack {
            List {
                ForEach(UpComingEventReminderPeriod.allCases, id: \.self) { period in
                    Button {
                        onSelect(period)
                        dismiss()
                    } label: {
                        HStack {
                            Text(period.displayName)
                                .foregroundColor(.rdTextPrimary)
                            Spacer()
                            if period == selectedPeriod {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.rdPrimaryDark)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Period Before Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.rdTextPrimary)
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        NotificationSettingsView(
            configuration: NotificationConfiguration()
        )
        .environmentObject(AppState())
    }
}
