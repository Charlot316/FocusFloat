import AppKit
import SwiftUI

struct OverlayRootView: View {
    @ObservedObject var store: RemindersStore

    @State private var draftTitle = ""
    @State private var draftNotes = ""
    @State private var includeDueDate = false
    @State private var dueDate = Self.defaultDueDate
    @State private var isSaving = false
    @State private var isShowingAddSheet = false
    @State private var completingReminderID: String?

    private static var defaultDueDate: Date {
        Date().addingTimeInterval(3600)
    }

    var body: some View {
        VStack(spacing: 0) {
            if store.authorizationState.isGranted {
                if let reminder = store.currentReminder {
                    activeTaskView(reminder)
                } else {
                    emptyStateView
                }
            } else {
                permissionSection
            }
        }
        .padding(32) // 给四周留出足够的呼吸空间
        .background(Color.clear) // 背景现在由外层 NSVisualEffectView 提供
        .colorScheme(.dark)
        .fixedSize(horizontal: false, vertical: true) // 这行非常重要，让 View 根据内容自动增长窗口
        .sheet(isPresented: $isShowingAddSheet) {
            quickAddSheet
        }
    }

    // MARK: - Active Task View
    private func activeTaskView(_ reminder: ReminderSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 32) {
            // 1. 任务核心文本区域
            VStack(alignment: .leading, spacing: 16) {
                Text(reminder.title)
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                
                if let notes = reminder.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(.white.opacity(0.8))
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            
            // 2. 任务标签栏
            HStack(spacing: 12) {
                labelTag(reminder.calendarTitle, icon: "list.bullet", color: .blue)
                if let dueDate = reminder.dueDate {
                    labelTag(dueText(for: dueDate), icon: "clock.fill", color: .orange)
                }
                Spacer()
            }

            // 3. 完成任务大按钮
            Button {
                withAnimation(.spring(response: 0.3)) { completingReminderID = reminder.id }
                Task {
                    _ = await store.completeReminder(id: reminder.id)
                    completingReminderID = nil
                }
            } label: {
                HStack(spacing: 12) {
                    if completingReminderID == reminder.id {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                    }
                    Text("COMPLETE THIS TASK").fontWeight(.black).tracking(1)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 68)
                .background(.white)
                .foregroundStyle(.black)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
            }
            .buttonStyle(.plain)

            // 4. 底部功能小工具栏
            HStack(spacing: 16) {
                bottomUtilityButton(icon: "plus", label: "ADD TASK", color: .blue) {
                    isShowingAddSheet = true
                }
                
                Spacer()
                
                HStack(spacing: 12) {
                    bottomUtilityButton(icon: "arrow.clockwise") {
                        Task { await store.refresh() }
                    }
                    bottomUtilityButton(icon: "power", color: .red) {
                        NSApp.terminate(nil)
                    }
                }
            }
            .padding(.top, 8)
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "sparkles")
                .font(.system(size: 48))
                .foregroundStyle(.white.opacity(0.3))
            
            Text("ALL CLEAR")
                .font(.system(size: 24, weight: .black))
                .foregroundStyle(.white.opacity(0.3))
                .tracking(2)
            
            bottomUtilityButton(icon: "plus", label: "NEW TASK", color: .blue) {
                isShowingAddSheet = true
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Quick Add Sheet
    private var quickAddSheet: some View {
        VStack(spacing: 0) {
            HStack {
                Text("NEW REMINDER").font(.system(size: 13, weight: .black)).foregroundStyle(.secondary)
                Spacer()
                Button("CLOSE") { isShowingAddSheet = false }.buttonStyle(.plain).font(.system(size: 12, weight: .bold)).foregroundStyle(.blue)
            }
            .padding()

            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 12) {
                    TextField("What needs to be done?", text: $draftTitle)
                        .textFieldStyle(.plain)
                        .font(.system(size: 22, weight: .bold))
                    
                    Divider().background(.white.opacity(0.1))
                    
                    TextField("Optionally add more context...", text: $draftNotes, axis: .vertical)
                        .lineLimit(3...10)
                        .textFieldStyle(.plain)
                        .font(.system(size: 16))
                }
                .padding()
                .background(.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 16))

                HStack {
                    Picker("List", selection: selectedCalendarBinding) {
                        ForEach(store.writableCalendars) { cal in
                            Text(cal.title).tag(cal.id)
                        }
                    }.pickerStyle(.menu).scaleEffect(0.9)
                    
                    Spacer()
                    
                    Toggle(isOn: $includeDueDate) {
                        Image(systemName: "bell.fill")
                    }.toggleStyle(.button).controlSize(.small)
                    
                    if includeDueDate {
                        DatePicker("", selection: $dueDate).datePickerStyle(.compact).labelsHidden().scaleEffect(0.8)
                    }
                }

                Button {
                    Task {
                        isSaving = true
                        _ = await store.addReminder(title: draftTitle, notes: draftNotes, dueDate: includeDueDate ? dueDate : nil, calendarIdentifier: store.selectedCalendarIdentifier)
                        draftTitle = ""; draftNotes = ""; isSaving = false; isShowingAddSheet = false
                    }
                } label: {
                    Text(isSaving ? "ADDING..." : "COMMIT TO LIST")
                        .font(.system(size: 14, weight: .black))
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(Color.blue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
                .disabled(draftTitle.isEmpty)
            }
            .padding()
        }
        .frame(width: 400)
        .background(.thickMaterial)
        .colorScheme(.dark)
    }

    private var permissionSection: some View {
        VStack(spacing: 24) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 54))
                .foregroundStyle(.blue.gradient)
            Text("Reminders Access Required")
                .font(.system(size: 20, weight: .bold))
            Button("ALLOW ACCESS") {
                Task { await store.requestAccess() }
            }.buttonStyle(.borderedProminent).controlSize(.large)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Styled Components
    private func labelTag(_ text: String, icon: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 12, weight: .bold))
            Text(text).font(.system(size: 13, weight: .black))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.white.opacity(0.1))
        .foregroundStyle(color)
        .clipShape(Capsule())
    }

    private func bottomUtilityButton(icon: String, label: String? = nil, color: Color = .white, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .black))
                if let label = label {
                    Text(label)
                        .font(.system(size: 12, weight: .black))
                }
            }
            .padding(.horizontal, label == nil ? 12 : 18)
            .frame(height: 44)
            .background(.white.opacity(0.1))
            .foregroundStyle(color)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.1), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func dueText(for date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private var selectedCalendarBinding: Binding<String> {
        Binding(get: { store.selectedCalendarIdentifier }, set: { store.selectedCalendarIdentifier = $0 })
    }
}

// 移除了 LiquidBackground，因为现在使用外层的 NSVisualEffectView
