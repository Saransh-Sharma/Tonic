#!/usr/bin/env swift

import AppKit
import Foundation

struct TextStyles {
    let title: [NSAttributedString.Key: Any]
    let subtitle: [NSAttributedString.Key: Any]
    let sectionHeader: [NSAttributedString.Key: Any]
    let body: [NSAttributedString.Key: Any]
    let bullet: [NSAttributedString.Key: Any]

    init() {
        // Use fixed colors to avoid dynamic appearance mismatches when rendering/converting.
        let titleColor = NSColor.black
        let subtleColor = NSColor(calibratedWhite: 0.35, alpha: 1.0)

        let headerParagraph = NSMutableParagraphStyle()
        headerParagraph.paragraphSpacingBefore = 0
        headerParagraph.paragraphSpacing = 6

        let bodyParagraph = NSMutableParagraphStyle()
        bodyParagraph.paragraphSpacing = 4
        bodyParagraph.lineBreakMode = .byWordWrapping

        let bulletParagraph = NSMutableParagraphStyle()
        bulletParagraph.paragraphSpacing = 3
        bulletParagraph.lineBreakMode = .byWordWrapping
        bulletParagraph.firstLineHeadIndent = 0
        bulletParagraph.headIndent = 12

        self.title = [
            .font: NSFont.boldSystemFont(ofSize: 18),
            .foregroundColor: titleColor,
            .paragraphStyle: headerParagraph,
        ]
        self.subtitle = [
            .font: NSFont.systemFont(ofSize: 9),
            .foregroundColor: subtleColor,
            .paragraphStyle: bodyParagraph,
        ]
        self.sectionHeader = [
            .font: NSFont.boldSystemFont(ofSize: 12),
            .foregroundColor: titleColor,
            .paragraphStyle: headerParagraph,
        ]
        self.body = [
            .font: NSFont.systemFont(ofSize: 10),
            .foregroundColor: titleColor,
            .paragraphStyle: bodyParagraph,
        ]
        self.bullet = [
            .font: NSFont.systemFont(ofSize: 10),
            .foregroundColor: titleColor,
            .paragraphStyle: bulletParagraph,
        ]
    }
}

func makeSection(
    styles: TextStyles,
    title: String,
    paragraphs: [String] = [],
    bullets: [String] = []
) -> NSAttributedString {
    let out = NSMutableAttributedString()

    out.append(NSAttributedString(string: title + "\n", attributes: styles.sectionHeader))

    for paragraph in paragraphs {
        out.append(NSAttributedString(string: paragraph + "\n", attributes: styles.body))
    }

    if !bullets.isEmpty {
        for bullet in bullets {
            out.append(NSAttributedString(string: "- " + bullet + "\n", attributes: styles.bullet))
        }
    }

    out.append(NSAttributedString(string: "\n", attributes: styles.body))
    return out
}

@discardableResult
func drawAttributedBlock(_ text: NSAttributedString, in rectFromTop: CGRect, pageHeight: CGFloat) -> CGFloat {
    let maxSize = CGSize(width: rectFromTop.width, height: .greatestFiniteMagnitude)
    let bounds = text.boundingRect(with: maxSize, options: [.usesLineFragmentOrigin, .usesFontLeading])
    let height = ceil(bounds.height)
    // We do layout using a top-left origin (y increases downward). PDF drawing uses a bottom-left origin.
    let drawY = pageHeight - rectFromTop.minY - height
    let drawRect = CGRect(x: rectFromTop.minX, y: drawY, width: rectFromTop.width, height: height)
    text.draw(with: drawRect, options: [.usesLineFragmentOrigin, .usesFontLeading])
    return height
}

func ensureDirExists(_ path: String) throws {
    let url = URL(fileURLWithPath: path, isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
}

func main() throws {
    let outputPath: String = {
        if CommandLine.arguments.count >= 2 {
            return CommandLine.arguments[1]
        }
        return "output/pdf/tonic-app-summary.pdf"
    }()

    try ensureDirExists("output/pdf")
    try ensureDirExists("tmp/pdfs")

    let pageSize = CGSize(width: 612, height: 792) // US Letter (portrait)
    var mediaBox = CGRect(origin: .zero, size: pageSize)

    guard let consumer = CGDataConsumer(url: URL(fileURLWithPath: outputPath) as CFURL) else {
        throw NSError(domain: "pdf", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create PDF consumer"])
    }
    guard let pdfContext = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
        throw NSError(domain: "pdf", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to create PDF context"])
    }

    pdfContext.beginPDFPage(nil)
    // Use a standard (unflipped) PDF coordinate system so renderers (Preview/sips) display text correctly.
    // We convert top-left layout rects to PDF rects in `drawAttributedBlock`.
    let gfx = NSGraphicsContext(cgContext: pdfContext, flipped: false)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = gfx
    defer {
        NSGraphicsContext.restoreGraphicsState()
        pdfContext.endPDFPage()
        pdfContext.closePDF()
    }

    let styles = TextStyles()

    let margin: CGFloat = 36
    let gutter: CGFloat = 18
    let columnWidth = (pageSize.width - margin * 2 - gutter) / 2

    let fullWidthRect = CGRect(x: margin, y: margin, width: pageSize.width - margin * 2, height: pageSize.height - margin * 2)

    // Background
    NSColor.white.setFill()
    CGRect(x: 0, y: 0, width: pageSize.width, height: pageSize.height).fill()

    // Header (full width)
    let header = NSMutableAttributedString()
    header.append(NSAttributedString(string: "Tonic - App Summary\n", attributes: styles.title))

    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .none
    let generatedDate = formatter.string(from: Date())
    header.append(NSAttributedString(
        string: "Generated \(generatedDate) from repo docs: README.md, ARCHITECTURE.md, SETUP.md\n",
        attributes: styles.subtitle
    ))

    var cursorY = margin
    cursorY += drawAttributedBlock(header, in: CGRect(x: fullWidthRect.minX, y: cursorY, width: fullWidthRect.width, height: 0), pageHeight: pageSize.height)
    cursorY += 8

    let leftX = margin
    let rightX = margin + columnWidth + gutter
    let columnTopY = cursorY
    let columnHeight = pageSize.height - margin - columnTopY

    let leftCursor = columnTopY
    let rightCursor = columnTopY

    // Content (based only on repo evidence)
    let whatItIs = makeSection(
        styles: styles,
        title: "What it is",
        paragraphs: [
            "Tonic is a native macOS system management and optimization app built with SwiftUI. It combines disk cleanup, performance monitoring, app management, and menu bar widgets in one interface."
        ]
    )

    let whoItsFor = makeSection(
        styles: styles,
        title: "Who it's for",
        paragraphs: [
            "Mac users who want a polished, native utility to monitor system health, reclaim disk space, and manage startup/app behavior."
        ]
    )

    let whatItDoes = makeSection(
        styles: styles,
        title: "What it does",
        bullets: [
            "Real-time monitoring (CPU, memory, disk, network, battery, GPU, sensors) in-app and via menu bar widgets.",
            "Smart Scan: multi-stage scan that produces a health score and recommendations.",
            "Deep Clean across common clutter categories (caches, logs, temp files, browser cache, downloads, trash, dev artifacts, Docker, Xcode).",
            "Disk Analysis: directory browser, large-files view, and treemap visualization (with Full Disk Access guidance).",
            "App Management: app inventory, login items, complete uninstall (bundle + associated files).",
            "Update checking (Sparkle) and notification rules for thresholds (CPU, memory pressure, disk, network, weather).",
            "Optional fan control via a privileged helper tool for root-level SMC write operations."
        ]
    )

    let howItWorks = makeSection(
        styles: styles,
        title: "How it works (repo evidence)",
        bullets: [
            "SwiftUI app entry in `TonicApp.swift` with an `AppDelegate` for macOS integration; main navigation uses `NavigationSplitView` in `ContentView.swift`.",
            "MVVM-style separation: Views bind to Models and singleton Services using the `@Observable` pattern (Swift 6).",
            "Monitoring + widgets: `WidgetDataManager` collects metrics and updates UI; `WidgetCoordinator` manages NSStatusItem-based menu bar widgets and popovers per widget type.",
            "Cleanup: `SmartScanEngine` orchestrates scanning and results; `DeepCleanEngine` performs categorized cleanup (often via filesystem scanning utilities).",
            "Permissions + security: permission checks/requests gate Full Disk Access, notifications, and location (for weather).",
            "Privileged ops: `PrivilegedHelperManager` communicates over XPC with `TonicHelperTool` for root-required actions (e.g., fan write control).",
            "External data: `WeatherService` fetches weather using the Open-Meteo API (no API key required).",
            "Persistence: widget/settings preferences stored via `@AppStorage` / UserDefaults."
        ]
    )

    let howToRun = makeSection(
        styles: styles,
        title: "How to run (minimal)",
        bullets: [
            "Prereqs: macOS 14+, Xcode (SETUP.md: 16.0+), and XcodeGen.",
            "Generate the project: `xcodegen generate` (uses `Tonic/project.yml`).",
            "Open and run: `open Tonic/Tonic.xcodeproj` then Cmd+R in Xcode.",
            "Grant permissions as prompted (Full Disk Access recommended; location only needed for weather widget)."
        ]
    )

    // Draw left column
    let leftRect = CGRect(x: leftX, y: leftCursor, width: columnWidth, height: columnHeight)
    var remainingLeftRect = leftRect

    for block in [whatItIs, whoItsFor, whatItDoes] {
        let used = drawAttributedBlock(block, in: remainingLeftRect, pageHeight: pageSize.height)
        remainingLeftRect.origin.y += used
        remainingLeftRect.size.height -= used
    }

    // Draw right column
    let rightRect = CGRect(x: rightX, y: rightCursor, width: columnWidth, height: columnHeight)
    var remainingRightRect = rightRect

    for block in [howItWorks, howToRun] {
        let used = drawAttributedBlock(block, in: remainingRightRect, pageHeight: pageSize.height)
        remainingRightRect.origin.y += used
        remainingRightRect.size.height -= used
    }

    // Guard against overflow (single page requirement)
    let overflowThreshold: CGFloat = 6
    if remainingLeftRect.size.height < overflowThreshold || remainingRightRect.size.height < overflowThreshold {
        throw NSError(domain: "pdf", code: 3, userInfo: [
            NSLocalizedDescriptionKey: "Content overflowed a single page; tighten copy or reduce font sizes."
        ])
    }

    pdfContext.strokePath()
    fflush(stdout)
    print("Wrote PDF: \(outputPath)")
}

do {
    try main()
} catch {
    fputs("Error: \(error)\n", stderr)
    exit(1)
}
