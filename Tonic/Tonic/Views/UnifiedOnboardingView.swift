//
//  UnifiedOnboardingView.swift
//  Tonic
//
//  Redesigned onboarding — 7 benefit-first screens with polished animations
//

import SwiftUI
import UserNotifications

// MARK: - Main Orchestrator

struct UnifiedOnboardingView: View {
    @Binding var isPresented: Bool
    @Environment(\.dismiss) private var dismiss

    @State private var currentPage = 0
    @State private var direction: SlideDirection = .forward
    @State private var animateContent = false

    @State private var permissionManager = PermissionManager.shared
    @State private var helperManager = PrivilegedHelperManager.shared
    @State private var isInstallingHelper = false
    @State private var notificationsEnabled = false
    @State private var notificationStatus: PermissionStatus = .notDetermined

    private let totalPages = 7

    enum SlideDirection {
        case forward, backward
    }

    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Progress bar
                OnboardingProgressBar(currentPage: currentPage, totalPages: totalPages)
                    .padding(.top, 20)
                    .padding(.horizontal, 24)

                // Page content
                ZStack {
                    pageContent
                        .id(currentPage)
                        .transition(pageTransition)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()

                // Navigation
                navigationButtons
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)
            }
        }
        .frame(width: 580, height: 640)
        .onAppear {
            triggerEntrance()
        }
    }

    // MARK: - Page Routing

    @ViewBuilder
    private var pageContent: some View {
        switch currentPage {
        case 0: welcomePage
        case 1: smartScanPage
        case 2: diskLensPage
        case 3: appManagerPage
        case 4: menuBarWidgetsPage
        case 5: setupPage
        default: readyPage
        }
    }

    private var pageTransition: AnyTransition {
        switch direction {
        case .forward:
            return .asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            )
        case .backward:
            return .asymmetric(
                insertion: .move(edge: .leading).combined(with: .opacity),
                removal: .move(edge: .trailing).combined(with: .opacity)
            )
        }
    }

    // MARK: - Screen 1: Welcome

    private var welcomePage: some View {
        VStack(spacing: 24) {
            Spacer()

            TonicBrandAssets.appImage()
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .scaleEffect(animateContent ? 1.0 : 0.3)
                .rotationEffect(.degrees(animateContent ? 0 : -10))
                .animation(.spring(response: 0.6, dampingFraction: 0.6), value: animateContent)

            VStack(spacing: 8) {
                Text("Welcome to Tonic")
                    .font(.title).bold()
                    .offset(y: animateContent ? 0 : 25)
                    .opacity(animateContent ? 1 : 0)
                    .animation(.easeOut(duration: 0.4).delay(0.08), value: animateContent)

                Text("Keep your Mac healthy, fast, and clutter-free.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .offset(y: animateContent ? 0 : 20)
                    .opacity(animateContent ? 1 : 0)
                    .animation(.easeOut(duration: 0.35).delay(0.16), value: animateContent)
            }

            HStack(spacing: 12) {
                welcomePill("Clean", icon: "sparkle", delay: 0.3)
                welcomePill("Monitor", icon: "gauge.medium", delay: 0.4)
                welcomePill("Protect", icon: "shield.fill", delay: 0.5)
            }

            Spacer()
        }
        .padding(.horizontal, 40)
    }

    private func welcomePill(_ text: String, icon: String, delay: Double) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
            Text(text)
                .font(.subheadline).bold()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(TonicColors.accent.opacity(0.12))
        .foregroundColor(TonicColors.accent)
        .cornerRadius(20)
        .offset(y: animateContent ? 0 : 15)
        .opacity(animateContent ? 1 : 0)
        .animation(.easeOut(duration: 0.3).delay(delay), value: animateContent)
    }

    // MARK: - Screen 2: Smart Scan

    private var smartScanPage: some View {
        featurePage(
            icon: "bolt.shield.fill",
            title: "Your Mac's Check-Up",
            subtitle: "Caches pile up. Logs grow silently. Temp files linger. Smart Scan finds it all in seconds and tells you exactly how much space you'll get back.",
            cards: [
                ("gauge.with.dots.needle.67percent", "Instant Diagnosis", "Scans caches, logs, temp files, and app leftovers in under a minute"),
                ("arrow.counterclockwise", "Safe by Default", "Every file is reviewed before deletion — nothing gets removed without your say"),
                ("sparkles", "Reclaim Gigabytes", "Most Macs have 5-20 GB of hidden junk. Smart Scan finds it all"),
            ]
        )
    }

    // MARK: - Screen 3: Disk Space Lens

    private var diskLensPage: some View {
        featurePage(
            icon: "chart.pie.fill",
            title: "X-Ray Your Storage",
            subtitle: "Where did all your disk space go? Disk Space Lens gives you a visual map of every gigabyte — so you can spot the biggest offenders in seconds.",
            cards: [
                ("rectangle.split.2x2", "Visual Treemap", "See your entire disk as colored blocks — bigger block, bigger folder"),
                ("arrow.down.forward.and.arrow.up.backward", "Drill Into Anything", "Click any block to zoom in and explore what's inside"),
                ("flame.fill", "Find Space Hogs", "Instantly surfaces the largest files and folders eating your storage"),
            ]
        )
    }

    // MARK: - Screen 4: App Manager

    private var appManagerPage: some View {
        featurePage(
            icon: "app.badge.checkmark",
            title: "The Uninstaller macOS Should Have",
            subtitle: "Dragging an app to Trash leaves behind caches, preferences, and support files scattered across your system. App Manager removes everything.",
            cards: [
                ("trash.slash.fill", "True Uninstall", "Removes the app, its caches, preferences, containers, and login items"),
                ("magnifyingglass.circle.fill", "Find Hidden Leftovers", "Detects orphaned files from apps you've already deleted"),
                ("clock.fill", "Know What You Have", "See when you last opened each app and how much space it uses"),
            ]
        )
    }

    // MARK: - Screen 5: Menu Bar Widgets

    private var menuBarWidgetsPage: some View {
        featurePage(
            icon: "menubar.rectangle",
            title: "Your System, Always Visible",
            subtitle: "Tiny, beautiful widgets live in your menu bar — showing CPU, memory, disk, network, battery, and more. Glance up. Know everything.",
            cards: [
                ("waveform.path.ecg", "Live Metrics", "CPU, memory, disk, network, GPU, battery — updating every second"),
                ("paintbrush.fill", "Your Style", "14+ visualization types — sparklines, gauges, bar charts, pie charts"),
                ("bell.badge.fill", "Smart Alerts", "Set thresholds and get notified when CPU spikes or disk runs low"),
            ]
        )
    }

    // MARK: - Feature Page Template

    private func featurePage(
        icon: String,
        title: String,
        subtitle: String,
        cards: [(String, String, String)]
    ) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                Spacer().frame(height: 16)

                // Hero icon
                Image(systemName: icon)
                    .font(.system(size: 56))
                    .foregroundStyle(.linearGradient(
                        colors: [TonicColors.accent, TonicColors.pro],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .scaleEffect(animateContent ? 1.0 : 0.5)
                    .animation(.spring(response: 0.4, dampingFraction: 0.7), value: animateContent)

                // Title
                Text(title)
                    .font(.title).bold()
                    .multilineTextAlignment(.center)
                    .offset(y: animateContent ? 0 : 25)
                    .opacity(animateContent ? 1 : 0)
                    .animation(.easeOut(duration: 0.4).delay(0.08), value: animateContent)

                // Subtitle
                Text(subtitle)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .offset(y: animateContent ? 0 : 20)
                    .opacity(animateContent ? 1 : 0)
                    .animation(.easeOut(duration: 0.35).delay(0.16), value: animateContent)

                // Value cards
                VStack(spacing: 8) {
                    ForEach(Array(cards.enumerated()), id: \.offset) { index, card in
                        OnboardingValueCard(icon: card.0, title: card.1, description: card.2)
                            .offset(y: animateContent ? 0 : 15)
                            .opacity(animateContent ? 1 : 0)
                            .animation(.easeOut(duration: 0.3).delay(0.24 + 0.08 * Double(index)), value: animateContent)
                    }
                }

                Spacer().frame(height: 8)
            }
            .padding(.horizontal, 32)
        }
    }

    // MARK: - Screen 6: Setup

    private var setupPage: some View {
        ScrollView {
            VStack(spacing: 20) {
                Spacer().frame(height: 16)

                // Title
                Text("Let's Get You Set Up")
                    .font(.title).bold()
                    .offset(y: animateContent ? 0 : 25)
                    .opacity(animateContent ? 1 : 0)
                    .animation(.easeOut(duration: 0.4).delay(0.08), value: animateContent)

                Text("A few quick steps so Tonic can do its best work.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .offset(y: animateContent ? 0 : 20)
                    .opacity(animateContent ? 1 : 0)
                    .animation(.easeOut(duration: 0.35).delay(0.16), value: animateContent)

                // Setup cards
                VStack(spacing: 12) {
                    // Full Disk Access — with step-by-step guidance
                    fdaSetupCard
                        .offset(y: animateContent ? 0 : 15)
                        .opacity(animateContent ? 1 : 0)
                        .animation(.easeOut(duration: 0.3).delay(0.24), value: animateContent)

                    // Notifications — conditional UI based on status
                    notificationSetupCard
                        .offset(y: animateContent ? 0 : 15)
                        .opacity(animateContent ? 1 : 0)
                        .animation(.easeOut(duration: 0.3).delay(0.32), value: animateContent)

                    // Privileged Helper
                    OnboardingSetupCard(
                        icon: "checkmark.shield.fill",
                        title: "Privileged Helper",
                        description: "Enables deep cleaning, DNS flushing, RAM clearing, and fan control.",
                        badgeText: "Recommended",
                        badgeColor: TonicColors.accent,
                        isGranted: helperManager.isHelperInstalled,
                        action: {
                            Task {
                                await installHelper()
                            }
                        },
                        actionLabel: isInstallingHelper ? "Installing..." : "Install",
                        isLoading: isInstallingHelper
                    )
                    .offset(y: animateContent ? 0 : 15)
                    .opacity(animateContent ? 1 : 0)
                    .animation(.easeOut(duration: 0.3).delay(0.40), value: animateContent)
                }

                Text("You can always change these in Settings.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
                    .offset(y: animateContent ? 0 : 10)
                    .opacity(animateContent ? 1 : 0)
                    .animation(.easeOut(duration: 0.3).delay(0.5), value: animateContent)

                Spacer().frame(height: 8)
            }
            .padding(.horizontal, 32)
        }
        .task {
            await permissionManager.checkAllPermissions()
            _ = helperManager.checkInstallationStatus()
            await refreshNotificationStatus()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            Task {
                await permissionManager.checkAllPermissions()
                await refreshNotificationStatus()
            }
        }
    }

    // MARK: - FDA Setup Card (Step-by-Step)

    private var fdaSetupCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "lock.open.fill")
                    .font(.title3)
                    .foregroundColor(permissionManager.hasFullDiskAccess ? .green : TonicColors.accent)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Full Disk Access")
                        .font(.headline)
                    Text("Lets Tonic scan your entire disk — not just the parts macOS allows by default.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                if permissionManager.hasFullDiskAccess {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.green)
                        .transition(.scale.combined(with: .opacity))
                } else {
                    Text("Required")
                        .font(.caption2).bold()
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.orange.opacity(0.15))
                        .foregroundColor(.orange)
                        .cornerRadius(4)
                }
            }

            if !permissionManager.hasFullDiskAccess {
                // Step-by-step instructions
                VStack(alignment: .leading, spacing: 6) {
                    stepRow(number: 1, text: "Click below to open System Settings")
                    stepRow(number: 2, text: "Find **Tonic** in the list and flip the switch on")
                    stepRow(number: 3, text: "Come back here — we'll detect it automatically")
                }
                .padding(.leading, 38)
                .padding(.top, 2)

                Button {
                    _ = permissionManager.requestFullDiskAccess()
                } label: {
                    Text("Open System Settings")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .padding(.leading, 38)
            }
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(10)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: permissionManager.hasFullDiskAccess)
    }

    private func stepRow(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(number).")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(TonicColors.accent)
                .frame(width: 16, alignment: .trailing)

            Text(.init(text)) // .init enables markdown bold
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Notification Setup Card (Conditional)

    private var notificationSetupCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "bell.fill")
                    .font(.title3)
                    .foregroundColor(notificationsEnabled ? .green : TonicColors.accent)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Notifications")
                        .font(.headline)
                    Text("Get alerts when CPU spikes, memory runs low, or disk space drops.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                if notificationsEnabled {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.green)
                        .transition(.scale.combined(with: .opacity))
                } else {
                    Text("Optional")
                        .font(.caption2).bold()
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.gray.opacity(0.15))
                        .foregroundColor(.gray)
                        .cornerRadius(4)
                }
            }

            if !notificationsEnabled {
                if notificationStatus == .denied {
                    // Previously denied — show deep link to System Settings
                    Text("Previously denied — enable in System Settings")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.leading, 38)

                    Button {
                        NotificationManager.shared.openNotificationSettings()
                    } label: {
                        Text("Open Notification Settings")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .padding(.leading, 38)
                } else {
                    // Not determined — show request button
                    Button {
                        requestNotifications()
                    } label: {
                        Text("Enable Notifications")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .padding(.leading, 38)
                }
            }
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(10)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: notificationsEnabled)
    }

    // MARK: - Screen 7: Ready

    private var readyPage: some View {
        VStack(spacing: 24) {
            Spacer()

            // Animated checkmark
            ZStack {
                Circle()
                    .fill(Color.green.opacity(animateContent ? 0.12 : 0))
                    .frame(width: 120, height: 120)
                    .animation(.easeInOut(duration: 0.8).delay(0.3), value: animateContent)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 72))
                    .foregroundColor(.green)
                    .scaleEffect(animateContent ? 1.0 : 0)
                    .animation(.spring(response: 0.5, dampingFraction: 0.6), value: animateContent)
                    .shadow(color: .green.opacity(animateContent ? 0.3 : 0), radius: 25)
                    .animation(.easeInOut(duration: 0.6).delay(0.4), value: animateContent)
            }

            VStack(spacing: 8) {
                Text("You're All Set!")
                    .font(.title).bold()
                    .offset(y: animateContent ? 0 : 25)
                    .opacity(animateContent ? 1 : 0)
                    .animation(.easeOut(duration: 0.4).delay(0.15), value: animateContent)

                Text("Tonic is ready to help you keep your Mac running at its best.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .offset(y: animateContent ? 0 : 20)
                    .opacity(animateContent ? 1 : 0)
                    .animation(.easeOut(duration: 0.35).delay(0.25), value: animateContent)
            }

            // Status summary
            VStack(spacing: 8) {
                readyStatusRow(
                    icon: "lock.open.fill",
                    title: "Full Disk Access",
                    isGranted: permissionManager.hasFullDiskAccess,
                    delay: 0.35
                )
                readyStatusRow(
                    icon: "bell.fill",
                    title: "Notifications",
                    isGranted: notificationsEnabled,
                    delay: 0.45
                )
                readyStatusRow(
                    icon: "checkmark.shield.fill",
                    title: "Privileged Helper",
                    isGranted: helperManager.isHelperInstalled,
                    delay: 0.55
                )
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(10)
            .padding(.horizontal, 40)

            if !permissionManager.hasFullDiskAccess {
                Text("Tip: Grant Full Disk Access for the complete experience.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .opacity(animateContent ? 1 : 0)
                    .animation(.easeOut(duration: 0.3).delay(0.6), value: animateContent)
            }

            Spacer()
        }
        .padding(.horizontal, 32)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            Task {
                await permissionManager.checkAllPermissions()
                await refreshNotificationStatus()
            }
        }
    }

    private func readyStatusRow(icon: String, title: String, isGranted: Bool, delay: Double) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(isGranted ? .green : .secondary)
                .frame(width: 24)

            Text(title)
                .font(.subheadline)

            Spacer()

            if isGranted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else {
                Text("Grant later in Settings")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .offset(y: animateContent ? 0 : 10)
        .opacity(animateContent ? 1 : 0)
        .animation(.easeOut(duration: 0.3).delay(delay), value: animateContent)
    }

    // MARK: - Navigation

    private var navigationButtons: some View {
        HStack(spacing: 12) {
            if currentPage > 0 {
                Button("Back") {
                    goBack()
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }

            Spacer()

            if currentPage < totalPages - 1 {
                Button("Next") {
                    goForward()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            } else {
                Button("Start Using Tonic") {
                    completeOnboarding()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .opacity(animateContent ? 1 : 0)
                .animation(.easeOut(duration: 0.3).delay(0.5), value: animateContent)
            }
        }
    }

    // MARK: - Actions

    private func goForward() {
        animateContent = false
        direction = .forward
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
            currentPage += 1
        }
        triggerEntrance()
    }

    private func goBack() {
        animateContent = false
        direction = .backward
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
            currentPage -= 1
        }
        triggerEntrance()
    }

    private func triggerEntrance() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            animateContent = true
        }
    }

    private func installHelper() async {
        isInstallingHelper = true
        do {
            try await helperManager.installHelper()
            _ = helperManager.checkInstallationStatus()
        } catch {
            print("Helper installation failed: \(error)")
        }
        isInstallingHelper = false
    }

    private func requestNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            Task { @MainActor in
                notificationsEnabled = granted
                notificationStatus = granted ? .authorized : .denied
            }
        }
    }

    private func refreshNotificationStatus() async {
        let granted = await NotificationManager.shared.checkPermissionStatus()
        notificationsEnabled = granted
        let status = await PermissionManager.shared.checkPermission(.notifications)
        notificationStatus = status
    }

    private func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
        UserDefaults.standard.set(true, forKey: "hasCompletedWidgetOnboarding")
        UserDefaults.standard.set(true, forKey: "hasSeenFeatureTour")
        WidgetPreferences.shared.setHasCompletedOnboarding(true)
        WidgetCoordinator.shared.start()
        isPresented = false
        dismiss()
    }
}

// MARK: - Progress Bar

struct OnboardingProgressBar: View {
    let currentPage: Int
    let totalPages: Int

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<totalPages, id: \.self) { index in
                RoundedRectangle(cornerRadius: 3)
                    .fill(index <= currentPage ? TonicColors.accent : Color.gray.opacity(0.3))
                    .frame(width: index == currentPage ? 28 : 8, height: 4)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentPage)
            }
        }
    }
}

// MARK: - Value Card

struct OnboardingValueCard: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(TonicColors.accent)
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline).bold()
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(10)
    }
}

// MARK: - Setup Card

struct OnboardingSetupCard: View {
    let icon: String
    let title: String
    let description: String
    let badgeText: String
    let badgeColor: Color
    let isGranted: Bool

    var action: (() -> Void)?
    var actionLabel: String = ""
    var secondaryAction: (() -> Void)?
    var secondaryLabel: String = ""
    var isLoading: Bool = false
    var toggleAction: ((Bool) -> Void)?

    @State private var toggleState = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(isGranted ? .green : TonicColors.accent)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                if isGranted {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.green)
                        .transition(.scale.combined(with: .opacity))
                } else {
                    Text(badgeText)
                        .font(.caption2).bold()
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(badgeColor.opacity(0.15))
                        .foregroundColor(badgeColor)
                        .cornerRadius(4)
                }
            }

            if !isGranted {
                if let toggleAction {
                    Toggle("Enable", isOn: $toggleState)
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .onChange(of: toggleState) { _, newValue in
                            toggleAction(newValue)
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                } else if let action {
                    HStack(spacing: 12) {
                        Button(action: action) {
                            if isLoading {
                                ProgressView()
                                    .scaleEffect(0.7)
                                    .frame(height: 14)
                            } else {
                                Text(actionLabel)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(isLoading)

                        if !secondaryLabel.isEmpty, let secondaryAction {
                            Button(action: secondaryAction) {
                                Text(secondaryLabel)
                                    .font(.caption)
                                    .underline()
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(10)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isGranted)
    }
}

// MARK: - Preview

#Preview {
    UnifiedOnboardingView(isPresented: .constant(true))
}
