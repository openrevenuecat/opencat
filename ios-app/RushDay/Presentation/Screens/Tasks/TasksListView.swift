import SwiftUI
import Combine

// MARK: - Tasks List View
struct TasksListView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel: TasksViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var isAddingTask = false
    @State private var newTaskTitle = ""
    @State private var newTaskNote = ""
    @State private var newTaskDate: Date? = nil
    @State private var isSelectMode = false
    @State private var selectedTaskIds: Set<String> = []
    @State private var showDeleteAllConfirmation = false
    @State private var showDeleteSelectedConfirmation = false
    @AppStorage("tasks_hide_completed") private var hideCompleted = false
    @State private var showNavTitle = false
    @State private var showTaskDetailSheet = false
    @State private var editingTask: EventTask? = nil
    @State private var activeEditingTaskId: String? = nil
    @State private var editingTaskTitle: String = ""
    @FocusState private var isTitleFocused: Bool
    @FocusState private var isEditingTaskFocused: Bool

    let isViewerMode: Bool
    private let eventId: String

    private var backgroundColor: Color {
        colorScheme == .dark ? Color(UIColor.systemBackground) : Color(hex: "F2F2F7")
    }

    private var textPrimary: Color {
        colorScheme == .dark ? .white : Color(hex: "0D1017")
    }

    init(eventId: String, isViewerMode: Bool = false) {
        self.eventId = eventId
        _viewModel = StateObject(wrappedValue: TasksViewModel(eventId: eventId, appState: nil))
        self.isViewerMode = isViewerMode
    }

    var body: some View {
        ZStack {
            // Background
            backgroundColor
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Content
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // Title with scroll tracking
                        GeometryReader { geometry in
                            Text(isSelectMode ? (selectedTaskIds.isEmpty ? "Select Tasks" : "\(selectedTaskIds.count) Selected") : "Tasks")
                                .font(.system(size: 34, weight: .semibold, design: .rounded))
                                .foregroundColor(textPrimary)
                                .padding(.horizontal, 16)
                                .onChange(of: geometry.frame(in: .global).minY) { _, newValue in
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        showNavTitle = newValue < 50
                                    }
                                }
                        }
                        .frame(height: 40)
                        .padding(.top, 8)
                        .padding(.bottom, 24)

                        // Tasks Card - Show shimmer while loading, empty state only when truly empty
                        // Use ViewModel's isLoading to track actual loading state
                        if viewModel.isLoading && viewModel.tasks.isEmpty {
                            // Loading with no data - show shimmer
                            TasksShimmerView()
                                .padding(.top, 8)
                        } else if !viewModel.isLoading && viewModel.tasks.isEmpty && !isAddingTask {
                            // Not loading and no tasks - show empty state
                            if isViewerMode {
                                TasksEmptyViewerView()
                            } else {
                                TasksEmptyStateView(onAddTask: { startAddingTask() })
                            }
                        } else if filteredTasks.isEmpty && hideCompleted && !viewModel.tasks.isEmpty {
                            // All tasks completed and "Hide Completed" is on
                            TasksAllCompletedView()
                        } else {
                            TasksCardView(
                                tasks: filteredTasks,
                                isAddingTask: isAddingTask,
                                isSelectMode: isSelectMode,
                                isViewerMode: isViewerMode,
                                selectedTaskIds: $selectedTaskIds,
                                newTaskTitle: $newTaskTitle,
                                newTaskNote: $newTaskNote,
                                isTitleFocused: $isTitleFocused,
                                activeEditingTaskId: $activeEditingTaskId,
                                editingTaskTitle: $editingTaskTitle,
                                isEditingTaskFocused: $isEditingTaskFocused,
                                onTaskToggle: { taskId in
                                    viewModel.toggleTaskStatus(taskId)
                                },
                                onTaskSelect: { taskId in
                                    // Toggle selection without any API call
                                    if selectedTaskIds.contains(taskId) {
                                        selectedTaskIds.remove(taskId)
                                    } else {
                                        selectedTaskIds.insert(taskId)
                                    }
                                },
                                onTaskDelete: { taskId in
                                    viewModel.deleteTask(taskId)
                                },
                                onTaskMove: { taskId, toIndex in
                                    viewModel.moveTask(taskId, toIndex: toIndex)
                                },
                                onTaskTap: { task in
                                    // Start inline editing with animation
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        activeEditingTaskId = task.id
                                        editingTaskTitle = task.title
                                    }
                                    // Set focus after a brief delay to allow animation
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        isEditingTaskFocused = true
                                    }
                                },
                                onTaskTitleSave: { taskId, newTitle in
                                    // Save the edited title
                                    if let task = viewModel.tasks.first(where: { $0.id == taskId }) {
                                        var updatedTask = task
                                        updatedTask.title = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                                        updatedTask.updatedAt = Date()
                                        viewModel.updateTask(updatedTask)
                                    }
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        activeEditingTaskId = nil
                                        editingTaskTitle = ""
                                    }
                                },
                                onInfoTapped: { task in
                                    // Open edit sheet for the active task
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        activeEditingTaskId = nil
                                        isEditingTaskFocused = false
                                    }
                                    editingTask = task
                                },
                                onAddTaskSubmit: submitNewTask,
                                onAddTaskInfoTapped: {
                                    isTitleFocused = false
                                    showTaskDetailSheet = true
                                }
                            )
                            .padding(.horizontal, 16)
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: filteredTasks.count)
                        }
                    }
                    .padding(.bottom, isSelectMode ? 100 : 100)
                }

                // Bottom Action Bar (when in select mode)
                if isSelectMode {
                    SelectModeToolbar(
                        isAllSelected: selectedTaskIds.count == viewModel.tasks.count && !viewModel.tasks.isEmpty,
                        hasSelection: !selectedTaskIds.isEmpty,
                        showCompleteButton: true,
                        canComplete: incompleteSelectedCount > 0,
                        onSelectAll: {
                            withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                                if selectedTaskIds.count == viewModel.tasks.count {
                                    selectedTaskIds.removeAll()
                                } else {
                                    selectedTaskIds = Set(viewModel.tasks.map { $0.id })
                                }
                            }
                        },
                        onDelete: {
                            if !selectedTaskIds.isEmpty {
                                showDeleteSelectedConfirmation = true
                            }
                        },
                        onComplete: {
                            let incompleteSelectedIds = selectedTaskIds.filter { id in
                                viewModel.tasks.first(where: { $0.id == id })?.status != .completed
                            }
                            if !incompleteSelectedIds.isEmpty {
                                viewModel.completeTasks(ids: Array(incompleteSelectedIds))
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    selectedTaskIds.removeAll()
                                    isSelectMode = false
                                }
                            }
                        }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSelectMode)

        }
        .overlay(alignment: .bottomTrailing) {
            // Floating Add Button (only when not in select mode and not viewer)
            if !isSelectMode && !isViewerMode {
                Button(action: { startAddingTask() }) {
                    Image(systemName: "plus")
                }
                .buttonStyle(FloatingAddButtonStyle())
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(isSelectMode ? (selectedTaskIds.isEmpty ? "Select Tasks" : "\(selectedTaskIds.count) Selected") : "Tasks")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(textPrimary)
                    .opacity(showNavTitle ? 1 : 0)
            }
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(textPrimary)
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                if isViewerMode {
                    // No menu for viewers
                    EmptyView()
                } else if isSelectMode {
                    // Done button when in select mode
                    SelectModeCheckmarkButton(hasSelection: !selectedTaskIds.isEmpty) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            isSelectMode = false
                            selectedTaskIds.removeAll()
                        }
                    }
                    .id(selectedTaskIds.count)
                } else {
                    // Menu when not in select mode
                    Menu {
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                isSelectMode = true
                            }
                        }) {
                            Label("Select Tasks", systemImage: "checkmark.circle")
                        }

                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                hideCompleted.toggle()
                            }
                        }) {
                            Label(hideCompleted ? "Show Completed" : "Hide Completed", systemImage: hideCompleted ? "eye" : "eye.slash")
                        }

                        Button(role: .destructive) {
                            showDeleteAllConfirmation = true
                        } label: {
                            Label {
                                Text("Delete All")
                            } icon: {
                                Image("icon_bin_red")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 17))
                            .foregroundColor(textPrimary)
                            .frame(width: 32, height: 32)
                    }
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            // Set up AppState connection
            viewModel.setAppState(appState)
        }
        .task {
            // Load fresh data from backend
            await viewModel.loadTasks()
        }
        .alert("Delete All Tasks?", isPresented: $showDeleteAllConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    viewModel.deleteAllTasks()
                }
            }
        } message: {
            Text("All tasks will be permanently deleted")
        }
        .alert("Delete \(selectedTaskIds.count) Task\(selectedTaskIds.count == 1 ? "" : "s")?", isPresented: $showDeleteSelectedConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    viewModel.deleteTasks(ids: Array(selectedTaskIds))
                    selectedTaskIds.removeAll()
                    isSelectMode = false
                }
            }
        } message: {
            Text("All selected tasks will be permanently deleted")
        }
        .sheet(isPresented: $showTaskDetailSheet) {
            TaskDetailSheet(
                title: $newTaskTitle,
                note: $newTaskNote,
                dueDate: $newTaskDate,
                onSave: {
                    submitNewTask()
                    showTaskDetailSheet = false
                },
                onCancel: {
                    showTaskDetailSheet = false
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.hidden)
        }
        .sheet(item: $editingTask) { task in
            EditTaskSheet(
                task: task,
                onSave: { updatedTask in
                    viewModel.updateTask(updatedTask)
                    editingTask = nil
                },
                onCancel: {
                    editingTask = nil
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.hidden)
        }
        .onChange(of: isEditingTaskFocused) { _, isFocused in
            // Save when focus is lost (user taps outside)
            if !isFocused, let taskId = activeEditingTaskId {
                let trimmedTitle = editingTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmedTitle.isEmpty,
                   let task = viewModel.tasks.first(where: { $0.id == taskId }),
                   trimmedTitle != task.title {
                    var updatedTask = task
                    updatedTask.title = trimmedTitle
                    updatedTask.updatedAt = Date()
                    viewModel.updateTask(updatedTask)
                }
                withAnimation(.easeInOut(duration: 0.2)) {
                    activeEditingTaskId = nil
                    editingTaskTitle = ""
                }
            }
        }
    }

    private var filteredTasks: [EventTask] {
        if hideCompleted {
            return viewModel.sortedTasks.filter { $0.status != .completed }
        }
        return viewModel.sortedTasks
    }

    /// Count of selected tasks that are not yet completed
    private var incompleteSelectedCount: Int {
        selectedTaskIds.filter { id in
            viewModel.tasks.first(where: { $0.id == id })?.status != .completed
        }.count
    }

    private func startAddingTask() {
        // Set state without heavy animation for instant response
        newTaskTitle = ""
        newTaskNote = ""
        isAddingTask = true
        // Focus immediately - no delay for snappy feel
        isTitleFocused = true
    }

    private func cancelAddingTask() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            isAddingTask = false
            newTaskTitle = ""
            newTaskNote = ""
            newTaskDate = nil
        }
        isTitleFocused = false
    }

    private func submitNewTask() {
        let trimmedTitle = newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)

        // If empty, just cancel adding mode
        guard !trimmedTitle.isEmpty else {
            cancelAddingTask()
            return
        }

        let task = EventTask(
            eventId: viewModel.eventId,
            title: trimmedTitle,
            description: newTaskNote.isEmpty ? nil : newTaskNote.trimmingCharacters(in: .whitespacesAndNewlines),
            status: .pending,
            priority: .medium,
            dueDate: newTaskDate,
            createdBy: DIContainer.shared.authService.currentUser?.id ?? ""
        )

        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            viewModel.addTask(task)
        }

        // Clear for next task but keep adding mode active (like iOS Reminders)
        newTaskTitle = ""
        newTaskNote = ""
        newTaskDate = nil
        // Keep focus for continuous task entry
        isTitleFocused = true
    }
}

// MARK: - Task Detail Sheet
struct TaskDetailSheet: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var title: String
    @Binding var note: String
    @Binding var dueDate: Date?
    let onSave: () -> Void
    let onCancel: () -> Void

    @State private var dateEnabled = false
    @State private var timeEnabled = false
    @State private var selectedDate = Date()
    @State private var selectedTime = Date()
    @State private var showDatePicker = false
    @State private var showTimePicker = false
    @FocusState private var titleFocused: Bool
    @FocusState private var noteFocused: Bool

    private let maxNoteLength = 200

    private var backgroundColor: Color {
        colorScheme == .dark ? Color(hex: "1C1C1E") : Color(hex: "F2F2F7")
    }

    private var cardBackground: Color {
        colorScheme == .dark ? Color(hex: "2C2C2E") : .white
    }

    private var textPrimary: Color {
        colorScheme == .dark ? .white : Color(hex: "0D1017")
    }

    private var textSecondary: Color {
        colorScheme == .dark ? Color(hex: "8E8E93") : Color(hex: "9E9EAA")
    }

    private var borderColor: Color {
        colorScheme == .dark ? Color(hex: "3A3A3C") : Color(hex: "E5E7EB")
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        if #available(iOS 26.0, *) {
            iOS26Content
        } else {
            legacyContent
        }
    }

    @available(iOS 26.0, *)
    private var iOS26Content: some View {
        VStack(spacing: 0) {
            // Header with glass effect on iOS 26
            RDSheetHeader(
                title: "Add Task",
                canSave: canSave,
                onDismiss: onCancel,
                onSave: onSave
            )

            ScrollView {
                formContent
            }
        }
        .background(backgroundColor)
        .onAppear(perform: setupInitialState)
    }

    private var legacyContent: some View {
        NavigationStack {
            ZStack {
                backgroundColor.ignoresSafeArea()

                ScrollView {
                    formContent
                }

                // Bottom Save Button
                VStack {
                    Spacer()
                    Button {
                        onSave()
                    } label: {
                        Text("Save")
                    }
                    .rdGradientButtonStyle(isEnabled: canSave)
                    .disabled(!canSave)
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                    .padding(.bottom, 16)
                }
            }
            .navigationTitle("Add Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color(UIColor.systemBackground), for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    RDCloseButton(tint: Color(hex: "A17BF4")) { onCancel() }
                }
            }
        }
        .onAppear(perform: setupInitialState)
    }

    private func setupInitialState() {
        if let existingDate = dueDate {
            dateEnabled = true
            selectedDate = existingDate
            let calendar = Calendar.current
            let hour = calendar.component(.hour, from: existingDate)
            let minute = calendar.component(.minute, from: existingDate)
            if hour != 0 || minute != 0 {
                timeEnabled = true
                selectedTime = existingDate
            }
        }
    }

    private var formContent: some View {
        VStack(spacing: 0) {
            // Title Field
            TextField("Task name", text: $title)
                .font(.system(size: 17, weight: .regular))
                .foregroundColor(textPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(cardBackground)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(borderColor, lineWidth: 1)
                )
                .focused($titleFocused)
                .padding(.horizontal, 16)
                .padding(.top, 24)
                .padding(.bottom, 12)

            // Note Field
            VStack(alignment: .trailing, spacing: 4) {
                ZStack(alignment: .topLeading) {
                    if note.isEmpty {
                        Text("Note")
                            .font(.system(size: 17, weight: .regular))
                            .foregroundColor(textSecondary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                    }
                    TextEditor(text: $note)
                        .font(.system(size: 17, weight: .regular))
                        .foregroundColor(textPrimary)
                        .scrollContentBackground(.hidden)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .focused($noteFocused)
                        .onChange(of: note) { _, newValue in
                            if newValue.count > maxNoteLength {
                                note = String(newValue.prefix(maxNoteLength))
                            }
                        }
                }
                .frame(height: 80)
                .background(cardBackground)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(borderColor, lineWidth: 1)
                )

                Text("\(note.count)/\(maxNoteLength)")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(textSecondary)
                    .padding(.trailing, 4)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)

            // Date Section
            VStack(spacing: 0) {
                // Date Row
                HStack {
                    HStack(spacing: 12) {
                        Image("icon_calendar")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .foregroundColor(Color(hex: "8251EB"))
                            .frame(width: 24, height: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Date")
                                .font(.system(size: 17, weight: .regular))
                                .foregroundColor(textPrimary)

                            if dateEnabled {
                                Text(formattedDate(selectedDate))
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundColor(Color(hex: "8251EB"))
                            }
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if dateEnabled {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showDatePicker.toggle()
                            }
                        }
                    }

                    Spacer()

                    Toggle("", isOn: $dateEnabled)
                        .tint(.rdPrimary)
                        .labelsHidden()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .onChange(of: dateEnabled) { _, enabled in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showDatePicker = enabled
                    }
                    updateDueDate()
                }

                // Date Picker (inline, shown when enabled)
                if dateEnabled && showDatePicker {
                    Rectangle()
                        .fill(borderColor)
                        .frame(height: 1)
                        .padding(.leading, 16)

                    DatePicker(
                        "",
                        selection: $selectedDate,
                        in: Date()...,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .tint(.rdPrimary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                    .onChange(of: selectedDate) { _, _ in
                        updateDueDate()
                    }
                }
            }
            .background(cardBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(borderColor, lineWidth: 1)
            )
            .padding(.horizontal, 16)

            // Time Section
            VStack(spacing: 0) {
                // Time Row
                HStack {
                    HStack(spacing: 12) {
                        Image(systemName: "clock")
                            .font(.system(size: 20))
                            .foregroundColor(Color(hex: "8251EB"))
                            .frame(width: 24, height: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Time")
                                .font(.system(size: 17, weight: .regular))
                                .foregroundColor(textPrimary)

                            if timeEnabled {
                                Text(selectedTime, format: .dateTime.hour().minute())
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundColor(Color(hex: "8251EB"))
                            }
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if timeEnabled {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showTimePicker.toggle()
                            }
                        }
                    }

                    Spacer()

                    Toggle("", isOn: $timeEnabled)
                        .tint(.rdPrimary)
                        .labelsHidden()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .onChange(of: timeEnabled) { _, enabled in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showTimePicker = enabled
                    }
                    updateDueDate()
                }

                // Time Picker (inline, shown when enabled)
                if timeEnabled && showTimePicker {
                    Rectangle()
                        .fill(borderColor)
                        .frame(height: 1)
                        .padding(.leading, 16)

                    DatePicker(
                        "",
                        selection: $selectedTime,
                        displayedComponents: .hourAndMinute
                    )
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
                    .frame(height: 150)
                    .padding(.horizontal, 8)
                    .onChange(of: selectedTime) { _, _ in
                        updateDueDate()
                    }
                }
            }
            .background(cardBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(borderColor, lineWidth: 1)
            )
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .padding(.bottom, 50)
    }

    private func updateDueDate() {
        if dateEnabled {
            let calendar = Calendar.current
            var components = calendar.dateComponents([.year, .month, .day], from: selectedDate)

            if timeEnabled {
                let timeComponents = calendar.dateComponents([.hour, .minute], from: selectedTime)
                components.hour = timeComponents.hour
                components.minute = timeComponents.minute
            } else {
                components.hour = 0
                components.minute = 0
            }

            dueDate = calendar.date(from: components)
        } else {
            dueDate = nil
        }
    }

    private func formattedDate(_ date: Date) -> String { 
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "EEEE, d MMM yyyy"
        return formatter.string(from: date)
    }
}

// MARK: - Edit Task Sheet
struct EditTaskSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    let taskItem: EventTask
    let onSave: (EventTask) -> Void
    let onCancel: () -> Void

    @State private var title: String
    @State private var note: String
    @State private var dueDate: Date?
    @State private var dateEnabled: Bool
    @State private var timeEnabled: Bool
    @State private var selectedDate: Date
    @State private var selectedTime: Date
    @State private var showDatePicker: Bool = false
    @State private var showTimePicker: Bool = false

    init(task: EventTask, onSave: @escaping (EventTask) -> Void, onCancel: @escaping () -> Void) {
        self.taskItem = task
        self.onSave = onSave
        self.onCancel = onCancel
        _title = State(initialValue: task.title)
        _note = State(initialValue: task.description ?? "")
        _dueDate = State(initialValue: task.dueDate)
        _dateEnabled = State(initialValue: task.dueDate != nil)
        _timeEnabled = State(initialValue: false)
        _selectedDate = State(initialValue: task.dueDate ?? Date())
        _selectedTime = State(initialValue: task.dueDate ?? Date())

        // Check if time was set
        if let existingDate = task.dueDate {
            let calendar = Calendar.current
            let hour = calendar.component(.hour, from: existingDate)
            let minute = calendar.component(.minute, from: existingDate)
            _timeEnabled = State(initialValue: hour != 0 || minute != 0)
        }
    }

    private var isFormValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var hasChanges: Bool {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let originalNote = taskItem.description?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        return trimmedTitle != taskItem.title ||
               trimmedNote != originalNote ||
               dueDate != taskItem.dueDate
    }

    private var canSave: Bool {
        isFormValid && hasChanges
    }

    private var backgroundColor: Color {
        .rdBackground
    }

    private var cardBackground: Color {
        .rdBackgroundSecondary
    }

    private var textPrimaryColor: Color {
        colorScheme == .dark ? .white : Color(hex: "0D1017")
    }

    private var textSecondaryColor: Color {
        colorScheme == .dark ? Color(hex: "9E9EAA") : Color(hex: "9E9EAA")
    }

    private var borderColor: Color {
        colorScheme == .dark ? Color(hex: "3A3A3C") : Color(hex: "E5E7EB")
    }

    var body: some View {
        if #available(iOS 26.0, *) {
            // iOS 26+ with custom glass header
            ZStack {
                backgroundColor.ignoresSafeArea()

                VStack(spacing: 0) {
                    RDSheetHeader(
                        title: "Edit Task",
                        canSave: canSave,
                        onDismiss: { dismiss() },
                        onSave: {
                            saveTask()
                            dismiss()
                        }
                    )

                    ScrollView {
                        VStack(spacing: 0) {
                            // Title Section
                            TextField("Title", text: $title)
                                .font(.system(size: 17, weight: .regular))
                                .foregroundColor(textPrimaryColor)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .background(cardBackground)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(borderColor, lineWidth: 1)
                                )
                                .padding(.top, 24)
                                .padding(.bottom, 12)

                            // Note Section
                            VStack(alignment: .leading, spacing: 4) {
                                TextField("Note", text: $note, axis: .vertical)
                                    .font(.system(size: 17, weight: .regular))
                                    .foregroundColor(note.isEmpty ? textSecondaryColor : textPrimaryColor)
                                    .lineLimit(3...6)
                                    .onChange(of: note) { _, newValue in
                                        if newValue.count > 200 {
                                            note = String(newValue.prefix(200))
                                        }
                                    }

                                HStack {
                                    Spacer()
                                    Text("\(note.count)/200")
                                        .font(.system(size: 13, weight: .regular))
                                        .foregroundColor(note.count >= 200 ? Color(hex: "DB4F47") : textSecondaryColor)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .frame(minHeight: 100, alignment: .topLeading)
                            .background(cardBackground)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(note.count >= 200 ? Color(hex: "DB4F47") : borderColor, lineWidth: 1)
                            )
                            .padding(.bottom, 12)

                            // Date & Time Section (combined card)
                            VStack(spacing: 0) {
                                // Date Row
                                HStack {
                                    HStack(spacing: 12) {
                                        Image("icon_calendar")
                                            .renderingMode(.template)
                                            .resizable()
                                            .scaledToFit()
                                            .foregroundColor(Color(hex: "8251EB"))
                                            .frame(width: 24, height: 24)

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Date")
                                                .font(.system(size: 17, weight: .regular))
                                                .foregroundColor(textPrimaryColor)

                                            if dateEnabled {
                                                Text(formattedDate(selectedDate))
                                                    .font(.system(size: 13, weight: .regular))
                                                    .foregroundColor(Color(hex: "8251EB"))
                                            }
                                        }
                                    }
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        if dateEnabled {
                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                showDatePicker.toggle()
                                                showTimePicker = false
                                            }
                                        }
                                    }

                                    Spacer()

                                    Toggle("", isOn: $dateEnabled)
                                        .tint(.rdPrimary)
                                        .labelsHidden()
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .onChange(of: dateEnabled) { _, enabled in
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        showDatePicker = enabled
                                        if !enabled {
                                            showTimePicker = false
                                        }
                                    }
                                    updateDueDate()
                                }

                                // Date Picker (inline, shown when enabled)
                                if dateEnabled && showDatePicker {
                                    Rectangle()
                                        .fill(borderColor)
                                        .frame(height: 1)
                                        .padding(.leading, 16)

                                    DatePicker(
                                        "",
                                        selection: $selectedDate,
                                        in: Date()...,
                                        displayedComponents: .date
                                    )
                                    .datePickerStyle(.graphical)
                                    .tint(.rdPrimary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 8)
                                    .onChange(of: selectedDate) { _, _ in
                                        updateDueDate()
                                    }
                                }

                                // Divider between Date and Time
                                Rectangle()
                                    .fill(borderColor)
                                    .frame(height: 1)
                                    .padding(.leading, 16)

                                // Time Row
                                HStack {
                                    HStack(spacing: 12) {
                                        Image(systemName: "clock")
                                            .font(.system(size: 20))
                                            .foregroundColor(Color(hex: "8251EB"))
                                            .frame(width: 24, height: 24)

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Time")
                                                .font(.system(size: 17, weight: .regular))
                                                .foregroundColor(textPrimaryColor)

                                            if timeEnabled {
                                                Text(selectedTime, format: .dateTime.hour().minute())
                                                    .font(.system(size: 13, weight: .regular))
                                                    .foregroundColor(Color(hex: "8251EB"))
                                            }
                                        }
                                    }
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        if timeEnabled {
                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                showTimePicker.toggle()
                                                showDatePicker = false
                                            }
                                        }
                                    }

                                    Spacer()

                                    Toggle("", isOn: $timeEnabled)
                                        .tint(.rdPrimary)
                                        .labelsHidden()
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .onChange(of: timeEnabled) { _, enabled in
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        showTimePicker = enabled
                                        if enabled {
                                            showDatePicker = false
                                        }
                                    }
                                    updateDueDate()
                                }

                                // Time Picker (inline, shown when enabled)
                                if timeEnabled && showTimePicker {
                                    Rectangle()
                                        .fill(borderColor)
                                        .frame(height: 1)
                                        .padding(.leading, 16)

                                    DatePicker(
                                        "",
                                        selection: $selectedTime,
                                        displayedComponents: .hourAndMinute
                                    )
                                    .datePickerStyle(.wheel)
                                    .labelsHidden()
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 180)
                                    .padding(.horizontal, 8)
                                    .onChange(of: selectedTime) { _, _ in
                                        updateDueDate()
                                    }
                                }
                            }
                            .background(cardBackground)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(borderColor, lineWidth: 1)
                            )

                            Spacer().frame(height: 50)
                        }
                        .padding(.horizontal, 16)
                    }
                }
            }
        } else {
            // Pre-iOS 26 with standard navigation
            NavigationStack {
                ZStack {
                    backgroundColor.ignoresSafeArea()

                    ScrollView {
                        VStack(spacing: 0) {
                        // Title Section
                        TextField("Title", text: $title)
                            .font(.system(size: 17, weight: .regular))
                            .foregroundColor(textPrimaryColor)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(cardBackground)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(borderColor, lineWidth: 1)
                            )
                            .padding(.top, 24)
                            .padding(.bottom, 12)

                        // Note Section
                        VStack(alignment: .leading, spacing: 4) {
                            TextField("Note", text: $note, axis: .vertical)
                                .font(.system(size: 17, weight: .regular))
                                .foregroundColor(note.isEmpty ? textSecondaryColor : textPrimaryColor)
                                .lineLimit(3...6)
                                .onChange(of: note) { _, newValue in
                                    if newValue.count > 200 {
                                        note = String(newValue.prefix(200))
                                    }
                                }

                            HStack {
                                Spacer()
                                Text("\(note.count)/200")
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundColor(note.count >= 200 ? Color(hex: "DB4F47") : textSecondaryColor)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .frame(minHeight: 100, alignment: .topLeading)
                        .background(cardBackground)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(note.count >= 200 ? Color(hex: "DB4F47") : borderColor, lineWidth: 1)
                        )
                        .padding(.bottom, 12)

                        // Date & Time Section (combined card)
                        VStack(spacing: 0) {
                            // Date Row
                            HStack {
                                HStack(spacing: 12) {
                                    Image("icon_calendar")
                                        .renderingMode(.template)
                                        .resizable()
                                        .scaledToFit()
                                        .foregroundColor(Color(hex: "8251EB"))
                                        .frame(width: 24, height: 24)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Date")
                                            .font(.system(size: 17, weight: .regular))
                                            .foregroundColor(textPrimaryColor)

                                        if dateEnabled {
                                            Text(formattedDate(selectedDate))
                                                .font(.system(size: 13, weight: .regular))
                                                .foregroundColor(Color(hex: "8251EB"))
                                        }
                                    }
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if dateEnabled {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            showDatePicker.toggle()
                                            showTimePicker = false
                                        }
                                    }
                                }

                                Spacer()

                                Toggle("", isOn: $dateEnabled)
                                    .tint(.rdPrimary)
                                    .labelsHidden()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .onChange(of: dateEnabled) { _, enabled in
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    showDatePicker = enabled
                                    if !enabled {
                                        showTimePicker = false
                                    }
                                }
                                updateDueDate()
                            }

                            // Date Picker (inline, shown when enabled)
                            if dateEnabled && showDatePicker {
                                Rectangle()
                                    .fill(borderColor)
                                    .frame(height: 1)
                                    .padding(.leading, 16)

                                DatePicker(
                                    "",
                                    selection: $selectedDate,
                                    in: Date()...,
                                    displayedComponents: .date
                                )
                                .datePickerStyle(.graphical)
                                .tint(.rdPrimary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 8)
                                .onChange(of: selectedDate) { _, _ in
                                    updateDueDate()
                                }
                            }

                            // Divider between Date and Time
                            Rectangle()
                                .fill(borderColor)
                                .frame(height: 1)
                                .padding(.leading, 16)

                            // Time Row
                            HStack {
                                HStack(spacing: 12) {
                                    Image(systemName: "clock")
                                        .font(.system(size: 20))
                                        .foregroundColor(Color(hex: "8251EB"))
                                        .frame(width: 24, height: 24)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Time")
                                            .font(.system(size: 17, weight: .regular))
                                            .foregroundColor(textPrimaryColor)

                                        if timeEnabled {
                                            Text(selectedTime, format: .dateTime.hour().minute())
                                                .font(.system(size: 13, weight: .regular))
                                                .foregroundColor(Color(hex: "8251EB"))
                                        }
                                    }
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if timeEnabled {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            showTimePicker.toggle()
                                            showDatePicker = false
                                        }
                                    }
                                }

                                Spacer()

                                Toggle("", isOn: $timeEnabled)
                                    .tint(.rdPrimary)
                                    .labelsHidden()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .onChange(of: timeEnabled) { _, enabled in
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    showTimePicker = enabled
                                    if enabled {
                                        showDatePicker = false
                                    }
                                }
                                updateDueDate()
                            }

                            // Time Picker (inline, shown when enabled)
                            if timeEnabled && showTimePicker {
                                Rectangle()
                                    .fill(borderColor)
                                    .frame(height: 1)
                                    .padding(.leading, 16)

                                DatePicker(
                                    "",
                                    selection: $selectedTime,
                                    displayedComponents: .hourAndMinute
                                )
                                .datePickerStyle(.wheel)
                                .labelsHidden()
                                .frame(maxWidth: .infinity)
                                .frame(height: 180)
                                .padding(.horizontal, 8)
                                .onChange(of: selectedTime) { _, _ in
                                    updateDueDate()
                                }
                            }
                        }
                        .background(cardBackground)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(borderColor, lineWidth: 1)
                        )

                        Spacer().frame(height: 100)
                    }
                    .padding(.horizontal, 16)
                }

                // Bottom Save Button
                VStack {
                    Spacer()
                    Button {
                        saveTask()
                        dismiss()
                    } label: {
                        Text("Save")
                    }
                    .rdGradientButtonStyle(isEnabled: isFormValid)
                    .disabled(!isFormValid)
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                    .padding(.bottom, 16)
                }
            }
            .navigationTitle("Edit Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color(UIColor.systemBackground), for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    RDCloseButton(tint: Color(hex: "A17BF4")) { dismiss() }
                }
            }
        }
        }
    }

    private func updateDueDate() {
        if dateEnabled {
            let calendar = Calendar.current
            var components = calendar.dateComponents([.year, .month, .day], from: selectedDate)

            if timeEnabled {
                let timeComponents = calendar.dateComponents([.hour, .minute], from: selectedTime)
                components.hour = timeComponents.hour
                components.minute = timeComponents.minute
            } else {
                components.hour = 0
                components.minute = 0
            }

            dueDate = calendar.date(from: components)
        } else {
            dueDate = nil
        }
    }

    private func saveTask() {
        var updatedTask = taskItem
        updatedTask.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        updatedTask.description = note.isEmpty ? nil : note.trimmingCharacters(in: .whitespacesAndNewlines)
        updatedTask.dueDate = dueDate
        updatedTask.updatedAt = Date()
        onSave(updatedTask)
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "EEEE, d MMM yyyy"
        return formatter.string(from: date)
    }
}

// MARK: - Tasks Card View
struct TasksCardView: View {
    @Environment(\.colorScheme) private var colorScheme
    let tasks: [EventTask]
    let isAddingTask: Bool
    let isSelectMode: Bool
    let isViewerMode: Bool
    @Binding var selectedTaskIds: Set<String>
    @Binding var newTaskTitle: String
    @Binding var newTaskNote: String
    var isTitleFocused: FocusState<Bool>.Binding
    @Binding var activeEditingTaskId: String?
    @Binding var editingTaskTitle: String
    var isEditingTaskFocused: FocusState<Bool>.Binding
    let onTaskToggle: (String) -> Void
    let onTaskSelect: (String) -> Void
    let onTaskDelete: (String) -> Void
    let onTaskMove: (String, Int) -> Void
    let onTaskTap: (EventTask) -> Void
    let onTaskTitleSave: (String, String) -> Void
    let onInfoTapped: (EventTask) -> Void
    let onAddTaskSubmit: () -> Void
    let onAddTaskInfoTapped: () -> Void

    // Custom drag state
    @State private var draggedTask: EventTask?
    @State private var dragOffset: CGSize = .zero
    @State private var dragStartY: CGFloat = 0
    @State private var draggedRowOriginY: CGFloat = 0
    @State private var rowHeights: [String: CGFloat] = [:]
    @State private var rowOrigins: [String: CGFloat] = [:]
    @State private var currentTargetIndex: Int?
    @State private var isReordering: Bool = false
    @GestureState private var isDragging: Bool = false

    private var cardBackground: Color {
        colorScheme == .dark ? Color(hex: "2C2C2E") : .white
    }

    private var separatorColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.15) : Color(hex: "181818").opacity(0.24)
    }

    private var dropIndicatorColor: Color {
        Color(hex: "A17BF4")
    }

    // Get incomplete tasks for drag reordering - sorted by order to match ViewModel
    private var incompleteTasks: [EventTask] {
        tasks.filter { $0.status != .completed }.sorted { $0.order < $1.order }
    }

    var body: some View {
        ZStack {
            // Main content
            VStack(spacing: 0) {
                // Inline Add Task Row (at top when adding, not in viewer mode)
                if isAddingTask && !isViewerMode {
                    AddTaskInlineRow(
                        title: $newTaskTitle,
                        note: $newTaskNote,
                        isTitleFocused: isTitleFocused,
                        onSubmit: onAddTaskSubmit,
                        onInfoTapped: onAddTaskInfoTapped
                    )
                    .transition(.opacity.animation(.easeOut(duration: 0.15)))

                    // Separator
                    if !tasks.isEmpty {
                        Rectangle()
                            .fill(separatorColor)
                            .frame(height: 0.5)
                            .padding(.leading, isViewerMode ? 16 : 52)
                    }
                }

                // Existing Tasks
                ForEach(Array(tasks.enumerated()), id: \.element.id) { index, task in
                    VStack(spacing: 0) {
                        // Drop indicator above this row
                        if let targetIdx = currentTargetIndex,
                           let draggedTaskItem = draggedTask,
                           task.status != .completed {
                            let incompleteIndex = incompleteTasks.firstIndex(where: { $0.id == task.id }) ?? 0
                            if incompleteIndex == targetIdx && draggedTaskItem.id != task.id {
                                DropIndicatorView()
                                    .transition(.scale.combined(with: .opacity))
                            }
                        }

                        TaskRowView(
                            task: task,
                            isSelectMode: isSelectMode,
                            isViewerMode: isViewerMode,
                            isSelected: selectedTaskIds.contains(task.id),
                            isDragging: draggedTask?.id == task.id,
                            isEditing: activeEditingTaskId == task.id,
                            editingTitle: $editingTaskTitle,
                            isEditingFocused: isEditingTaskFocused,
                            onToggle: { onTaskToggle(task.id) },
                            onSelect: { onTaskSelect(task.id) },
                            onDelete: { onTaskDelete(task.id) },
                            onTap: { onTaskTap(task) },
                            onTitleSave: { newTitle in onTaskTitleSave(task.id, newTitle) },
                            onInfoTapped: { onInfoTapped(task) }
                        )
                        .background(
                            GeometryReader { geo in
                                Color.clear
                                    .onAppear {
                                        rowHeights[task.id] = geo.size.height
                                        rowOrigins[task.id] = geo.frame(in: .named("tasksList")).minY
                                    }
                                    .onChange(of: geo.frame(in: .named("tasksList")).minY) { _, newY in
                                        rowOrigins[task.id] = newY
                                    }
                            }
                        )
                        .if(isSelectMode && !isViewerMode && task.status != .completed) { view in
                            view.gesture(
                                LongPressGesture(minimumDuration: 0.2)
                                    .sequenced(before: DragGesture(coordinateSpace: .named("tasksList")))
                                    .updating($isDragging) { value, state, _ in
                                        switch value {
                                        case .second(true, _):
                                            state = true
                                        default:
                                            break
                                        }
                                    }
                                    .onChanged { value in
                                        switch value {
                                        case .second(true, let drag):
                                            if let drag = drag {
                                                if draggedTask == nil {
                                                    // Start drag - capture the row's origin
                                                    draggedRowOriginY = rowOrigins[task.id] ?? 0
                                                    dragStartY = drag.startLocation.y
                                                    withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                                                        draggedTask = task
                                                    }
                                                    // Haptic feedback
                                                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                                    impactFeedback.impactOccurred()
                                                }
                                                // Update position without animation for responsive feel
                                                dragOffset = drag.translation
                                                updateTargetIndex(currentY: drag.location.y)
                                            }
                                        default:
                                            break
                                        }
                                    }
                                    .onEnded { value in
                                        if let targetIdx = currentTargetIndex,
                                           let draggedTaskItem = draggedTask {
                                            // Disable animations during reorder
                                            isReordering = true
                                            // Convert visual index to logical index for moveTask
                                            let adjustedIdx = adjustedTargetIndex(targetIdx)
                                            onTaskMove(draggedTaskItem.id, adjustedIdx)
                                            // Re-enable after a brief moment
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                                isReordering = false
                                            }
                                        }
                                        // Reset drag state immediately (no animation)
                                        draggedTask = nil
                                        dragOffset = .zero
                                        currentTargetIndex = nil
                                        draggedRowOriginY = 0
                                        dragStartY = 0
                                    }
                            )
                        }
                    }

                    // Separator (not after last item)
                    if index < tasks.count - 1 {
                        Rectangle()
                            .fill(separatorColor)
                            .frame(height: 0.5)
                            .padding(.leading, isViewerMode ? 16 : 52)
                    }
                }

                // Drop indicator at the end
                if let targetIdx = currentTargetIndex,
                   targetIdx == incompleteTasks.count,
                   draggedTask != nil {
                    DropIndicatorView()
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .background(cardBackground)
            .cornerRadius(12)
            .animation(isReordering ? nil : .easeOut(duration: 0.15), value: isAddingTask)
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: currentTargetIndex)
            .coordinateSpace(name: "tasksList")

            // Dragged row overlay - positioned to follow finger
            if let draggedTaskItem = draggedTask {
                GeometryReader { geo in
                    TaskDragPreview(
                        title: draggedTaskItem.title,
                        description: draggedTaskItem.description,
                        isLifted: true
                    )
                    .padding(.horizontal, 16)
                    .position(
                        x: geo.size.width / 2,
                        y: draggedRowOriginY + (rowHeights[draggedTaskItem.id] ?? 60) / 2 + dragOffset.height
                    )
                }
                .zIndex(100)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.95).combined(with: .opacity),
                    removal: .opacity
                ))
                .animation(.spring(response: 0.2, dampingFraction: 0.8), value: draggedTask?.id)
            }
        }
    }

    private func updateTargetIndex(currentY: CGFloat) {
        // Use the same ordering as ViewModel's moveTask - sorted by order field
        let sortedIncompleteTasks = incompleteTasks

        guard let draggedTaskItem = draggedTask,
              let draggedIndex = sortedIncompleteTasks.firstIndex(where: { $0.id == draggedTaskItem.id }) else {
            return
        }

        // Calculate which position we're hovering over based on Y position
        var cumulativeHeight: CGFloat = 0
        var newTargetIndex: Int? = nil

        for (index, task) in sortedIncompleteTasks.enumerated() {
            let rowHeight = rowHeights[task.id] ?? 60
            let rowMidpoint = cumulativeHeight + rowHeight / 2

            if currentY < rowMidpoint {
                newTargetIndex = index
                break
            }
            cumulativeHeight += rowHeight
        }

        // If we're past all rows, target the end
        if newTargetIndex == nil && !sortedIncompleteTasks.isEmpty {
            newTargetIndex = sortedIncompleteTasks.count
        }

        // Skip if hovering over the dragged item's current position or right after it
        if let targetIdx = newTargetIndex {
            if targetIdx == draggedIndex || targetIdx == draggedIndex + 1 {
                newTargetIndex = nil
            }
        }

        if currentTargetIndex != newTargetIndex {
            // Haptic feedback when target changes
            if newTargetIndex != nil {
                let selectionFeedback = UISelectionFeedbackGenerator()
                selectionFeedback.selectionChanged()
            }
            withAnimation(.easeInOut(duration: 0.15)) {
                currentTargetIndex = newTargetIndex
            }
        }
    }

    // Convert visual target index to the index expected by moveTask
    private func adjustedTargetIndex(_ visualIndex: Int) -> Int {
        guard let draggedTaskItem = draggedTask,
              let draggedIndex = incompleteTasks.firstIndex(where: { $0.id == draggedTaskItem.id }) else {
            return visualIndex
        }

        // When moving down, subtract 1 because the item will be removed first
        if visualIndex > draggedIndex {
            return visualIndex - 1
        }
        return visualIndex
    }
}

// MARK: - Drop Indicator View
struct DropIndicatorView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color(hex: "A17BF4"))
                .frame(width: 8, height: 8)

            Rectangle()
                .fill(Color(hex: "A17BF4"))
                .frame(height: 2)

            Circle()
                .fill(Color(hex: "A17BF4"))
                .frame(width: 8, height: 8)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }
}

// MARK: - Task Drag Preview
struct TaskDragPreview: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let description: String?
    var isLifted: Bool = true

    private var backgroundColor: Color {
        colorScheme == .dark ? Color(hex: "3A3A3C") : .white
    }

    private var textPrimary: Color {
        colorScheme == .dark ? .white : Color(hex: "0D1017")
    }

    private var textSecondary: Color {
        colorScheme == .dark ? Color(hex: "8E8E93") : Color(hex: "9E9EAA")
    }

    var body: some View {
        HStack(spacing: 12) {
            // Checkbox placeholder
            Circle()
                .stroke(colorScheme == .dark ? Color(hex: "48484A") : Color(hex: "CCD2E3"), lineWidth: 1.5)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 17, weight: .regular))
                    .foregroundColor(textPrimary)
                    .lineLimit(1)

                if let desc = description, !desc.isEmpty {
                    Text(desc)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Drag handle
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(colorScheme == .dark ? Color(hex: "636366") : Color(hex: "C7C7CC"))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(backgroundColor)
        .cornerRadius(12)
        .shadow(color: .black.opacity(isLifted ? 0.25 : 0), radius: isLifted ? 20 : 0, x: 0, y: isLifted ? 10 : 0)
        .scaleEffect(isLifted ? 1.02 : 1.0)
    }
}

// MARK: - Add Task Inline Row
struct AddTaskInlineRow: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var title: String
    @Binding var note: String
    var isTitleFocused: FocusState<Bool>.Binding
    let onSubmit: () -> Void
    let onInfoTapped: () -> Void

    private var textPrimary: Color {
        colorScheme == .dark ? .white : Color(hex: "0D1017")
    }

    private var textSecondary: Color {
        colorScheme == .dark ? Color(hex: "8E8E93") : Color(hex: "9E9EAA")
    }

    private var checkboxStroke: Color {
        colorScheme == .dark ? Color(hex: "48484A") : Color(hex: "CCD2E3")
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Empty circle checkbox
            Circle()
                .stroke(checkboxStroke, lineWidth: 1.5)
                .frame(width: 24, height: 24)

            // Content
            VStack(alignment: .leading, spacing: 2) {
                // Title TextField
                TextField("Enter Task", text: $title)
                    .font(.system(size: 17, weight: .regular))
                    .foregroundColor(textPrimary)
                    .tracking(-0.44)
                    .focused(isTitleFocused)
                    .submitLabel(.return)
                    .onSubmit {
                        onSubmit()
                    }

                // Note placeholder
                Text("Add Note")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(textSecondary)
                    .tracking(-0.08)
            }

            Spacer()

            // Info button
            Button(action: onInfoTapped) {
                Image(systemName: "info.circle")
                    .font(.system(size: 22, weight: .regular))
                    .foregroundColor(Color(hex: "A17BF4"))
            }
        }
        .padding(.leading, 16)
        .padding(.trailing, 12)
        .padding(.vertical, 11)
    }
}

// MARK: - Task Row View
struct TaskRowView: View {
    @Environment(\.colorScheme) private var colorScheme
    let task: EventTask
    let isSelectMode: Bool
    let isViewerMode: Bool
    let isSelected: Bool
    let isDragging: Bool
    let isEditing: Bool
    @Binding var editingTitle: String
    var isEditingFocused: FocusState<Bool>.Binding
    let onToggle: () -> Void
    let onSelect: () -> Void
    let onDelete: () -> Void
    let onTap: () -> Void
    let onTitleSave: (String) -> Void
    let onInfoTapped: () -> Void

    private var textPrimary: Color {
        colorScheme == .dark ? .white : Color(hex: "0D1017")
    }

    private var textSecondary: Color {
        colorScheme == .dark ? Color(hex: "8E8E93") : Color(hex: "9E9EAA")
    }

    private var checkboxStroke: Color {
        colorScheme == .dark ? Color(hex: "48484A") : Color(hex: "CCD2E3")
    }

    private var dragHandleColor: Color {
        colorScheme == .dark ? Color(hex: "636366") : Color(hex: "C7C7CC")
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Checkbox (different behavior for viewer mode)
            if isViewerMode {
                // Viewer mode: only show checkmark for completed tasks
                if task.status == .completed {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(Color(hex: "8251EB"))
                }
                // No checkbox for uncompleted tasks in viewer mode
            } else {
                // Owner mode: interactive checkboxes
                checkboxView
            }

            // Content
            VStack(alignment: .leading, spacing: 0) {
                // Title - TextField when editing, Text otherwise
                if isEditing {
                    TextField("Task name", text: $editingTitle)
                        .font(.system(size: 17, weight: .regular))
                        .foregroundColor(task.status == .completed ? textSecondary : textPrimary)
                        .tracking(-0.44)
                        .focused(isEditingFocused)
                        .submitLabel(.done)
                        .onSubmit {
                            onTitleSave(editingTitle)
                        }

                    // Add Note placeholder (when editing and no description)
                    if task.description == nil || task.description?.isEmpty == true {
                        Text("Add Note")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(Color(hex: "9E9EAA"))
                            .tracking(-0.08)
                    } else if let description = task.description, !description.isEmpty {
                        // Show existing description
                        Text(description)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(textSecondary)
                            .tracking(-0.08)
                            .lineLimit(1)
                    }
                } else {
                    Text(task.title)
                        .font(.system(size: 17, weight: .regular))
                        .foregroundColor(task.status == .completed ? textSecondary : textPrimary)
                        .tracking(-0.44)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)

                    // Description (if exists, only shown when not editing)
                    if let description = task.description, !description.isEmpty {
                        Text(description)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(textSecondary)
                            .tracking(-0.08)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    // Due Date Badge (if exists, not shown in viewer mode)
                    if let dueDate = task.dueDate, !isViewerMode {
                        DueDateBadge(date: dueDate, isCompleted: task.status == .completed)
                            .padding(.top, 8)
                    }
                }
            }

            Spacer()

            // Info icon (only when editing this row)
            if isEditing && !isViewerMode {
                Button(action: onInfoTapped) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 22, weight: .regular))
                        .foregroundColor(Color(hex: "A17BF4"))
                }
                .buttonStyle(.plain)
            }

            // Drag handle (only in select mode, not viewer mode)
            if isSelectMode && !isViewerMode {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(dragHandleColor)
            }
        }
        .padding(.leading, 16)
        .padding(.trailing, 12)
        .padding(.vertical, 11)
        .contentShape(Rectangle())
        .animation(.easeInOut(duration: 0.2), value: isEditing)
        .opacity(isDragging ? 0.3 : 1.0)
        .background(
            Group {
                if isSelected && isSelectMode {
                    // Gray background for selected rows
                    Color(hex: "9C9CA6").opacity(0.15)
                } else if isDragging {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.03))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                }
            }
        )
        .onTapGesture {
            if isSelectMode && !isViewerMode {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                    onSelect()
                }
            } else if !isViewerMode && !isEditing {
                // Start inline editing when tapping the row
                onTap()
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            if !isSelectMode && !isViewerMode {
                Button(role: .destructive, action: onDelete) {
                    Label {
                        Text("Delete")
                    } icon: {
                        Image("icon_swipe_bin")
                            .renderingMode(.template)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var checkboxView: some View {
        if isSelectMode {
            // Selection mode checkbox - just visual, tap is handled by row's onTapGesture
            if isSelected {
                // Purple checkmark for selected rows
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(Color(hex: "8251EB"))
            } else if task.status == .completed {
                // Gray checkmark for completed but not selected
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(Color(hex: "9C9CA6").opacity(0.5))
            } else {
                // Empty circle for incomplete tasks
                Circle()
                    .stroke(checkboxStroke, lineWidth: 1.5)
                    .frame(width: 24, height: 24)
            }
        } else {
            // Normal mode - checkbox is a button that toggles task completion
            Button(action: {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                    onToggle()
                }
            }) {
                if task.status == .completed {
                    // Purple filled checkmark
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(Color(hex: "8251EB"))
                } else {
                    // Empty circle
                    Circle()
                        .stroke(checkboxStroke, lineWidth: 1.5)
                        .frame(width: 24, height: 24)
                }
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Due Date Badge
struct DueDateBadge: View {
    @Environment(\.colorScheme) private var colorScheme
    let date: Date
    let isCompleted: Bool

    private var isOverdue: Bool {
        date < Date() && !isCompleted
    }

    private var badgeColor: Color {
        isOverdue ? Color(hex: "DB4F47") : Color(hex: "A17BF4")
    }

    private var iconName: String {
        isOverdue ? "exclamationmark.circle" : "clock"
    }

    private var badgeBackground: Color {
        colorScheme == .dark ? Color(hex: "3A3A3C") : Color(hex: "9C9CA6").opacity(0.1)
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: iconName)
                .font(.system(size: 12))
            Text(formattedDate)
                .font(.system(size: 13, weight: .regular))
                .tracking(-0.08)
        }
        .foregroundColor(badgeColor)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(badgeBackground)
        .cornerRadius(8)
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "d MMM, HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - Tasks Empty State View (Owner)
struct TasksEmptyStateView: View {
    @Environment(\.colorScheme) private var colorScheme
    let onAddTask: () -> Void

    private var textSecondary: Color {
        colorScheme == .dark ? Color(hex: "A1A1A6") : Color(hex: "83828D")
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 24) {
                Image("tasks_empty")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 184, height: 156)

                Text("Add Your First Task\nCreate to-do list to stay organized")
                    .font(.system(size: 15, weight: .regular))
                    .lineSpacing(0)
                    .foregroundColor(textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2 - 40)
        }
        .frame(height: UIScreen.main.bounds.height - 250)
        .padding(.horizontal, 24)
    }
}

// MARK: - Tasks Empty Viewer View (Read-only)
struct TasksEmptyViewerView: View {
    @Environment(\.colorScheme) private var colorScheme

    private var textSecondary: Color {
        colorScheme == .dark ? Color(hex: "A1A1A6") : Color(hex: "83828D")
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 24) {
                Image("tasks_empty")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 184, height: 156)

                Text("No Tasks Yet\nThe host hasn't added any tasks")
                    .font(.system(size: 15, weight: .regular))
                    .lineSpacing(0)
                    .foregroundColor(textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2 - 40)
        }
        .frame(height: UIScreen.main.bounds.height - 250)
        .padding(.horizontal, 24)
    }
}

// MARK: - Tasks All Completed View
struct TasksAllCompletedView: View {
    @Environment(\.colorScheme) private var colorScheme

    private var textSecondary: Color {
        colorScheme == .dark ? Color(hex: "A1A1A6") : Color(hex: "83828D")
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 16) {
                Image("tasks_all_completed")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 205, height: 205)

                Text("All Tasks Completed")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2 - 40)
        }
        .frame(height: UIScreen.main.bounds.height - 250)
        .padding(.horizontal, 24)
    }
}

// MARK: - View Model
@MainActor
class TasksViewModel: ObservableObject {
    let eventId: String

    @Published var tasks: [EventTask] = []
    @Published var isLoading = true  // Start with loading true to show shimmer
    @Published var isInitialized = false  // Tracks if data has been loaded at least once

    // Track task IDs that are still being synced (local IDs not yet replaced with server IDs)
    private var pendingSyncTaskIds: Set<String> = []

    private let taskRepository: TaskRepositoryProtocol
    private weak var appState: AppState?
    private var cancellables = Set<AnyCancellable>()

    init(eventId: String, appState: AppState? = nil) {
        self.eventId = eventId
        self.taskRepository = DIContainer.shared.taskRepository
        self.appState = appState

        // Load cached data from AppState immediately (no jumping)
        if let appState = appState {
            self.tasks = appState.tasks(for: eventId)
            subscribeToAppState(appState)
        }
    }

    /// Set AppState reference and subscribe to updates (called from View's onAppear)
    func setAppState(_ appState: AppState) {
        // Always check current cache state to determine loading
        let cachedTasks = appState.tasks(for: eventId)
        if !cachedTasks.isEmpty {
            self.tasks = cachedTasks
            // We have cached data, so hide shimmer
            isLoading = false
            isInitialized = true
        } else {
            // No cache, ensure shimmer shows
            isLoading = true
        }

        // Only set up subscription once
        guard self.appState == nil else { return }
        self.appState = appState
        subscribeToAppState(appState)
    }

    private func subscribeToAppState(_ appState: AppState) {
        // Subscribe to AppState changes for real-time updates (push notifications)
        appState.$tasksByEvent
            .map { [eventId] in $0[eventId] ?? [] }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] tasks in
                guard let self = self else { return }
                // Only update if different to avoid loops
                if self.tasks != tasks {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        self.tasks = tasks
                    }
                    // Reset loading state when cache is cleared (to show shimmer)
                    // But NOT if already initialized (e.g. user deleted all items)
                    if tasks.isEmpty && !self.isInitialized {
                        self.isLoading = true
                    }
                }
            }
            .store(in: &cancellables)
    }

    /// Tasks sorted by order field (descending - higher order first), with completed tasks at the bottom
    var sortedTasks: [EventTask] {
        let incomplete = tasks.filter { $0.status != .completed }
            .sorted { $0.order < $1.order }
        let completed = tasks.filter { $0.status == .completed }
            .sorted { $0.order < $1.order }
        return incomplete + completed
    }

    func loadTasks() async {
        // Use AppState to load (which handles caching)
        if let appState = appState {
            await appState.loadTasks(for: eventId)
            // Sync local state with AppState cache BEFORE hiding shimmer
            let cachedTasks = appState.tasks(for: eventId)
            if tasks != cachedTasks {
                withAnimation(.easeInOut(duration: 0.2)) {
                    tasks = cachedTasks
                }
            }
        } else {
            // Fallback: load directly without AppState
            do {
                let freshTasks = try await taskRepository.getTasksForEvent(eventId: eventId)
                withAnimation(.easeInOut(duration: 0.2)) {
                    tasks = freshTasks
                }
            } catch {
                // Load failed
            }
        }

        // Hide shimmer AFTER tasks is updated
        isLoading = false
        isInitialized = true
    }

    func toggleTaskStatus(_ taskId: String) {
        // Optimistic update - update UI immediately
        guard let index = tasks.firstIndex(where: { $0.id == taskId }) else { return }
        let originalTask = tasks[index]
        let newStatus: TaskStatus = originalTask.status == .completed ? .pending : .completed

        // Haptic feedback when completing a task
        if newStatus == .completed {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }

        // Update local state immediately for instant feedback
        var updatedTask = tasks[index]
        updatedTask.status = newStatus
        updatedTask.updatedAt = Date()

        withAnimation(.easeInOut(duration: 0.2)) {
            tasks[index] = updatedTask
            appState?.updateTask(updatedTask, eventId: eventId)
        }

        // Sync with backend in background using toggleTaskDone
        Task {
            do {
                try await taskRepository.updateTaskStatus(taskId: taskId, status: newStatus)
            } catch {
                // Revert on failure
                withAnimation(.easeInOut(duration: 0.2)) {
                    if let idx = tasks.firstIndex(where: { $0.id == taskId }) {
                        tasks[idx].status = originalTask.status
                        appState?.updateTask(originalTask, eventId: eventId)
                    }
                }
            }
        }
    }

    func addTask(_ task: EventTask) {
        var taskWithEventId = task
        taskWithEventId.eventId = eventId

        // Calculate minimum order to place new task at top (ascending sort - lower order = first)
        let incompleteTasks = tasks.filter { $0.status != .completed }
        let minOrder = incompleteTasks.map { $0.order }.min() ?? 0
        taskWithEventId.order = minOrder - 1

        // Optimistic update - add to UI immediately with temp ID
        let tempTask = taskWithEventId

        // Track this task as pending sync (local ID not yet replaced with server ID)
        pendingSyncTaskIds.insert(tempTask.id)

        withAnimation(.easeInOut(duration: 0.2)) {
            tasks.insert(tempTask, at: 0)
            appState?.addTask(tempTask, eventId: eventId)
        }

        // Sync with backend
        Task {
            do {
                let createdTask = try await taskRepository.createTask(taskWithEventId)
                // Replace temp task with real one from server
                withAnimation(.easeInOut(duration: 0.15)) {
                    if let idx = tasks.firstIndex(where: { $0.id == tempTask.id }) {
                        var updatedTask = createdTask
                        // Set local order to maintain UI position
                        updatedTask.order = minOrder - 1
                        tasks[idx] = updatedTask

                        // IMPORTANT: AppState has the task with the OLD local ID,
                        // but the server returned a task with a NEW server ID.
                        // We need to replace the old one with the new one.
                        appState?.replaceTask(oldId: tempTask.id, with: updatedTask, eventId: eventId)

                        // Task is now synced - remove from pending and allow interactions
                        pendingSyncTaskIds.remove(tempTask.id)
                    }
                }

                // Persist the order to backend
                // Only include tasks with real IDs (not pending temp tasks)
                let sortedIncompleteTasks = tasks
                    .filter { $0.status != .completed && !$0.id.contains("-") }  // UUID format has hyphens (temp), server IDs don't
                    .sorted { $0.order < $1.order }
                let taskIds = sortedIncompleteTasks.map { $0.id }

                if !taskIds.isEmpty {
                    await reorderTasksOnBackend(taskIds: taskIds)
                }
            } catch {
                // Remove on failure (backend rejected)
                pendingSyncTaskIds.remove(tempTask.id)
                withAnimation(.easeInOut(duration: 0.2)) {
                    tasks.removeAll { $0.id == tempTask.id }
                    appState?.removeTask(id: tempTask.id, eventId: eventId)
                }
            }
        }
    }

    /// Check if a task is still pending sync (has local ID, not yet replaced with server ID)
    func isTaskPendingSync(_ taskId: String) -> Bool {
        return pendingSyncTaskIds.contains(taskId)
    }

    func updateTask(_ task: EventTask) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        let originalTask = tasks[index]

        // Optimistic update
        withAnimation(.easeInOut(duration: 0.2)) {
            tasks[index] = task
            appState?.updateTask(task, eventId: eventId)
        }

        // Sync with backend
        Task {
            do {
                try await taskRepository.updateTask(task)
            } catch {
                // Revert on failure
                withAnimation(.easeInOut(duration: 0.2)) {
                    if let idx = tasks.firstIndex(where: { $0.id == task.id }) {
                        tasks[idx] = originalTask
                        appState?.updateTask(originalTask, eventId: eventId)
                    }
                }
            }
        }
    }

    func deleteTask(_ taskId: String) {
        guard let index = tasks.firstIndex(where: { $0.id == taskId }) else { return }
        let removedTask = tasks[index]

        // Optimistic update
        withAnimation(.easeInOut(duration: 0.2)) {
            tasks.remove(at: index)
            appState?.removeTask(id: taskId, eventId: eventId)
        }

        // Sync with backend
        Task {
            do {
                try await taskRepository.deleteTask(id: taskId)
            } catch {
                // Restore on failure
                withAnimation(.easeInOut(duration: 0.2)) {
                    tasks.insert(removedTask, at: min(index, tasks.count))
                    appState?.addTask(removedTask, eventId: eventId)
                }
            }
        }
    }

    func deleteTasks(ids: [String]) {
        let removedTasks = tasks.filter { ids.contains($0.id) }

        // Optimistic update
        withAnimation(.easeInOut(duration: 0.2)) {
            tasks.removeAll { ids.contains($0.id) }
            appState?.removeTasks(ids: Set(ids), eventId: eventId)
        }

        // Sync with backend
        Task {
            var failedIds: [String] = []
            for taskId in ids {
                do {
                    try await taskRepository.deleteTask(id: taskId)
                } catch {
                    failedIds.append(taskId)
                }
            }
            // Restore failed deletions
            if !failedIds.isEmpty {
                let failedTasks = removedTasks.filter { failedIds.contains($0.id) }
                withAnimation(.easeInOut(duration: 0.2)) {
                    tasks.append(contentsOf: failedTasks)
                    for task in failedTasks {
                        appState?.addTask(task, eventId: eventId)
                    }
                }
            }
        }
    }

    func completeTasks(ids: [String]) {
        // Store original states for rollback
        var originalStates: [String: TaskStatus] = [:]
        var originalTasks: [String: EventTask] = [:]
        for id in ids {
            if let task = tasks.first(where: { $0.id == id }) {
                originalStates[id] = task.status
                originalTasks[id] = task
            }
        }

        // Optimistic update - mark all as completed
        withAnimation(.easeInOut(duration: 0.2)) {
            for id in ids {
                if let index = tasks.firstIndex(where: { $0.id == id }) {
                    tasks[index].status = .completed
                    tasks[index].updatedAt = Date()
                    appState?.updateTask(tasks[index], eventId: eventId)
                }
            }
        }

        // Sync with backend
        Task {
            for taskId in ids {
                do {
                    try await taskRepository.updateTaskStatus(taskId: taskId, status: .completed)
                } catch {
                    // Revert on failure
                    if let idx = tasks.firstIndex(where: { $0.id == taskId }),
                       let originalTask = originalTasks[taskId] {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            tasks[idx] = originalTask
                            appState?.updateTask(originalTask, eventId: eventId)
                        }
                    }
                }
            }
        }
    }

    func deleteAllTasks() {
        let allTasks = tasks

        // Optimistic update - clear UI immediately
        withAnimation(.easeInOut(duration: 0.2)) {
            tasks.removeAll()
            appState?.removeTasks(ids: Set(allTasks.map(\.id)), eventId: eventId)
        }

        // Sync with backend
        Task {
            var failedTasks: [EventTask] = []
            for task in allTasks {
                do {
                    try await taskRepository.deleteTask(id: task.id)
                } catch {
                    failedTasks.append(task)
                }
            }
            // Restore failed deletions
            if !failedTasks.isEmpty {
                withAnimation(.easeInOut(duration: 0.2)) {
                    tasks.append(contentsOf: failedTasks)
                    for task in failedTasks {
                        appState?.addTask(task, eventId: eventId)
                    }
                }
            }
        }
    }

    /// Reorder tasks - moves task from source index to destination index
    /// Call this when user drags a task to a new position
    func reorderTasks(from source: IndexSet, to destination: Int) {
        // Get only incomplete tasks for reordering (completed stay at bottom)
        var incompleteTasks = tasks.filter { $0.status != .completed }.sorted { $0.order < $1.order }
        _ = tasks.filter { $0.status == .completed } // Keep completed tasks at bottom

        // Perform the move
        incompleteTasks.move(fromOffsets: source, toOffset: destination)

        // Update order values
        withAnimation(.easeInOut(duration: 0.2)) {
            for (index, var task) in incompleteTasks.enumerated() {
                task.order = index
                if let taskIndex = tasks.firstIndex(where: { $0.id == task.id }) {
                    tasks[taskIndex].order = index
                    appState?.updateTask(tasks[taskIndex], eventId: eventId)
                }
            }
        }

        // Sync with backend - send new order
        let taskIds = incompleteTasks.map { $0.id }
        Task {
            await reorderTasksOnBackend(taskIds: taskIds)
        }
    }

    /// Reorder by moving a specific task to a new position
    func moveTask(_ taskId: String, toIndex newIndex: Int) {
        var incompleteTasks = tasks.filter { $0.status != .completed }.sorted { $0.order < $1.order }

        guard let currentIndex = incompleteTasks.firstIndex(where: { $0.id == taskId }) else {
            return
        }
        guard newIndex >= 0 && newIndex < incompleteTasks.count else {
            return
        }

        let task = incompleteTasks.remove(at: currentIndex)
        incompleteTasks.insert(task, at: newIndex)

        // Update order values
        withAnimation(.easeInOut(duration: 0.2)) {
            for (index, _) in incompleteTasks.enumerated() {
                let id = incompleteTasks[index].id
                if let taskIndex = tasks.firstIndex(where: { $0.id == id }) {
                    tasks[taskIndex].order = index
                    appState?.updateTask(tasks[taskIndex], eventId: eventId)
                }
            }
        }

        // Sync with backend
        let taskIds = incompleteTasks.map { $0.id }
        Task {
            await reorderTasksOnBackend(taskIds: taskIds)
        }
    }

    private func reorderTasksOnBackend(taskIds: [String]) async {
        do {
            // Call the API and update local tasks with backend response
            let reorderedTasks = try await taskRepository.reorderTasks(eventId: eventId, taskIds: taskIds)
            // Update local tasks with the backend's order values
            withAnimation(.easeInOut(duration: 0.15)) {
                for reorderedTask in reorderedTasks {
                    if let index = tasks.firstIndex(where: { $0.id == reorderedTask.id }) {
                        tasks[index].order = reorderedTask.order
                        appState?.updateTask(tasks[index], eventId: eventId)
                    }
                }
            }
        } catch {
            // On failure, reload to get correct order from backend
            await loadTasks()
        }
    }
}

// MARK: - Conditional View Modifier
extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        TasksListView(eventId: "preview-event-id")
    }
}
