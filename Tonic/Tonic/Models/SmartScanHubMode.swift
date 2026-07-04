//
//  SmartScanHubMode.swift
//  Tonic
//
//  Smart Scan hub lifecycle mode. Extracted from the legacy SmartScanHubView so it
//  survives the presentation-layer rewrite (it backs SmartCareSessionStore.hubMode).
//

import Foundation

enum SmartScanHubMode {
    case ready
    case scanning
    case running
    case results
}
