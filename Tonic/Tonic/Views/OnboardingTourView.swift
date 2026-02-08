//
//  OnboardingTourView.swift
//  Tonic
//
//  Feature walkthrough tour for returning users — restyled to match unified onboarding
//

import SwiftUI

struct OnboardingTourView: View {
    @Binding var isPresented: Bool
    @State private var currentStep = 0
    @State private var direction: SlideDirection = .forward
    @State private var animateContent = false

    @Environment(\.dismiss) private var dismiss

    private let totalSteps = 5

    enum SlideDirection {
        case forward, backward
    }

    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Expanding pill progress bar
                OnboardingProgressBar(currentPage: currentStep, totalPages: totalSteps)
                    .padding(.top, 20)
                    .padding(.horizontal, 24)

                // Page content
                ZStack {
                    pageContent
                        .id(currentStep)
                        .transition(pageTransition)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()

                // Navigation buttons
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
        switch currentStep {
        case 0: welcomeTour
        case 1: dashboardTour
        case 2: navigationTour
        case 3: maintenanceTour
        default: finalTour
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

    // MARK: - Tour Steps

    private var welcomeTour: some View {
        tourPage(
            icon: "sparkles",
            title: "Redesigned for macOS",
            subtitle: "Let's explore the improvements",
            cards: [
                ("sidebar.left", "Improved Navigation", "Organized sidebar with grouped sections for better clarity"),
                ("square.grid.2x2", "Native Components", "Cards and controls redesigned to feel native to macOS"),
                ("moon.stars.fill", "Light & Dark Mode", "Full support with proper contrast and readability in both modes"),
            ]
        )
    }

    private var dashboardTour: some View {
        tourPage(
            icon: "rectangle.grid.1x2.fill",
            title: "Dashboard",
            subtitle: "Health at a glance",
            cards: [
                ("heart.circle.fill", "Health Ring", "Visual indicator of your system's overall health and performance"),
                ("bolt.fill", "Smart Scan", "Single primary button to run a comprehensive system scan"),
                ("exclamationmark.triangle.fill", "Recommendations", "Priority-based cleanup suggestions organized by category"),
            ]
        )
    }

    private var navigationTour: some View {
        tourPage(
            icon: "list.bullet.indent",
            title: "Navigation",
            subtitle: "Organized for easy access",
            cards: [
                ("rectangle.split.2x1", "Grouped Sections", "Features are organized into logical groups with visual separators"),
                ("command", "Command Palette", "Press Cmd+K to quickly search and navigate to any screen"),
                ("square.and.pencil", "Easier Selection", "Cleaner interface makes it easier to find what you're looking for"),
            ]
        )
    }

    private var maintenanceTour: some View {
        tourPage(
            icon: "sparkle",
            title: "Smart Scan & Clean",
            subtitle: "Streamlined cleanup workflow",
            cards: [
                ("circle.fill", "Progress Indicators", "Clear visual feedback showing scan stages and progress"),
                ("checkmark.circle.fill", "Review First", "Always review before cleaning to avoid removing important files"),
                ("xmark.circle.fill", "Easy Cancel", "Cancel anytime without partial or incomplete results"),
            ]
        )
    }

    private var finalTour: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundColor(.green)
                .scaleEffect(animateContent ? 1.0 : 0.5)
                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: animateContent)

            VStack(spacing: 8) {
                Text("You're Ready!")
                    .font(.title).bold()
                    .offset(y: animateContent ? 0 : 25)
                    .opacity(animateContent ? 1 : 0)
                    .animation(.easeOut(duration: 0.4).delay(0.08), value: animateContent)

                Text("Start exploring Tonic")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .offset(y: animateContent ? 0 : 20)
                    .opacity(animateContent ? 1 : 0)
                    .animation(.easeOut(duration: 0.35).delay(0.16), value: animateContent)
            }

            VStack(spacing: 8) {
                OnboardingValueCard(icon: "doc.plaintext", title: "More Details", description: "Visit Settings for complete documentation and help")
                    .offset(y: animateContent ? 0 : 15)
                    .opacity(animateContent ? 1 : 0)
                    .animation(.easeOut(duration: 0.3).delay(0.24), value: animateContent)

                OnboardingValueCard(icon: "questionmark.circle.fill", title: "Need Help?", description: "Right-click any element for context-specific tips")
                    .offset(y: animateContent ? 0 : 15)
                    .opacity(animateContent ? 1 : 0)
                    .animation(.easeOut(duration: 0.3).delay(0.32), value: animateContent)

                OnboardingValueCard(icon: "hand.raised.fill", title: "Take Your Time", description: "Experiment with different features at your own pace")
                    .offset(y: animateContent ? 0 : 15)
                    .opacity(animateContent ? 1 : 0)
                    .animation(.easeOut(duration: 0.3).delay(0.40), value: animateContent)
            }
            .padding(.horizontal, 32)

            Text("This tour will not show again")
                .font(.caption)
                .foregroundColor(.secondary)
                .opacity(animateContent ? 1 : 0)
                .animation(.easeOut(duration: 0.3).delay(0.5), value: animateContent)

            Spacer()
        }
    }

    // MARK: - Tour Page Template

    private func tourPage(
        icon: String,
        title: String,
        subtitle: String,
        cards: [(String, String, String)]
    ) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                Spacer().frame(height: 24)

                // Gradient hero icon
                Image(systemName: icon)
                    .font(.system(size: 56))
                    .foregroundStyle(.linearGradient(
                        colors: [TonicColors.accent, TonicColors.pro],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .scaleEffect(animateContent ? 1.0 : 0.5)
                    .animation(.spring(response: 0.4, dampingFraction: 0.7), value: animateContent)

                Text(title)
                    .font(.title).bold()
                    .offset(y: animateContent ? 0 : 25)
                    .opacity(animateContent ? 1 : 0)
                    .animation(.easeOut(duration: 0.4).delay(0.08), value: animateContent)

                Text(subtitle)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .offset(y: animateContent ? 0 : 20)
                    .opacity(animateContent ? 1 : 0)
                    .animation(.easeOut(duration: 0.35).delay(0.16), value: animateContent)

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

    // MARK: - Navigation

    private var navigationButtons: some View {
        HStack(spacing: 12) {
            Button("Skip Tour") {
                completeTour()
            }
            .buttonStyle(.borderless)
            .foregroundColor(.secondary)

            Spacer()

            if currentStep > 0 {
                Button("Back") {
                    goBack()
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }

            if currentStep < totalSteps - 1 {
                Button("Next") {
                    goForward()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            } else {
                Button("Get Started") {
                    completeTour()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
    }

    // MARK: - Actions

    private func goForward() {
        animateContent = false
        direction = .forward
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
            currentStep += 1
        }
        triggerEntrance()
    }

    private func goBack() {
        animateContent = false
        direction = .backward
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
            currentStep -= 1
        }
        triggerEntrance()
    }

    private func triggerEntrance() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            animateContent = true
        }
    }

    private func completeTour() {
        UserDefaults.standard.set(true, forKey: "hasSeenFeatureTour")
        isPresented = false
        dismiss()
    }
}

#Preview {
    OnboardingTourView(isPresented: .constant(true))
}
