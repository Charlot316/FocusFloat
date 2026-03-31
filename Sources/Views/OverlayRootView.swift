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
        .padding(20) // 显著缩小内边距
        .background(Color.clear) // 背景现在由外层 NSVisualEffectView 提供
        .colorScheme(.dark)
        .fixedSize(horizontal: false, vertical: true) // 这行非常重要，让 View 根据内容自动增长窗口
        .sheet(isPresented: $isShowingAddSheet) {
            quickAddSheet
        }
    }

    // MARK: - Active Task View
    private func activeTaskView(_ reminder: ReminderSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 20) { // 缩小各模块之间的间距
            focusTimerSection(for: reminder)

            VStack(alignment: .leading, spacing: 10) {
                Text(reminder.title)
                    .font(.system(size: 30, weight: .bold, design: .rounded)) // 缩小字号
                    .foregroundStyle(.white)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)

                if let notes = reminder.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.system(size: 16, weight: .medium)) // 缩小字号
                        .foregroundStyle(.white.opacity(0.8))
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 8) {
                labelTag(reminder.calendarTitle, icon: "list.bullet", color: .blue)
                if let dueDate = reminder.dueDate {
                    labelTag(endTimeText(for: dueDate), icon: "clock.fill", color: .orange)
                }
                Spacer()
            }

            // 3. 完成任务按钮
            Button {
                withAnimation(.spring(response: 0.3)) { completingReminderID = reminder.id }
                Task {
                    _ = await store.completeReminder(id: reminder.id)
                    completingReminderID = nil
                }
            } label: {
                HStack(spacing: 10) {
                    if completingReminderID == reminder.id {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16))
                    }
                    Text("DONE").fontWeight(.black).tracking(0.5) // 文字更精简
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52) // 缩小按钮高度
                .background(.white)
                .foregroundStyle(.black)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
            }
            .buttonStyle(.plain)

            // 4. 底部功能小工具栏
            HStack(spacing: 12) {
                bottomUtilityButton(icon: "plus", label: "ADD", color: .blue) {
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
        }
    }

    private func focusTimerSection(for reminder: ReminderSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("FOCUS TIMER")
                .font(.system(size: 12, weight: .black))
                .foregroundStyle(.white.opacity(0.55))
                .tracking(1.6)

            if let dueDate = reminder.dueDate {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let countdown = countdownPresentation(to: dueDate, now: context.date)

                    VStack(alignment: .leading, spacing: 10) {
                        Text(countdown.timeText)
                            .font(.system(size: 64, weight: .black, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(countdown.accent)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)

                        Text(countdown.statusText)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white.opacity(0.78))

                        Capsule()
                            .fill(countdown.accent.opacity(0.9))
                            .frame(width: countdown.barWidth, height: 6)
                            .animation(.easeInOut(duration: 0.25), value: countdown.barWidth)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(18)
                    .background(countdown.background, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(.white.opacity(0.08), lineWidth: 1)
                    )
                }
            } else {
                Text("NO TIMER")
                    .font(.system(size: 42, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.35))
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 18) {
            Image(systemName: "sparkles")
                .font(.system(size: 32))
                .foregroundStyle(.white.opacity(0.3))
            
            Text("FOCUS ON NOW")
                .font(.system(size: 16, weight: .black))
                .foregroundStyle(.white.opacity(0.3))
                .tracking(1.5)
            
            bottomUtilityButton(icon: "plus", label: "START NEW", color: .blue) {
                isShowingAddSheet = true
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
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
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 10, weight: .bold))
            Text(text).font(.system(size: 11, weight: .black))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.white.opacity(0.08))
        .foregroundStyle(color)
        .clipShape(Capsule())
    }

    private func bottomUtilityButton(icon: String, label: String? = nil, color: Color = .white, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .black))
                if let label = label {
                    Text(label)
                        .font(.system(size: 11, weight: .black))
                }
            }
            .padding(.horizontal, label == nil ? 10 : 14)
            .frame(height: 38)
            .background(.white.opacity(0.08))
            .foregroundStyle(color)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.08), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func dueText(for date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func endTimeText(for date: Date) -> String {
        "截止 \(date.formatted(date: .omitted, time: .shortened))"
    }

    private func countdownPresentation(to dueDate: Date, now: Date) -> CountdownPresentation {
        let secondsRemaining = Int(dueDate.timeIntervalSince(now).rounded(.down))
        let seconds = abs(secondsRemaining)
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let remainingSeconds = seconds % 60

        let timeText: String
        if hours > 0 {
            timeText = String(format: "%d:%02d:%02d", hours, minutes, remainingSeconds)
        } else {
            timeText = String(format: "%02d:%02d", minutes, remainingSeconds)
        }

        let accent: Color
        let background: Color
        let statusText: String
        let barWidth: CGFloat

        if secondsRemaining < 0 {
            accent = .red
            background = Color.red.opacity(0.16)
            statusText = "已经超时，先把这个块收掉。"
            barWidth = 220
        } else if secondsRemaining <= 5 * 60 {
            accent = .orange
            background = Color.orange.opacity(0.14)
            statusText = "最后冲刺，专注到 \(endTimeText(for: dueDate))。"
            barWidth = 180
        } else {
            accent = .green
            background = Color.green.opacity(0.14)
            statusText = "只盯这一件事，先做到 \(endTimeText(for: dueDate))。"
            barWidth = 120
        }

        return CountdownPresentation(
            timeText: timeText,
            statusText: statusText,
            accent: accent,
            background: background,
            barWidth: barWidth
        )
    }

    private var selectedCalendarBinding: Binding<String> {
        Binding(get: { store.selectedCalendarIdentifier }, set: { store.selectedCalendarIdentifier = $0 })
    }
}

private struct CountdownPresentation {
    let timeText: String
    let statusText: String
    let accent: Color
    let background: Color
    let barWidth: CGFloat
}

// 移除了 LiquidBackground，因为现在使用外层的 NSVisualEffectView
