//
//  OnboardingTourView.swift
//  Tonic
//
//  First-launch feature walkthrough tour explaining redesigned UI elements
//  Task ID: fn-4-as7.19
//

import SwiftUI

struct OnboardingTourView: View {
    @Binding var isPresented: Bool
    @State private var currentStep = 0

    @Environment(\.dismiss) private var dismiss

    private let totalSteps = 5

    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Progress indicator
                HStack {
                    ForEach(0..<totalSteps, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(index <= currentStep ? DesignTokens.Colors.accent : Color.gray.opacity(0.3))
                            .frame(width: index == currentStep ? 32 : 8, height: 4)
                            .animation(.easeInOut(duration: 0.3), value: currentStep)
                    }
                }
                .padding()

                Spacer()

                // Content
                switch currentStep {
                case 0:
                    welcomeTour
                case 1:
                    dashboardTour
                case 2:
                    navigationTour
                case 3:
                    maintenanceTour
                default:
                    finalTour
                }

                Spacer()

                // Navigation buttons
                navigationButtons
            }
        }
        .frame(minWidth: 600, minHeight: 500)
    }

    // MARK: - Tour Steps

    private var welcomeTour: some View {
        VStack(spacing: 24) {
            Image(systemName: "sparkles")
                .font(.system(size: 60))
                .foregroundStyle(.linearGradient(
                    colors: [DesignTokens.Colors.accent, Color.blue],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))

            VStack(spacing: 12) {
                Text("Redesigned for macOS")
                    .font(.system(size: 28, weight: .bold))

                Text("Let's explore the improvements")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 16) {
                tourFeature(
                    icon: "sidebar.left",
                    title: "Improved Navigation",
                    description: "Organized sidebar with grouped sections for better clarity"
                )

                tourFeature(
                    icon: "square.grid.2x2",
                    title: "Native Components",
                    description: "Cards and controls redesigned to feel native to macOS"
                )

                tourFeature(
                    icon: "moon.stars.fill",
                    title: "Light & Dark Mode",
                    description: "Full support with proper contrast and readability in both modes"
                )
            }
            .padding()
        }
    }

    private var dashboardTour: some View {
        VStack(spacing: 24) {
            Image(systemName: "rectangle.grid.1x2.fill")
                .font(.system(size: 60))
                .foregroundColor(DesignTokens.Colors.accent)

            VStack(spacing: 12) {
                Text("Dashboard")
                    .font(.system(size: 28, weight: .bold))

                Text("Health at a glance")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 16) {
                tourFeature(
                    icon: "heart.circle.fill",
                    title: "Health Ring",
                    description: "Visual indicator of your system's overall health and performance"
                )

                tourFeature(
                    icon: "bolt.fill",
                    title: "Smart Scan",
                    description: "Single primary button to run a comprehensive system scan"
                )

                tourFeature(
                    icon: "exclamationmark.triangle.fill",
                    title: "Recommendations",
                    description: "Priority-based cleanup suggestions organized by category"
                )

                tourFeature(
                    icon: "clock.fill",
                    title: "Recent Activity",
                    description: "Quick view of your last actions with detailed history"
                )
            }
            .padding()
        }
    }

    private var navigationTour: some View {
        VStack(spacing: 24) {
            Image(systemName: "list.bullet.indent")
                .font(.system(size: 60))
                .foregroundColor(DesignTokens.Colors.accent)

            VStack(spacing: 12) {
                Text("Navigation")
                    .font(.system(size: 28, weight: .bold))

                Text("Organized for easy access")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 16) {
                tourFeature(
                    icon: "rectangle.split.2x1",
                    title: "Grouped Sections",
                    description: "Features are organized into logical groups with visual separators"
                )

                tourFeature(
                    icon: "command",
                    title: "Command Palette",
                    description: "Press Cmd+K to quickly search and navigate to any screen"
                )

                tourFeature(
                    icon: "square.and.pencil",
                    title: "Easier Selection",
                    description: "Cleaner interface makes it easier to find what you're looking for"
                )
            }
            .padding()
        }
    }

    private var maintenanceTour: some View {
        VStack(spacing: 24) {
            Image(systemName: "sparkle")
                .font(.system(size: 60))
                .foregroundColor(DesignTokens.Colors.accent)

            VStack(spacing: 12) {
                Text("Smart Scan & Clean")
                    .font(.system(size: 28, weight: .bold))

                Text("Streamlined cleanup workflow")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 16) {
                tourFeature(
                    icon: "circle.fill",
                    title: "Progress Indicators",
                    description: "Clear visual feedback showing scan stages and progress"
                )

                tourFeature(
                    icon: "checkmark.circle.fill",
                    title: "Review First",
                    description: "Always review before cleaning to avoid removing important files"
                )

                tourFeature(
                    icon: "xmark.circle.fill",
                    title: "Easy Cancel",
                    description: "Cancel anytime without partial or incomplete results"
                )
            }
            .padding()
        }
    }

    private var finalTour: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)

            VStack(spacing: 12) {
                Text("You're Ready!")
                    .font(.system(size: 28, weight: .bold))

                Text("Start exploring Tonic")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 16) {
                tourFeature(
                    icon: "doc.plaintext",
                    title: "More Details",
                    description: "Visit Settings for complete documentation and help"
                )

                tourFeature(
                    icon: "questionmark.circle.fill",
                    title: "Need Help?",
                    description: "Right-click any element for context-specific tips"
                )

                tourFeature(
                    icon: "hand.raised.fill",
                    title: "Take Your Time",
                    description: "Experiment with different features at your own pace"
                )
            }
            .padding()

            Text("This tour will not show again")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Helper Views

    private func tourFeature(icon: String, title: String, description: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(DesignTokens.Colors.accent)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }

    private var navigationButtons: some View {
        HStack(spacing: 16) {
            Button("Skip Tour") {
                completeTour()
            }
            .buttonStyle(.borderless)
            .foregroundColor(.secondary)

            Spacer()

            if currentStep > 0 {
                Button("Back") {
                    withAnimation {
                        currentStep -= 1
                    }
                }
                .buttonStyle(.bordered)
            }

            if currentStep < totalSteps - 1 {
                Button("Next") {
                    withAnimation {
                        currentStep += 1
                    }
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button("Get Started") {
                    completeTour()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }

    // MARK: - Actions

    private func completeTour() {
        UserDefaults.standard.set(true, forKey: "hasSeenFeatureTour")
        isPresented = false
        dismiss()
    }
}

#Preview {
    OnboardingTourView(isPresented: .constant(true))
}
