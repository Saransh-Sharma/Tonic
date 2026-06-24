import SwiftUI

struct DesignSandboxView: View {
    private enum Section: String, CaseIterable, Identifiable {
        case signature
        case surfaces
        case controls
        case metrics
        case composition

        var id: String { rawValue }

        var item: AtelierTabItem {
            switch self {
            case .signature:
                return .init(id: rawValue, title: "Signature", subtitle: "Brand language", systemImage: "sparkles")
            case .surfaces:
                return .init(id: rawValue, title: "Surfaces", subtitle: "Material stack", systemImage: "square.3.layers.3d.top.filled")
            case .controls:
                return .init(id: rawValue, title: "Controls", subtitle: "Actions & input", systemImage: "slider.horizontal.3")
            case .metrics:
                return .init(id: rawValue, title: "Metrics", subtitle: "Telemetry views", systemImage: "chart.line.uptrend.xyaxis")
            case .composition:
                return .init(id: rawValue, title: "Composition", subtitle: "Screen assembly", systemImage: "rectangle.3.group")
            }
        }
    }

    @State private var selectedSectionID = Section.signature.rawValue
    @State private var searchText = ""
    @State private var segmentedSelection: DemoSegment = .overview
    @State private var controlToggle = true

    private enum DemoSegment: String, CaseIterable {
        case overview = "Overview"
        case detail = "Detail"
        case audit = "Audit"
    }

    private var selectedSection: Section {
        Section(rawValue: selectedSectionID) ?? .signature
    }

    var body: some View {
        ZStack {
            AtelierAmbientCanvas(world: .smartScanPurple)

            VStack(spacing: AtelierLayout.md) {
                header
                    .atelierStagger(0)

                AtelierTabRail(items: Section.allCases.map(\.item), selectedID: $selectedSectionID)
                    .atelierStagger(1)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: AtelierLayout.md) {
                        hero
                            .atelierStagger(2)

                        selectedSectionView
                            .atelierStagger(3)

                        AtelierTicker(message: "TONIC ATELIER • EXTREME LUXURY • REUSABLE COMPONENTS • CINEMATIC MOTION")
                            .frame(height: 34)
                            .atelierStagger(4)
                    }
                    .padding(.bottom, AtelierLayout.md)
                }
            }
            .padding(.horizontal, AtelierLayout.md)
            .padding(.vertical, AtelierLayout.sm)
        }
    }

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Tonic Atelier")
                    .font(AtelierTypography.display)
                    .foregroundStyle(AtelierTokens.Color.porcelain)
                Text("Design Sandbox")
                    .font(AtelierTypography.body)
                    .foregroundStyle(AtelierTokens.Color.pearl.opacity(0.8))
            }

            Spacer()

            AtelierChip(title: Date.now.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()), icon: "calendar", tint: AtelierTokens.Color.champagne)
        }
    }

    private var hero: some View {
        AtelierCard {
            HStack(alignment: .top, spacing: AtelierLayout.md) {
                VStack(alignment: .leading, spacing: AtelierLayout.sm) {
                    Text("ATELIER MODE")
                        .font(AtelierTypography.micro)
                        .tracking(2)
                        .foregroundStyle(AtelierTokens.Color.champagne)

                    Text("Refined system command,\nbuilt as a luxury cockpit.")
                        .font(AtelierTypography.hero)
                        .foregroundStyle(AtelierTokens.Color.porcelain)
                        .lineSpacing(2)

                    Text("This catalog demonstrates the reusable Atelier component system used across the app.")
                        .font(AtelierTypography.body)
                        .foregroundStyle(AtelierTokens.Color.pearl.opacity(0.82))

                    HStack(spacing: AtelierLayout.xs) {
                        AtelierPrimaryButton(title: "Run Luxury Flow", icon: "play.fill") {}
                        AtelierSecondaryButton(title: "Component Index", icon: "square.grid.2x2") {}
                    }
                }

                Spacer()

                VStack(spacing: AtelierLayout.xs) {
                    AtelierRingMetric(title: "Aura", value: 0.86)
                    AtelierChip(title: "Cinematic", icon: "wand.and.stars")
                }
            }
        }
        .overlay {
            AtelierShimmerBorder(radius: AtelierLayout.radiusLg)
                .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private var selectedSectionView: some View {
        switch selectedSection {
        case .signature:
            AtelierCard(title: "Signature Components", subtitle: "Core badges, actions, and cards") {
                HStack(spacing: AtelierLayout.xs) {
                    AtelierChip(title: "Couture UI", icon: "sparkles")
                    AtelierChip(title: "Motion Driven", icon: "waveform.path.ecg")
                    AtelierChip(title: "Reusable", icon: "square.stack.3d.up")
                    Spacer()
                }
            }
        case .surfaces:
            AtelierCard(title: "Surface Hierarchy", subtitle: "Premium glass and layered materials") {
                HStack(spacing: AtelierLayout.sm) {
                    AtelierCard(title: "Hero Surface", subtitle: "Raised premium panel") {
                        Text("Use for flagship moments.")
                            .font(AtelierTypography.caption)
                            .foregroundStyle(AtelierTokens.Color.pearl.opacity(0.8))
                    }
                    AtelierCard(title: "Data Surface", subtitle: "Dense telemetry modules") {
                        Text("Use for heavy metrics.")
                            .font(AtelierTypography.caption)
                            .foregroundStyle(AtelierTokens.Color.pearl.opacity(0.8))
                    }
                }
            }
        case .controls:
            AtelierCard(title: "Control Language", subtitle: "Unified action + input vocabulary") {
                VStack(alignment: .leading, spacing: AtelierLayout.sm) {
                    HStack(spacing: AtelierLayout.xs) {
                        AtelierPrimaryButton(title: "Launch", icon: "play.fill") {}
                        AtelierSecondaryButton(title: "Schedule", icon: "calendar") {}
                        AtelierIconButton(systemName: "ellipsis") {}
                    }

                    AtelierSearchField(text: $searchText, placeholder: "Search modules")
                    AtelierSegmented(selected: $segmentedSelection)

                    Toggle("Realtime Monitoring", isOn: $controlToggle)
                        .toggleStyle(.switch)
                        .font(AtelierTypography.caption)
                        .foregroundStyle(AtelierTokens.Color.pearl)
                }
            }
        case .metrics:
            AtelierCard(title: "Data Components", subtitle: "Reusable telemetry modules") {
                VStack(spacing: AtelierLayout.sm) {
                    HStack(spacing: AtelierLayout.sm) {
                        AtelierMetricTile(title: "CPU", value: "42%", delta: "+3.4%")
                        AtelierMetricTile(title: "Memory", value: "11.8 GB", delta: "-0.6 GB", accent: AtelierTokens.Color.info)
                        AtelierMetricTile(title: "Network", value: "890 Mbps", delta: "+9%", accent: AtelierTokens.Color.success)
                    }

                    AtelierSparkline(values: [0.31, 0.55, 0.44, 0.63, 0.70, 0.59, 0.74, 0.78])
                        .frame(height: 60)

                    VStack(spacing: AtelierLayout.xs) {
                        AtelierTimelineRow(item: .init(time: "08:42", title: "Deep Scan", detail: "42 endpoints verified", tone: AtelierTokens.Color.success))
                        AtelierTimelineRow(item: .init(time: "10:07", title: "Thermal Spike", detail: "Auto-balanced to quiet mode", tone: AtelierTokens.Color.warning))
                        AtelierTimelineRow(item: .init(time: "12:19", title: "Memory Tune", detail: "Recovered 1.3 GB", tone: AtelierTokens.Color.info))
                    }
                }
            }
        case .composition:
            AtelierCard(title: "Bespoke Composition", subtitle: "Assembled from reusable primitives") {
                HStack(alignment: .top, spacing: AtelierLayout.sm) {
                    VStack(spacing: AtelierLayout.sm) {
                        AtelierCard(title: "Executive Overview", subtitle: "Morning posture") {
                            HStack(spacing: AtelierLayout.xs) {
                                AtelierChip(title: "No critical issues", icon: "checkmark.seal.fill", tint: AtelierTokens.Color.success)
                                AtelierChip(title: "Latency stable", icon: "speedometer", tint: AtelierTokens.Color.info)
                            }
                        }
                        AtelierCard(title: "Priority Queue", subtitle: "Next actions") {
                            VStack(spacing: AtelierLayout.xs) {
                                AtelierTimelineRow(item: .init(time: "Now", title: "Cache Prune", detail: "3.2 GB reclaimable", tone: AtelierTokens.Color.champagne))
                                AtelierTimelineRow(item: .init(time: "+12m", title: "Login Audit", detail: "5 startup agents", tone: AtelierTokens.Color.info))
                            }
                        }
                    }

                    VStack(spacing: AtelierLayout.sm) {
                        AtelierRingMetric(title: "Confidence", value: 0.93, tint: AtelierTokens.Color.success)
                        AtelierMetricTile(title: "Security", value: "A+", delta: "stable", accent: AtelierTokens.Color.success)
                    }
                    .frame(width: 260)
                }
            }
        }
    }
}

#Preview {
    DesignSandboxView()
        .frame(minWidth: 1100, minHeight: 760)
}
