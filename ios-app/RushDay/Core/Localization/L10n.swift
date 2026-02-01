import SwiftUI

// MARK: - Localization Keys
@MainActor
enum L10n {
    private static var manager: LocalizationManager { LocalizationManager.shared }

    // MARK: - Common
    static var cancel: String { manager.localizedString(for: "cancel") }
    static var done: String { manager.localizedString(for: "done") }
    static var save: String { manager.localizedString(for: "save") }
    static var delete: String { manager.localizedString(for: "delete") }
    static var edit: String { manager.localizedString(for: "edit") }
    static var next: String { manager.localizedString(for: "next") }
    static var skip: String { manager.localizedString(for: "skip") }
    static var search: String { manager.localizedString(for: "search") }
    static var areYouSure: String { manager.localizedString(for: "areYouSure") }
    static var name: String { manager.localizedString(for: "name") }
    static var email: String { manager.localizedString(for: "email") }
    static var date: String { manager.localizedString(for: "date") }
    static var time: String { manager.localizedString(for: "time") }
    static var add: String { manager.localizedString(for: "add") }
    static var ok: String { manager.localizedString(for: "ok") }
    static var error: String { manager.localizedString(for: "error") }
    static var title: String { manager.localizedString(for: "title") }
    static var description: String { manager.localizedString(for: "description") }
    static var location: String { manager.localizedString(for: "location") }
    static var notes: String { manager.localizedString(for: "notes") }
    static var status: String { manager.localizedString(for: "status") }
    static var share: String { manager.localizedString(for: "share") }
    static var manage: String { manager.localizedString(for: "manage") }
    static var host: String { manager.localizedString(for: "host") }
    static var organizer: String { manager.localizedString(for: "organizer") }
    static var eventHost: String { manager.localizedString(for: "eventHost") }
    static var all: String { manager.localizedString(for: "all") }
    static var undo: String { manager.localizedString(for: "undo") }
    static var remove: String { manager.localizedString(for: "remove") }
    static var complete: String { manager.localizedString(for: "complete") }
    static var openSettings: String { manager.localizedString(for: "openSettings") }

    // MARK: - Profile
    static var profile: String { manager.localizedString(for: "profile") }
    static var editProfile: String { manager.localizedString(for: "editProfile") }
    static var notifications: String { manager.localizedString(for: "notifications") }
    static var contactUs: String { manager.localizedString(for: "contactUs") }
    static var subject: String { manager.localizedString(for: "subject") }
    static var send: String { manager.localizedString(for: "send") }
    static var contactUsScreenDesc: String { manager.localizedString(for: "contactUsScreenDesc") }
    static var contactUsSuccessSendingTitle: String { manager.localizedString(for: "contactUsSuccessSendingTitle") }
    static var contactUsSuccessSendingDesc: String { manager.localizedString(for: "contactUsSuccessSendingDesc") }
    static var contactUsErrorSendingTitle: String { manager.localizedString(for: "contactUsErrorSendingTitle") }
    static var contactUsErrorSendingDesc: String { manager.localizedString(for: "contactUsErrorSendingDesc") }
    static var language: String { manager.localizedString(for: "language") }
    static var termsOfService: String { manager.localizedString(for: "termsOfService") }
    static var privacyPolicy: String { manager.localizedString(for: "privacyPolicy") }
    static var appVersion: String { manager.localizedString(for: "appVersion") }
    static var logOut: String { manager.localizedString(for: "logOut") }
    static var logOutDesc: String { manager.localizedString(for: "logOutDesc") }
    static var deleteAccount: String { manager.localizedString(for: "deleteAccount") }
    static var deleteAccountTitle: String { manager.localizedString(for: "deleteAccountTitle") }
    static var deleteAccountDesc: String { manager.localizedString(for: "deleteAccountDesc") }
    static var deleteProfile: String { manager.localizedString(for: "deleteProfile") }
    static var setNewPhoto: String { manager.localizedString(for: "setNewPhoto") }
    static var changePhoto: String { manager.localizedString(for: "changePhoto") }
    static var choosePhoto: String { manager.localizedString(for: "choosePhoto") }
    static var removePhoto: String { manager.localizedString(for: "removePhoto") }
    static var yourName: String { manager.localizedString(for: "yourName") }
    static var settings: String { manager.localizedString(for: "settings") }

    // MARK: - Events
    static var events: String { manager.localizedString(for: "events") }
    static var upcoming: String { manager.localizedString(for: "upcoming") }
    static var past: String { manager.localizedString(for: "past") }
    static var drafts: String { manager.localizedString(for: "drafts") }
    static var addEvent: String { manager.localizedString(for: "addEvent") }
    static var createEvent: String { manager.localizedString(for: "createEvent") }
    static var createYourFirstEvent: String { manager.localizedString(for: "createYourFirstEvent") }
    static var editEvent: String { manager.localizedString(for: "editEvent") }
    static var addToCalendar: String { manager.localizedString(for: "addToCalendar") }
    static var moveToDrafts: String { manager.localizedString(for: "moveToDrafts") }
    static var venue: String { manager.localizedString(for: "venue") }
    static var budget: String { manager.localizedString(for: "budget") }
    static var deleteEvent: String { manager.localizedString(for: "deleteEvent") }
    static var deleteEventConfirmation: String { manager.localizedString(for: "deleteEventConfirmation") }
    static var dateAndTime: String { manager.localizedString(for: "dateAndTime") }
    static var theme: String { manager.localizedString(for: "theme") }
    static var previewInvitation: String { manager.localizedString(for: "previewInvitation") }
    static var eventDate: String { manager.localizedString(for: "eventDate") }

    // MARK: - Tasks
    static var tasks: String { manager.localizedString(for: "tasks") }
    static var addTask: String { manager.localizedString(for: "addTask") }
    static var emptyTaskTitle: String { manager.localizedString(for: "emptyTaskTitle") }
    static var emptyTaskDesc: String { manager.localizedString(for: "emptyTaskDesc") }
    static var newTask: String { manager.localizedString(for: "newTask") }
    static var taskDetails: String { manager.localizedString(for: "taskDetails") }
    static var priority: String { manager.localizedString(for: "priority") }
    static var dueDate: String { manager.localizedString(for: "dueDate") }
    static var setDueDate: String { manager.localizedString(for: "setDueDate") }
    static var completed: String { manager.localizedString(for: "completed") }
    static var assigned: String { manager.localizedString(for: "assigned") }
    static var high: String { manager.localizedString(for: "high") }
    static var medium: String { manager.localizedString(for: "medium") }
    static var low: String { manager.localizedString(for: "low") }

    // MARK: - Guests
    static var guests: String { manager.localizedString(for: "guests") }
    static var addGuest: String { manager.localizedString(for: "addGuest") }
    static var totalGuests: String { manager.localizedString(for: "totalGuests") }
    static var confirmed: String { manager.localizedString(for: "confirmed") }
    static var pending: String { manager.localizedString(for: "pending") }
    static var declined: String { manager.localizedString(for: "declined") }
    static var invited: String { manager.localizedString(for: "invited") }
    static var notInvited: String { manager.localizedString(for: "notInvited") }
    static var accepted: String { manager.localizedString(for: "accepted") }
    static var going: String { manager.localizedString(for: "going") }
    static var notGoing: String { manager.localizedString(for: "notGoing") }
    static var emptyGuestTitle: String { manager.localizedString(for: "emptyGuestTitle") }
    static var emptyGuestDesc: String { manager.localizedString(for: "emptyGuestDesc") }
    static var guestInformation: String { manager.localizedString(for: "guestInformation") }
    static var phone: String { manager.localizedString(for: "phone") }
    static var role: String { manager.localizedString(for: "role") }
    static var importFromContacts: String { manager.localizedString(for: "importFromContacts") }
    static var addFromContacts: String { manager.localizedString(for: "addFromContacts") }
    static var noGuestsYet: String { manager.localizedString(for: "noGuestsYet") }
    static var everyoneInvited: String { manager.localizedString(for: "everyoneInvited") }
    static var noPendingRSVPs: String { manager.localizedString(for: "noPendingRSVPs") }
    static var noConfirmationsYet: String { manager.localizedString(for: "noConfirmationsYet") }
    static var noDeclines: String { manager.localizedString(for: "noDeclines") }
    static var startAddingGuests: String { manager.localizedString(for: "startAddingGuests") }
    static var allGuestsInvited: String { manager.localizedString(for: "allGuestsInvited") }
    static var noGuestsAwaiting: String { manager.localizedString(for: "noGuestsAwaiting") }
    static var confirmedGuestsAppear: String { manager.localizedString(for: "confirmedGuestsAppear") }
    static var declinedGuestsAppear: String { manager.localizedString(for: "declinedGuestsAppear") }
    static var loadingContacts: String { manager.localizedString(for: "loadingContacts") }
    static var cannotAccessContacts: String { manager.localizedString(for: "cannotAccessContacts") }
    static var noContacts: String { manager.localizedString(for: "noContacts") }
    static var noContactsFound: String { manager.localizedString(for: "noContactsFound") }
    static var searchContacts: String { manager.localizedString(for: "searchContacts") }
    static var added: String { manager.localizedString(for: "added") }
    static var contactsSelected: String { manager.localizedString(for: "contactsSelected") }

    // MARK: - Expenses
    static var expenses: String { manager.localizedString(for: "expenses") }
    static var addItem: String { manager.localizedString(for: "addItem") }
    static var totalSpent: String { manager.localizedString(for: "totalSpent") }
    static var emptyExpenseTitle: String { manager.localizedString(for: "emptyExpenseTitle") }
    static var emptyExpenseDesc: String { manager.localizedString(for: "emptyExpenseDesc") }
    static var addExpense: String { manager.localizedString(for: "addExpense") }
    static var overview: String { manager.localizedString(for: "overview") }
    static var planned: String { manager.localizedString(for: "planned") }
    static var spent: String { manager.localizedString(for: "spent") }
    static var remaining: String { manager.localizedString(for: "remaining") }
    static var byCategory: String { manager.localizedString(for: "byCategory") }
    static var recentExpenses: String { manager.localizedString(for: "recentExpenses") }
    static var noExpenses: String { manager.localizedString(for: "noExpenses") }
    static var noPlannedExpenses: String { manager.localizedString(for: "noPlannedExpenses") }
    static var noSpentExpenses: String { manager.localizedString(for: "noSpentExpenses") }
    static var startTrackingExpenses: String { manager.localizedString(for: "startTrackingExpenses") }
    static var addPlannedExpenses: String { manager.localizedString(for: "addPlannedExpenses") }
    static var paidExpensesAppear: String { manager.localizedString(for: "paidExpensesAppear") }
    static var expenseDetails: String { manager.localizedString(for: "expenseDetails") }
    static var amount: String { manager.localizedString(for: "amount") }
    static var category: String { manager.localizedString(for: "category") }
    static var paymentStatus: String { manager.localizedString(for: "paymentStatus") }
    static var markPaid: String { manager.localizedString(for: "markPaid") }
    static var setBudget: String { manager.localizedString(for: "setBudget") }
    static var plannedBudget: String { manager.localizedString(for: "plannedBudget") }
    static var budgetAmount: String { manager.localizedString(for: "budgetAmount") }
    static var setBudgetHint: String { manager.localizedString(for: "setBudgetHint") }

    // MARK: - Agenda
    static var agenda: String { manager.localizedString(for: "agenda") }
    static var addActivity: String { manager.localizedString(for: "addActivity") }
    static var emptyAgendaTitle: String { manager.localizedString(for: "emptyAgendaTitle") }
    static var emptyAgendaDesc: String { manager.localizedString(for: "emptyAgendaDesc") }
    static var addAgendaItem: String { manager.localizedString(for: "addAgendaItem") }
    static var noAgendaItems: String { manager.localizedString(for: "noAgendaItems") }
    static var planEventTimeline: String { manager.localizedString(for: "planEventTimeline") }
    static var itemDetails: String { manager.localizedString(for: "itemDetails") }
    static var startTime: String { manager.localizedString(for: "startTime") }
    static var endTime: String { manager.localizedString(for: "endTime") }
    static var setEndTime: String { manager.localizedString(for: "setEndTime") }

    // MARK: - Empty States
    static var emptyUpcomingTitle: String { manager.localizedString(for: "emptyUpcomingTitle") }
    static var emptyUpcomingDesc: String { manager.localizedString(for: "emptyUpcomingDesc") }
    static var emptyPastTitle: String { manager.localizedString(for: "emptyPastTitle") }
    static var emptyPastDesc: String { manager.localizedString(for: "emptyPastDesc") }
    static var emptyDraftTitle: String { manager.localizedString(for: "emptyDraftTitle") }
    static var emptyDraftDesc: String { manager.localizedString(for: "emptyDraftDesc") }
    static var selected: String { manager.localizedString(for: "selected") }

    // MARK: - Auth
    static var signGoogle: String { manager.localizedString(for: "signGoogle") }
    static var signApple: String { manager.localizedString(for: "signApple") }
    static var getStarted: String { manager.localizedString(for: "getStarted") }
    static var continueWithApple: String { manager.localizedString(for: "continueWithApple") }
    static var continueWithGoogle: String { manager.localizedString(for: "continueWithGoogle") }
    static var createPerfectEvent: String { manager.localizedString(for: "createPerfectEvent") }
    static var signingIn: String { manager.localizedString(for: "signingIn") }
    static var byContinuing: String { manager.localizedString(for: "byContinuing") }
    static var and: String { manager.localizedString(for: "and") }

    // MARK: - Notification Settings
    static var notificationsDisabled: String { manager.localizedString(for: "notificationsDisabled") }
    static var enableNotificationsHint: String { manager.localizedString(for: "enableNotificationsHint") }
    static var enableAllNotifications: String { manager.localizedString(for: "enableAllNotifications") }
    static var upcomingReminders: String { manager.localizedString(for: "upcomingReminders") }
    static var notifyMe: String { manager.localizedString(for: "notifyMe") }
    static var alertTime: String { manager.localizedString(for: "alertTime") }
    static var upcomingRemindersHint: String { manager.localizedString(for: "upcomingRemindersHint") }
    static var agendaNotifications: String { manager.localizedString(for: "agendaNotifications") }
    static var agendaNotificationsHint: String { manager.localizedString(for: "agendaNotificationsHint") }
    static var guestUpdates: String { manager.localizedString(for: "guestUpdates") }
    static var guestUpdatesHint: String { manager.localizedString(for: "guestUpdatesHint") }
    static var reminderTime: String { manager.localizedString(for: "reminderTime") }

    // MARK: - Edit Event
    static var back: String { manager.localizedString(for: "back") }
    static var allDay: String { manager.localizedString(for: "allDay") }
    static var start: String { manager.localizedString(for: "start") }
    static var end: String { manager.localizedString(for: "end") }
    static var addEndDate: String { manager.localizedString(for: "addEndDate") }
    static var removeEndDate: String { manager.localizedString(for: "removeEndDate") }
    static var starts: String { manager.localizedString(for: "starts") }
    static var ends: String { manager.localizedString(for: "ends") }
    static var confirm: String { manager.localizedString(for: "confirm") }
    static var addEndTime: String { manager.localizedString(for: "addEndTime") }
    static var removeEndTime: String { manager.localizedString(for: "removeEndTime") }
    static var unsavedChanges: String { manager.localizedString(for: "unsavedChanges") }
    static var unsavedChangesDesc: String { manager.localizedString(for: "unsavedChangesDesc") }
    static var discard: String { manager.localizedString(for: "discard") }

    // MARK: - Create Event Flow
    static var addYourGuests: String { manager.localizedString(for: "addYourGuests") }
    static var invitePeopleToEvent: String { manager.localizedString(for: "invitePeopleToEvent") }
    static var addGuestsToSendInvites: String { manager.localizedString(for: "addGuestsToSendInvites") }
    static var budgetHelpHint: String { manager.localizedString(for: "budgetHelpHint") }

    // MARK: - Onboarding & Auth
    static var alreadyHaveAccount: String { manager.localizedString(for: "alreadyHaveAccount") }
    static var welcomeToRushDay: String { manager.localizedString(for: "welcomeToRushDay") }
    static var signInToRushDay: String { manager.localizedString(for: "signInToRushDay") }
    static var loginDescription: String { manager.localizedString(for: "loginDescription") }
    static var byContinuingYouAgree: String { manager.localizedString(for: "byContinuingYouAgree") }

    // MARK: - AI Plan Tiers
    static var planTierRecommended: String { manager.localizedString(for: "planTierRecommended") }
    static var planTierPopular: String { manager.localizedString(for: "planTierPopular") }
    static var planTitleRecommended: String { manager.localizedString(for: "planTitleRecommended") }
    static var planTitlePopular: String { manager.localizedString(for: "planTitlePopular") }
    static var planTitleStandard: String { manager.localizedString(for: "planTitleStandard") }

    // MARK: - Paywall
    static var getPremium: String { manager.localizedString(for: "getPremium") }
    static var free: String { manager.localizedString(for: "free") }
    static var pro: String { manager.localizedString(for: "pro") }
    static var go: String { manager.localizedString(for: "go") }
    static var premium: String { manager.localizedString(for: "premium") }
    static var unlockMoreWith: String { manager.localizedString(for: "unlockMoreWith") }
    static var rushDayPro: String { manager.localizedString(for: "rushDayPro") }
    static var cancelAnytime: String { manager.localizedString(for: "cancelAnytime") }
    static var restorePurchase: String { manager.localizedString(for: "restorePurchase") }
    static var byContinuingAgree: String { manager.localizedString(for: "byContinuingAgree") }

    // Format functions for paywall
    static func freeDays(_ days: Int) -> String {
        String(format: manager.localizedString(for: "freeDays"), days)
    }

    static func tryFreeForDays(_ days: Int) -> String {
        String(format: manager.localizedString(for: "tryFreeForDays"), days)
    }

    static func discount(_ percent: Int) -> String {
        String(format: manager.localizedString(for: "discountPercent"), percent)
    }

    static func freeTrial(_ days: Int) -> String {
        String(format: manager.localizedString(for: "freeTrialDays"), days)
    }

    static func startYourFreeTrial(_ days: Int) -> String {
        String(format: manager.localizedString(for: "startYourFreeTrial"), days)
    }

    // MARK: - Invitation Preview
    static var unsavedChangesAction: String { manager.localizedString(for: "unsavedChangesAction") }

    // MARK: - Additional Expenses
    static var notesOptional: String { manager.localizedString(for: "notesOptional") }

    // MARK: - Co-Hosts
    static var coHosts: String { manager.localizedString(for: "coHosts") }
    static var addCoHost: String { manager.localizedString(for: "addCoHost") }
    static var cannotCoHostOwnEvent: String { manager.localizedString(for: "cannotCoHostOwnEvent") }

    // MARK: - Create Event Flow
    static var whatsYourBudget: String { manager.localizedString(for: "whatsYourBudget") }
    static var spentLimit: String { manager.localizedString(for: "spentLimit") }
    static var selectCurrency: String { manager.localizedString(for: "selectCurrency") }
    static var addEventNameDateVenue: String { manager.localizedString(for: "addEventNameDateVenue") }
    static var eventName: String { manager.localizedString(for: "eventName") }
    static var enterEventName: String { manager.localizedString(for: "enterEventName") }
    static var nameYourEvent: String { manager.localizedString(for: "nameYourEvent") }
    static var selectDateTime: String { manager.localizedString(for: "selectDateTime") }
    static var enterAddress: String { manager.localizedString(for: "enterAddress") }
    static var addManually: String { manager.localizedString(for: "addManually") }
    static var fromContacts: String { manager.localizedString(for: "fromContacts") }
    static var guestsAdded: String { manager.localizedString(for: "guestsAdded") }
    static var clearAll: String { manager.localizedString(for: "clearAll") }
    static var skipForNow: String { manager.localizedString(for: "skipForNow") }
    static var continueText: String { manager.localizedString(for: "continue") }
    static var guestName: String { manager.localizedString(for: "guestName") }
    static var phoneOptional: String { manager.localizedString(for: "phoneOptional") }

    // MARK: - Agenda
    static var descriptionOptional: String { manager.localizedString(for: "descriptionOptional") }
    static var locationOptional: String { manager.localizedString(for: "locationOptional") }

    // MARK: - Onboarding
    static var planAnyEvent: String { manager.localizedString(for: "planAnyEvent") }
    static var planAnyEventDesc: String { manager.localizedString(for: "planAnyEventDesc") }
    static var manageGuestsTitle: String { manager.localizedString(for: "manageGuestsTitle") }
    static var manageGuestsDesc: String { manager.localizedString(for: "manageGuestsDesc") }
    static var stayOrganized: String { manager.localizedString(for: "stayOrganized") }
    static var stayOrganizedDesc: String { manager.localizedString(for: "stayOrganizedDesc") }
    static var shareCollaborate: String { manager.localizedString(for: "shareCollaborate") }
    static var shareCollaborateDesc: String { manager.localizedString(for: "shareCollaborateDesc") }
    static var signIn: String { manager.localizedString(for: "signIn") }

    // MARK: - Paywall Features
    static var manualPlanning: String { manager.localizedString(for: "manualPlanning") }
    static var unlimitedEvents: String { manager.localizedString(for: "unlimitedEvents") }
    static var aiTaskGeneration: String { manager.localizedString(for: "aiTaskGeneration") }
    static var agendaBuilder: String { manager.localizedString(for: "agendaBuilder") }
    static var expenseTracker: String { manager.localizedString(for: "expenseTracker") }
    static var shareEvents: String { manager.localizedString(for: "shareEvents") }
    static var inviteGuestsFeature: String { manager.localizedString(for: "inviteGuestsFeature") }
    static var annual: String { manager.localizedString(for: "annual") }
    static var monthly: String { manager.localizedString(for: "monthly") }
    static var subscribe: String { manager.localizedString(for: "subscribe") }
    static var startFreeTrial: String { manager.localizedString(for: "startFreeTrial") }
    static var daysFree: String { manager.localizedString(for: "daysFree") }
    static var noActiveSubscription: String { manager.localizedString(for: "noActiveSubscription") }

    // MARK: - Invitation Preview
    static var invitesYouTo: String { manager.localizedString(for: "invitesYouTo") }
    static var noMessageYet: String { manager.localizedString(for: "noMessageYet") }
    static var enterMessageForGuests: String { manager.localizedString(for: "enterMessageForGuests") }
    static var whatWouldYouLikeToDo: String { manager.localizedString(for: "whatWouldYouLikeToDo") }

    // MARK: - Create Event Flow - Event Type
    static var whatTypeOfEvent: String { manager.localizedString(for: "whatTypeOfEvent") }
    static var chooseTypeBestFits: String { manager.localizedString(for: "chooseTypeBestFits") }
    static var enterYourEventType: String { manager.localizedString(for: "enterYourEventType") }

    // MARK: - Event Type Names
    static var eventTypeBirthday: String { manager.localizedString(for: "eventTypeBirthday") }
    static var eventTypeWedding: String { manager.localizedString(for: "eventTypeWedding") }
    static var eventTypeCorporate: String { manager.localizedString(for: "eventTypeCorporate") }
    static var eventTypeBabyShower: String { manager.localizedString(for: "eventTypeBabyShower") }
    static var eventTypeGraduation: String { manager.localizedString(for: "eventTypeGraduation") }
    static var eventTypeAnniversary: String { manager.localizedString(for: "eventTypeAnniversary") }
    static var eventTypeHoliday: String { manager.localizedString(for: "eventTypeHoliday") }
    static var eventTypeConference: String { manager.localizedString(for: "eventTypeConference") }
    static var eventTypeVacation: String { manager.localizedString(for: "eventTypeVacation") }
    static var eventTypeCustom: String { manager.localizedString(for: "eventTypeCustom") }

    // MARK: - Create Event Flow - Guest Count
    static var howManyGuests: String { manager.localizedString(for: "howManyGuests") }
    static var lessThan: String { manager.localizedString(for: "lessThan") }
    static var moreThan: String { manager.localizedString(for: "moreThan") }

    // MARK: - Create Event Flow - Venue
    static var whereWillEventTakePlace: String { manager.localizedString(for: "whereWillEventTakePlace") }
    static var selectVenueType: String { manager.localizedString(for: "selectVenueType") }
    static var enterVenueName: String { manager.localizedString(for: "enterVenueName") }
    static var venueHome: String { manager.localizedString(for: "venueHome") }
    static var venueRestaurant: String { manager.localizedString(for: "venueRestaurant") }
    static var venueHotel: String { manager.localizedString(for: "venueHotel") }
    static var venueOutdoor: String { manager.localizedString(for: "venueOutdoor") }
    static var venueOffice: String { manager.localizedString(for: "venueOffice") }
    static var venueEventHall: String { manager.localizedString(for: "venueEventHall") }
    static var venueOther: String { manager.localizedString(for: "venueOther") }
    static var venueHomeDesc: String { manager.localizedString(for: "venueHomeDesc") }
    static var venueRestaurantDesc: String { manager.localizedString(for: "venueRestaurantDesc") }
    static var venueHotelDesc: String { manager.localizedString(for: "venueHotelDesc") }
    static var venueOutdoorDesc: String { manager.localizedString(for: "venueOutdoorDesc") }
    static var venueOfficeDesc: String { manager.localizedString(for: "venueOfficeDesc") }
    static var venueEventHallDesc: String { manager.localizedString(for: "venueEventHallDesc") }
    static var venueOtherDesc: String { manager.localizedString(for: "venueOtherDesc") }

    // MARK: - Create Event Flow - Services
    static var whatServicesDoYouNeed: String { manager.localizedString(for: "whatServicesDoYouNeed") }
    static var selectAllThatApply: String { manager.localizedString(for: "selectAllThatApply") }
    static var customIdea: String { manager.localizedString(for: "customIdea") }
    static var enterCustomIdea: String { manager.localizedString(for: "enterCustomIdea") }
    static var services: String { manager.localizedString(for: "services") }

    // MARK: - Create Event Flow - Services Names
    static var serviceCatering: String { manager.localizedString(for: "serviceCatering") }
    static var servicePhotography: String { manager.localizedString(for: "servicePhotography") }
    static var serviceVideography: String { manager.localizedString(for: "serviceVideography") }
    static var serviceMusicDJ: String { manager.localizedString(for: "serviceMusicDJ") }
    static var serviceDecorations: String { manager.localizedString(for: "serviceDecorations") }
    static var serviceFlowers: String { manager.localizedString(for: "serviceFlowers") }
    static var serviceCakeDesserts: String { manager.localizedString(for: "serviceCakeDesserts") }
    static var serviceTransportation: String { manager.localizedString(for: "serviceTransportation") }
    static var serviceEntertainment: String { manager.localizedString(for: "serviceEntertainment") }
    static var serviceInvitations: String { manager.localizedString(for: "serviceInvitations") }
    static var serviceRentals: String { manager.localizedString(for: "serviceRentals") }
    static var serviceSecurity: String { manager.localizedString(for: "serviceSecurity") }

    // MARK: - Create Event Flow - Review
    static var review: String { manager.localizedString(for: "review") }

    // MARK: - Create Event Flow - Generated Result
    static var todoList: String { manager.localizedString(for: "todoList") }
    static var selectAll: String { manager.localizedString(for: "selectAll") }
    static var generateAgenda: String { manager.localizedString(for: "generateAgenda") }
    static var generateExpenses: String { manager.localizedString(for: "generateExpenses") }
    static var recalculate: String { manager.localizedString(for: "recalculate") }
    static var total: String { manager.localizedString(for: "total") }

    // MARK: - Create Event Flow - Buttons
    static var letsPlan: String { manager.localizedString(for: "letsPlan") }

    // MARK: - Create Event Flow - Errors
    static var generationFailed: String { manager.localizedString(for: "generationFailed") }
    static var notSignedIn: String { manager.localizedString(for: "notSignedIn") }

    // MARK: - Date Formatting
    static var at: String { manager.localizedString(for: "at") }

    // MARK: - Placeholders
    static var emailPlaceholder: String { manager.localizedString(for: "emailPlaceholder") }
    static var phonePlaceholder: String { manager.localizedString(for: "phonePlaceholder") }

    // MARK: - Currency Names
    static var currencyUSDollar: String { manager.localizedString(for: "currencyUSDollar") }
    static var currencyEuro: String { manager.localizedString(for: "currencyEuro") }
    static var currencyBritishPound: String { manager.localizedString(for: "currencyBritishPound") }
    static var currencyJapaneseYen: String { manager.localizedString(for: "currencyJapaneseYen") }
    static var currencyAustralianDollar: String { manager.localizedString(for: "currencyAustralianDollar") }
    static var currencyCanadianDollar: String { manager.localizedString(for: "currencyCanadianDollar") }
    static var currencySwissFranc: String { manager.localizedString(for: "currencySwissFranc") }
    static var currencyChineseYuan: String { manager.localizedString(for: "currencyChineseYuan") }
    static var currencyIndianRupee: String { manager.localizedString(for: "currencyIndianRupee") }
    static var currencyRussianRuble: String { manager.localizedString(for: "currencyRussianRuble") }
    static var currencyUzbekSom: String { manager.localizedString(for: "currencyUzbekSom") }

    // MARK: - Onboarding
    static var onboardingFirstTitle: String { manager.localizedString(for: "onboardingFirstTitle") }
    static var onboardingFirstSubtitle: String { manager.localizedString(for: "onboardingFirstSubtitle") }
    static var onboardingSecondTitle: String { manager.localizedString(for: "onboardingSecondTitle") }
    static var onboardingSecondSubtitle: String { manager.localizedString(for: "onboardingSecondSubtitle") }
    static var onboardingThirdTitle: String { manager.localizedString(for: "onboardingThirdTitle") }
    static var onboardingThirdSubtitle: String { manager.localizedString(for: "onboardingThirdSubtitle") }

    // MARK: - Network
    static var connectionLostTitle: String { manager.localizedString(for: "connectionLostTitle") }
    static var connectionLostMessage: String { manager.localizedString(for: "connectionLostMessage") }

    // MARK: - Invitations & Deep Links
    static var shareInvitation: String { manager.localizedString(for: "shareInvitation") }
    static var invitationMessage: String { manager.localizedString(for: "message") }
    static var copy: String { manager.localizedString(for: "copy") }
    static var copiedToClipboard: String { manager.localizedString(for: "copiedToClipboard") }
    static var youAreInvited: String { manager.localizedString(for: "youAreInvited") }
    static var accept: String { manager.localizedString(for: "accept") }
    static var decline: String { manager.localizedString(for: "decline") }

    static func invitationEmailSubject(_ eventName: String) -> String {
        String(format: manager.localizedString(for: "invitationEmailSubject"), eventName)
    }

    static func invitationEmailBody(_ eventName: String, _ link: String) -> String {
        String(format: manager.localizedString(for: "invitationEmailBody"), eventName, link)
    }

    static func invitationSMSBody(_ eventName: String, _ link: String) -> String {
        String(format: manager.localizedString(for: "invitationSMSBody"), eventName, link)
    }

    // MARK: - Feature Paywall
    static var featurePaywallTitle: String { manager.localizedString(for: "featurePaywallTitle") }
    static var featurePaywallSubtitle: String { manager.localizedString(for: "featurePaywallSubtitle") }
    static var featureTaskLists: String { manager.localizedString(for: "featureTaskLists") }
    static var featureAutoScheduling: String { manager.localizedString(for: "featureAutoScheduling") }
    static var featureBudgetTracking: String { manager.localizedString(for: "featureBudgetTracking") }
    static var featureTeamSharing: String { manager.localizedString(for: "featureTeamSharing") }
    static var featurePromoTitle: String { manager.localizedString(for: "featurePromoTitle") }
    static var featurePromoPrice: String { manager.localizedString(for: "featurePromoPrice") }
}

// MARK: - String Extension for Localization
extension String {
    var localized: String {
        String(localized: LocalizationValue(self))
    }

    func localized(with arguments: CVarArg...) -> String {
        String(format: self.localized, arguments: arguments)
    }
}
