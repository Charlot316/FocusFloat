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
        ZStack {
            // Liquid Mesh Background: 保持深邃流动的液态背景
            LiquidBackground()
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                headerView
                    .padding(.horizontal, 28)
                    .padding(.top, 36)
                    .padding(.bottom, 24)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 32) {
                        if store.authorizationState.isGranted {
                            currentTaskSection
                        } else {
                            permissionSection
                                .padding(.top, 40)
                        }
                    }
                    .padding(.horizontal, 28)
                    .padding(.bottom, 48)
                }
            }
        }
        .frame(minWidth: 420, minHeight: 480) // 默认高度可略缩窄，因为内容更精简了
        .colorScheme(.dark)
        .sheet(isPresented: $isShowingAddSheet) {
            quickAddSheet
        }
    }

    // MARK: - Header
    private var headerView: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("FocusFloat")
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                
                HStack(spacing: 6) {
                    Circle().fill(store.isLoading ? .orange : .green)
                        .frame(width: 7, height: 7)
                    Text(store.isLoading ? "SYNCING..." : "SINGLE FOCUS MODE")
                        .font(.system(size: 10, weight: .black))
                        .foregroundStyle(.white.opacity(0.4))
                        .tracking(1.2)
                }
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                // 新增按钮，点击才展开
                systemButton(icon: "plus", color: .blue) {
                    isShowingAddSheet = true
                }
                
                systemButton(icon: "arrow.clockwise") {
                    Task { await store.refresh() }
                }
                
                systemButton(icon: "power", color: .red) {
                    NSApp.terminate(nil)
                }
            }
        }
    }

    // MARK: - Prime Focus Section
    private var currentTaskSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            if let reminder = store.currentReminder {
                glassGroup {
                    VStack(alignment: .leading, spacing: 28) {
                        // 任务核心内容：去除了所有行数限制，确保看到完整内容
                        VStack(alignment: .leading, spacing: 14) {
                            Text(reminder.title)
                                .font(.system(size: 34, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .lineSpacing(4)
                                .fixedSize(horizontal: false, vertical: true) // 强制垂直展开

                            if let notes = reminder.notes, !notes.isEmpty {
                                Text(notes)
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.7))
                                    .lineSpacing(2)
                                    .fixedSize(horizontal: false, vertical: true) // 确保备注不被截断
                            }
                        }

                        HStack(spacing: 12) {
                            labelTag(reminder.calendarTitle, icon: "list.bullet", color: .blue)
                            if let dueDate = reminder.dueDate {
                                labelTag(dueText(for: dueDate), icon: "clock.fill", color: .orange)
                            }
                        }

                        // 占据底部的大型完成按钮
                        Button {
                            withAnimation(.spring(response: 0.3)) { completingReminderID = reminder.id }
                            Task {
                                _ = await store.completeReminder(id: reminder.id)
                                completingReminderID = nil
                            }
                        } label: {
                            HStack {
                                if completingReminderID == reminder.id {
                                    ProgressView().controlSize(.small)
                                } else {
                                    Image(systemName: "checkmark.circle.fill")
                                }
                                Text("COMPLETE THIS TASK").fontWeight(.black)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 64)
                        }
                        .buttonStyle(.plain)
                        .background(Color.white)
                        .foregroundStyle(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .shadow(color: .black.opacity(0.2), radius: 15, x: 0, y: 10)
                    }
                }
            } else {
                glassGroup {
                    VStack(spacing: 20) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 40))
                            .foregroundStyle(.white.opacity(0.2))
                        Text("MIND CLEAR")
                            .font(.system(size: 20, weight: .black))
                            .foregroundStyle(.white.opacity(0.3))
                            .tracking(2)
                    }
                    .frame(maxWidth: .infinity, minHeight: 200)
                }
            }
        }
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
            .background(.ultraThinMaterial)

            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    TextField("What's on your mind?", text: $draftTitle)
                        .textFieldStyle(.plain)
                        .font(.system(size: 20, weight: .bold))
                    
                    Divider().background(.white.opacity(0.1))
                    
                    TextField("Add some notes...", text: $draftNotes, axis: .vertical)
                        .lineLimit(3...8)
                        .textFieldStyle(.plain)
                        .font(.system(size: 15))
                }
                .padding()
                .background(.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 16))

                VStack(spacing: 16) {
                    HStack {
                        Label("List", systemImage: "tray.full.fill").font(.system(size: 12, weight: .bold))
                        Spacer()
                        Picker("", selection: selectedCalendarBinding) {
                            ForEach(store.writableCalendars) { calendar in
                                Text(calendar.title).tag(calendar.id)
                            }
                        }.pickerStyle(.menu).labelsHidden().scaleEffect(0.9)
                    }

                    HStack {
                        Toggle(isOn: $includeDueDate) {
                            Label("Set Reminder", systemImage: "bell.fill").font(.system(size: 12, weight: .bold))
                        }.toggleStyle(.switch).controlSize(.small)
                        
                        Spacer()
                        
                        if includeDueDate {
                            DatePicker("", selection: $dueDate).datePickerStyle(.compact).labelsHidden().scaleEffect(0.9)
                        }
                    }
                }
                .padding()
                .background(.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 16))

                Button {
                    Task {
                        isSaving = true
                        _ = await store.addReminder(title: draftTitle, notes: draftNotes, dueDate: includeDueDate ? dueDate : nil, calendarIdentifier: store.selectedCalendarIdentifier)
                        draftTitle = ""; draftNotes = ""; isSaving = false; isShowingAddSheet = false
                    }
                } label: {
                    HStack {
                        if isSaving { ProgressView().controlSize(.small) }
                        Text(isSaving ? "SAVING..." : "COMMIT TO LIST").fontWeight(.black)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                }
                .buttonStyle(.plain)
                .background(Color.blue)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .disabled(draftTitle.isEmpty)
            }
            .padding()
        }
        .frame(width: 360)
        .background(.thickMaterial)
        .colorScheme(.dark)
    }

    private var permissionSection: some View {
        glassGroup {
            VStack(spacing: 24) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 54))
                    .foregroundStyle(.blue.gradient)
                Text(store.authorizationState == .denied ? "Access Denied" : "Reminders Access Required")
                    .font(.system(size: 20, weight: .bold))
                    .multilineTextAlignment(.center)
                Button("ALLOW REMINDERS") {
                    Task { await store.requestAccess() }
                }.buttonStyle(.borderedProminent).controlSize(.large)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
        }
    }

    // MARK: - Component Modifiers
    private func glassGroup<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(28)
            .background(.ultraThinMaterial.opacity(0.8))
            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .stroke(.white.opacity(0.12), lineWidth: 1)
            )
    }

    private func labelTag(_ text: String, icon: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 11, weight: .bold))
            Text(text).font(.system(size: 12, weight: .black))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(color.opacity(0.2))
        .foregroundStyle(color)
        .clipShape(Capsule())
    }

    private func systemButton(icon: String, color: Color = .white, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .black))
                .foregroundStyle(color)
                .frame(width: 40, height: 40)
                .background(.ultraThinMaterial)
                .clipShape(Circle())
                .overlay(Circle().stroke(.white.opacity(0.12), lineWidth: 1))
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

// MARK: - Liquid Background
struct LiquidBackground: View {
    @State private var phase = 0.0

    var body: some View {
        ZStack {
            Color(red: 0.02, green: 0.02, blue: 0.05)
            Canvas { context, size in
                let colors: [Color] = [.blue, .purple, .indigo, .blue]
                for i in 0..<colors.count {
                    let t = phase + Double(i) * 1.5
                    let x = size.width * (0.5 + 0.35 * cos(t * 0.3))
                    let y = size.height * (0.5 + 0.35 * sin(t * 0.4))
                    let radius = size.width * 0.9
                    context.addFilter(.blur(radius: 90))
                    context.fill(Path(ellipseIn: CGRect(x: x - radius/2, y: y - radius/2, width: radius, height: radius)), with: .color(colors[i].opacity(0.25)))
                }
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 25).repeatForever(autoreverses: false)) {
                phase = .pi * 2
            }
        }
    }
}
