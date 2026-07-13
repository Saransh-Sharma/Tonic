#!/usr/bin/env swift
import Foundation

enum Failure: Error, CustomStringConvertible {
    case invalid(String)
    var description: String {
        switch self { case .invalid(let value): return value }
    }
}

func dictionary(_ value: Any?, _ name: String) throws -> [String: Any] {
    guard let value = value as? [String: Any] else { throw Failure.invalid("Missing object: \(name)") }
    return value
}

do {
    guard CommandLine.arguments.count == 2 else { throw Failure.invalid("usage: CatalogValidator catalog.json") }
    let data = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))
    guard data.count <= 2 * 1_024 * 1_024 else { throw Failure.invalid("Catalog exceeds 2 MiB") }
    let root = try dictionary(try JSONSerialization.jsonObject(with: data), "root")
    let body = try dictionary(root["body"], "body")
    guard body["schemaVersion"] as? Int == 1,
          body["kind"] as? String == "tonic.marketplace.catalog",
          body["revision"] as? NSNumber != nil else { throw Failure.invalid("Invalid signed body") }
    let signature = try dictionary(root["signature"], "signature")
    guard signature["algorithm"] as? String == "ed25519",
          let encoded = signature["value"] as? String,
          Data(base64Encoded: encoded)?.count == 64 else { throw Failure.invalid("Invalid Ed25519 signature field") }
    let payload = try dictionary(body["payload"], "payload")
    guard let entries = payload["entries"] as? [[String: Any]] else { throw Failure.invalid("Missing entries") }
    var identifiers = Set<String>()
    for entry in entries {
        guard let identifier = entry["id"] as? String, identifiers.insert(identifier).inserted,
              identifier.count <= 128 else { throw Failure.invalid("Duplicate or invalid provider ID") }
        guard let releases = entry["releases"] as? [[String: Any]], !releases.isEmpty else {
            throw Failure.invalid("Provider \(identifier) has no release")
        }
        for release in releases {
            guard let url = (release["artifactURL"] as? String).flatMap(URL.init(string:)), url.scheme == "https",
                  let hash = release["sha256"] as? String, hash.count == 64,
                  hash.allSatisfy(\.isHexDigit) else { throw Failure.invalid("Invalid release for \(identifier)") }
        }
    }
    print("Validated \(entries.count) signed catalog entries")
} catch {
    fputs("Catalog validation failed: \(error)\n", stderr)
    exit(1)
}
