//
//  DesignGalleryView.swift
//  Tonic
//
//  Living documentation for the TonicDS editorial design system — colors, type scale,
//  motion, and real component primitives. Replaces the legacy Atelier sandbox.
//

import SwiftUI

struct DesignGalleryView: View {
    @State private var activeFilter = 0
    @State private var search = ""
    @State private var toggleOn = true
    @State private var showingSheet = false

    var body: some View {
        TonicScreenScaffold {
            VStack(alignment: .leading, spacing: TonicDS.Space.xl) {
                TonicPageHeader("Design Gallery", subtitle: "The TonicDS editorial system")

                palettePolicy
                typeScale
                actionsAndFilters
                dataCards
                bandsAndConsoles
                rowsAndPanels
                statesAndSheets
                menuBarConsole
            }
        }
        .sheet(isPresented: $showingSheet) {
            SheetChrome(title: "Sheet chrome", onClose: { showingSheet = false }) {
                VStack(alignment: .leading, spacing: TonicDS.Space.md) {
                    MonoLabel("REVIEW")
                    Text("Sheets use canvas, hairlines, carved headings, and explicit footer actions.")
                        .tonicType(.body)
                        .foregroundStyle(TonicDS.Colors.textMuted)
                    TonicInlineNotice(message: "This is an internal component sample.", tone: .info)
                }
                .frame(width: 420, alignment: .leading)
            } footer: {
                TextAction("Cancel") { showingSheet = false }
                PrimaryPill("Apply") { showingSheet = false }
            }
            .frame(width: 520, height: 360)
        }
    }

    private var palettePolicy: some View {
        TonicSection(title: "PALETTE POLICY") {
            TonicBentoGrid(minTileWidth: 120) {
                swatch("Ink", TonicDS.Colors.ink)
                swatch("Console", TonicDS.Colors.console)
                swatch("Green band", TonicDS.Colors.deepGreen)
                swatch("Navy band", TonicDS.Colors.darkNavy)
                swatch("Soft stone", TonicDS.Colors.softStone)
                swatch("Coral taxonomy", TonicDS.Colors.accentCoral)
                swatch("Healthy data", TonicDS.Colors.statusSuccess)
                swatch("Critical data", TonicDS.Colors.statusCritical)
            }

            TonicInlineNotice(
                message: "Status color belongs to data, values, charts, and true machine state. Coral is taxonomy only.",
                tone: .info
            )
        }
    }

    private func swatch(_ name: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: TonicDS.Space.xs) {
            RoundedRectangle(cornerRadius: TonicDS.Radius.md, style: .continuous)
                .fill(color)
                .frame(height: 56)
                .overlay(
                    RoundedRectangle(cornerRadius: TonicDS.Radius.md, style: .continuous)
                        .strokeBorder(TonicDS.Colors.hairline, lineWidth: 1)
                )
            Text(name)
                .tonicType(.caption)
                .foregroundStyle(TonicDS.Colors.textMuted)
        }
    }

    private var typeScale: some View {
        TonicSection(title: "TYPOGRAPHY") {
            DataCard(lift: false) {
                VStack(alignment: .leading, spacing: TonicDS.Space.md) {
                    Text("All clear.").tonicType(.heroDisplay).foregroundStyle(TonicDS.Colors.textPrimary)
                    Text("Smart Scan").tonicType(.sectionDisplay).foregroundStyle(TonicDS.Colors.textPrimary)
                    Text("Card heading").tonicType(.cardHeading).foregroundStyle(TonicDS.Colors.textPrimary)
                    Text("Feature heading").tonicType(.featureHeading).foregroundStyle(TonicDS.Colors.textPrimary)
                    Text("Body copy is quiet, native, and specific. One oversized voice per screen.")
                        .tonicType(.body)
                        .foregroundStyle(TonicDS.Colors.textMuted)
                    HStack(alignment: .firstTextBaseline, spacing: TonicDS.Space.lg) {
                        MonoLabel("MONO LABEL")
                        Metric("42", unit: "%")
                        Text("micro note").tonicType(.micro).foregroundStyle(TonicDS.Colors.textMuted)
                    }
                }
            }
        }
    }

    private var actionsAndFilters: some View {
        TonicSection(title: "ACTIONS AND FILTERS") {
            DataCard(lift: false) {
                VStack(alignment: .leading, spacing: TonicDS.Space.md) {
                    HStack(spacing: TonicDS.Space.md) {
                        PrimaryPill("Primary", systemImage: "sparkles") {}
                        TextAction("Text action", systemImage: "arrow.up.right") {}
                    }

                    HStack(spacing: TonicDS.Space.sm) {
                        FilterPill(title: "Live", isActive: activeFilter == 0) { activeFilter = 0 }
                        FilterPill(title: "24h", isActive: activeFilter == 1) { activeFilter = 1 }
                        FilterPill(title: "7d", isActive: activeFilter == 2) { activeFilter = 2 }
                    }

                    HStack(spacing: TonicDS.Space.sm) {
                        CategoryFilterChip(title: "Space", isActive: activeFilter == 3, neutralWhenInactive: true) {
                            activeFilter = 3
                        }
                        CategoryFilterChip(title: "Apps", isActive: activeFilter == 4, size: .compact, neutralWhenInactive: true) {
                            activeFilter = 4
                        }
                        StatusChip("92°C", level: .caution)
                    }

                    TonicSearchField(placeholder: "Search components", text: $search)
                        .frame(minWidth: 180, idealWidth: 260, maxWidth: 320)
                }
            }
        }
    }

    private var dataCards: some View {
        TonicSection(title: "DATA CARDS") {
            TonicBentoGrid(minTileWidth: 220) {
                GaugeCard(label: "CPU", fraction: 0.29, displayValue: "", metricMode: .percent, history: sample(0.29))
                GaugeCard(label: "Memory", fraction: 0.67, displayValue: "", metricMode: .percent, history: sample(0.67))
                ChartCard(label: "Storage", displayValue: "412 GB", unit: "used", history: sample(0.78), fraction: 0.78)
            }
        }
    }

    private var bandsAndConsoles: some View {
        TonicSection(title: "BANDS AND CONSOLES") {
            ModuleBand(band: .green) {
                VStack(alignment: .leading, spacing: TonicDS.Space.lg) {
                    Image(systemName: "shield.lefthalf.filled.badge.checkmark")
                        .font(.system(size: 34, weight: .thin))
                        .foregroundStyle(TonicDS.Colors.onDark)
                    Text("Smart Scan").tonicType(.sectionDisplay).foregroundStyle(TonicDS.Colors.onDark)
                    Text("Solid bands carry module identity. The data still carries the color.")
                        .tonicType(.bodyLarge)
                        .foregroundStyle(TonicDS.Colors.onDarkMuted)
                    PrimaryPill("Run Smart Scan", systemImage: "sparkles", onDark: true) {}
                }
            }

            MonitoringConsole {
                ConsoleSection(title: "SYSTEM") {
                    ConsoleMetricRow(label: "CPU", value: "29%", color: TonicDS.status(forFraction: 0.29), level: .success)
                    ConsoleMetricRow(label: "Memory", value: "67%", color: TonicDS.status(forFraction: 0.67), level: .warning)
                    ConsoleMetricRow(label: "Network down", value: "4.2 MB/s", color: TonicDS.Chart.download)
                    ConsoleLegend(items: [
                        .init(label: "Read", value: "42 MB/s", color: TonicDS.Chart.read),
                        .init(label: "Write", value: "8 MB/s", color: TonicDS.Chart.write)
                    ])
                }
            }
        }
    }

    private var rowsAndPanels: some View {
        TonicSection(title: "ROWS AND SETTINGS PANELS") {
            TonicBentoGrid(minTileWidth: 260) {
                ScanCategoryCard {
                    VStack(alignment: .leading, spacing: TonicDS.Space.sm) {
                        MonoLabel("SPACE")
                        Text("Scan category cards use soft stone and compact proof rows.")
                            .tonicType(.caption)
                            .foregroundStyle(TonicDS.Colors.textMuted)
                        TonicHairline()
                        HStack {
                            Text("Caches").tonicType(.caption).foregroundStyle(TonicDS.Colors.textPrimary)
                            Spacer()
                            Text("2.4 GB").tonicType(.monoLabel).foregroundStyle(TonicDS.Colors.textMuted)
                        }
                    }
                }

                DataCard(lift: false) {
                    VStack(alignment: .leading, spacing: TonicDS.Space.sm) {
                        MonoLabel("OVERFLOW FADE")
                        ZStack(alignment: .trailing) {
                            HStack(spacing: TonicDS.Space.sm) {
                                ForEach(["System", "Developer", "Media", "Archives"], id: \.self) { title in
                                    FilterPill(title: title, isActive: title == "System") {}
                                }
                            }
                            TonicOverflowFade()
                                .frame(width: 64)
                        }
                    }
                }
            }

            SettingsPanel(title: "PREFERENCES") {
                TonicToggleRow(title: "Reduce motion", description: "Collapse movement to opacity or instant state changes.", isOn: $toggleOn)
                TonicPreferenceRow(title: "Mode", description: "Outlined pills and native controls stay compact.", showsDivider: false) {
                    HStack(spacing: TonicDS.Space.xs) {
                        FilterPill(title: "System", isActive: true) {}
                        FilterPill(title: "Dark", isActive: false) {}
                    }
                }
            }

            DataCard(lift: false) {
                VStack(spacing: 0) {
                    ForEach(rowSamples) { row in
                        SystemListRow {
                            Image(systemName: row.icon)
                                .font(.system(size: 14, weight: .regular))
                                .foregroundStyle(TonicDS.Colors.textMuted)
                                .frame(width: 22)
                        } center: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(row.title).tonicType(.body).foregroundStyle(TonicDS.Colors.textPrimary)
                                Text(row.subtitle).tonicType(.caption).foregroundStyle(TonicDS.Colors.textMuted)
                            }
                        } trailing: {
                            Text(row.value)
                                .tonicType(.monoLabel)
                                .monospacedDigit()
                                .foregroundStyle(TonicDS.Colors.textPrimary)
                        }
                        if row.id != rowSamples.last?.id {
                            TonicHairline()
                        }
                    }
                }
            }
        }
    }

    private var statesAndSheets: some View {
        TonicSection(title: "STATES AND SHEETS") {
            TonicBentoGrid(minTileWidth: 260) {
                DataCard(lift: false) {
                    VStack(alignment: .leading, spacing: TonicDS.Space.md) {
                        MonoLabel("LOADING")
                        TonicSkeleton(height: 28, width: 96)
                        TonicSkeleton(height: 42)
                        TonicProgressBar(fraction: 0.42, color: TonicDS.Colors.ink)
                    }
                }

                DataCard(lift: false) {
                    TonicEmptyState(
                        systemImage: "externaldrive",
                        title: "Nothing to explore yet",
                        message: "Run a Smart Scan to generate real findings.",
                        actionTitle: "Run scan"
                    ) {}
                    .frame(height: 190)
                }

                DataCard(lift: false) {
                    VStack(alignment: .leading, spacing: TonicDS.Space.md) {
                        MonoLabel("SHEET")
                        TonicErrorNotice(title: "Connection failed", message: "Retry from the current screen. Nothing was changed.")
                        TextAction("Open sheet", color: TonicDS.Colors.linkBlue) { showingSheet = true }
                    }
                }
            }
        }
    }

    private var menuBarConsole: some View {
        TonicSection(title: "MENU-BAR CONSOLE") {
            MonitoringConsole {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: TonicDS.Space.xs) {
                        Image(systemName: "cpu")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(TonicDS.Colors.onDarkMuted)
                        MonoLabel("CPU", color: TonicDS.Colors.onDarkMuted)
                        Spacer()
                        Metric("29", unit: "%", color: TonicDS.status(forFraction: 0.29), role: .metricSmall)
                    }
                    .frame(height: TonicDS.Layout.minRowHeight)

                    TonicHairline(color: TonicDS.Colors.hairlineOnDark)
                    NetworkSparklineChart(data: sample(0.29), color: TonicDS.status(forFraction: 0.29), height: TonicDS.Layout.MenuBar.chartHeight)
                        .padding(.vertical, TonicDS.Space.md)
                    TonicHairline(color: TonicDS.Colors.hairlineOnDark)
                    ConsoleMetricRow(label: "User", value: "18%", color: TonicDS.Chart.cpuUser)
                    ConsoleMetricRow(label: "System", value: "11%", color: TonicDS.Chart.cpuSystem)
                    ConsoleMetricRow(label: "Temperature", value: "61°C", color: TonicDS.status(forTempC: 61), level: .warning)
                }
            }
            .frame(width: TonicDS.Layout.MenuBar.width)
        }
    }

    private var rowSamples: [GalleryRow] {
        [
            GalleryRow(icon: "app", title: "Xcode", subtitle: "com.apple.dt.Xcode", value: "18.4 GB"),
            GalleryRow(icon: "folder", title: "DerivedData", subtitle: "~/Library/Developer/Xcode", value: "7.2 GB"),
            GalleryRow(icon: "cpu", title: "WindowServer", subtitle: "PID 421", value: "12.4%")
        ]
    }

    private func sample(_ peak: Double) -> [Double] {
        (0..<40).map { i in max(1, (sin(Double(i) / 4) * 0.3 + peak) * 100) }
    }
}

private struct GalleryRow: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let subtitle: String
    let value: String
}
