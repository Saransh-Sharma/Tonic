//
//  DesignGalleryView.swift
//  Tonic
//
//  Living documentation for the TonicDS editorial design system — colors, type scale,
//  and components. Replaces the legacy Atelier sandbox.
//

import SwiftUI

struct DesignGalleryView: View {
    @State private var filter = 0
    @State private var search = ""

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: TonicDS.Space.xl) {
                TonicPageHeader("Design Gallery", subtitle: "The TonicDS editorial system")

                swatches
                typeScale
                components
                gauges
            }
            .frame(maxWidth: TonicDS.Layout.maxContentWidth, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .tonicScreenHPadding()
            .padding(.vertical, TonicDS.Space.xxl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(TonicDS.Colors.canvas)
    }

    private var swatches: some View {
        VStack(alignment: .leading, spacing: TonicDS.Space.sm) {
            MonoLabel("Color")
            TonicBentoGrid(minTileWidth: 120) {
                swatch("Ink", TonicDS.Colors.ink)
                swatch("Console", TonicDS.Colors.console)
                swatch("Deep Green", TonicDS.Colors.deepGreen)
                swatch("Navy", TonicDS.Colors.darkNavy)
                swatch("Soft Stone", TonicDS.Colors.softStone)
                swatch("Coral", TonicDS.Colors.accentCoral)
                swatch("Success", TonicDS.Colors.statusSuccess)
                swatch("Warning", TonicDS.Colors.statusWarning)
                swatch("Caution", TonicDS.Colors.statusCaution)
                swatch("Critical", TonicDS.Colors.statusCritical)
            }
        }
    }

    private func swatch(_ name: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: TonicDS.Space.xs) {
            RoundedRectangle(cornerRadius: TonicDS.Radius.md, style: .continuous)
                .fill(color).frame(height: 56)
                .overlay(RoundedRectangle(cornerRadius: TonicDS.Radius.md).strokeBorder(TonicDS.Colors.hairline, lineWidth: 1))
            Text(name).tonicType(.caption).foregroundStyle(TonicDS.Colors.textMuted)
        }
    }

    private var typeScale: some View {
        VStack(alignment: .leading, spacing: TonicDS.Space.sm) {
            MonoLabel("Typography")
            DataCard(lift: false) {
                VStack(alignment: .leading, spacing: TonicDS.Space.md) {
                    Text("Hero display").tonicType(.heroDisplay).foregroundStyle(TonicDS.Colors.textPrimary)
                    Text("Section display").tonicType(.sectionDisplay).foregroundStyle(TonicDS.Colors.textPrimary)
                    Text("Card heading").tonicType(.cardHeading).foregroundStyle(TonicDS.Colors.textPrimary)
                    Text("Feature heading").tonicType(.featureHeading).foregroundStyle(TonicDS.Colors.textPrimary)
                    Text("Body — the quiet UI voice.").tonicType(.body).foregroundStyle(TonicDS.Colors.textPrimary)
                    MonoLabel("MONO LABEL · 11")
                    Metric("42", unit: "%")
                }
            }
        }
    }

    private var components: some View {
        VStack(alignment: .leading, spacing: TonicDS.Space.sm) {
            MonoLabel("Components")
            DataCard(lift: false) {
                VStack(alignment: .leading, spacing: TonicDS.Space.md) {
                    HStack(spacing: TonicDS.Space.md) {
                        PrimaryPill("Primary") {}
                        TextAction("Text action") {}
                        FilterPill(title: "Filter", isActive: filter == 0) { filter = 0 }
                        FilterPill(title: "Inactive", isActive: filter == 1) { filter = 1 }
                    }
                    HStack(spacing: TonicDS.Space.md) {
                        CategoryFilterChip(title: "Category", isActive: true) {}
                        StatusChip("ACTIVE", color: TonicDS.Colors.statusSuccess)
                        StatusChip("92°C", color: TonicDS.Colors.statusCaution)
                    }
                    TonicSearchField(placeholder: "Search", text: $search).frame(width: 240)
                }
            }
        }
    }

    private var gauges: some View {
        VStack(alignment: .leading, spacing: TonicDS.Space.sm) {
            MonoLabel("Data cards")
            TonicBentoGrid(minTileWidth: 220) {
                GaugeCard(label: "Low", fraction: 0.3, displayValue: "30", unit: "%", history: sample(0.3))
                GaugeCard(label: "Elevated", fraction: 0.65, displayValue: "65", unit: "%", history: sample(0.65))
                GaugeCard(label: "Critical", fraction: 0.95, displayValue: "95", unit: "%", history: sample(0.95))
            }
        }
    }

    private func sample(_ peak: Double) -> [Double] {
        (0..<40).map { i in (sin(Double(i) / 4) * 0.3 + peak) * 100 }
    }
}
