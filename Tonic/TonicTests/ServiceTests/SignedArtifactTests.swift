import CryptoKit
import XCTest
@testable import Tonic

final class SignedArtifactTests: XCTestCase {
    private struct Payload: Codable, Equatable, Sendable { var value: String }

    private func envelope(revision: Int64 = 4, now: Date = Date(timeIntervalSince1970: 1_000),
                          key: Curve25519.Signing.PrivateKey) throws -> SignedArtifactEnvelope<Payload> {
        let body = SignedArtifactBody(
            kind: "test.payload",
            revision: revision,
            validity: ArtifactValidity(issuedAt: now.addingTimeInterval(-10),
                                       expiresAt: now.addingTimeInterval(10)),
            payload: Payload(value: "trusted")
        )
        return try SignedArtifactTestSupport.sign(body: body, privateKey: key)
    }

    func testValidSignatureReturnsPayload() throws {
        let now = Date(timeIntervalSince1970: 1_000)
        let key = Curve25519.Signing.PrivateKey()
        let verifier = try SignedArtifactVerifier(publicKeyData: key.publicKey.rawRepresentation)
        XCTAssertEqual(try verifier.verify(envelope(now: now, key: key), expectedKind: "test.payload", now: now),
                       Payload(value: "trusted"))
    }

    func testTamperExpiryAndRollbackFailClosed() throws {
        let now = Date(timeIntervalSince1970: 1_000)
        let key = Curve25519.Signing.PrivateKey()
        let verifier = try SignedArtifactVerifier(publicKeyData: key.publicKey.rawRepresentation)
        var tampered = try envelope(now: now, key: key)
        tampered.body.payload.value = "changed"
        XCTAssertThrowsError(try verifier.verify(tampered, expectedKind: "test.payload", now: now))
        XCTAssertThrowsError(try verifier.verify(try envelope(now: now, key: key), expectedKind: "test.payload",
                                                 now: now.addingTimeInterval(20)))
        XCTAssertThrowsError(try verifier.verify(try envelope(revision: 3, now: now, key: key),
                                                 expectedKind: "test.payload", minimumRevision: 4, now: now))
    }

    func testCompatibilityRequiresExactBuildAndArchitecture() {
        let manifest = CompatibilityManifest(rules: [
            CompatibilityRule(id: "approved", capability: .automaticSpaceContexts,
                              allowedBuilds: ["25F70"], allowedArchitectures: ["arm64"],
                              isEnabled: true, reason: "Validated")
        ])
        XCTAssertTrue(manifest.decision(for: .automaticSpaceContexts,
                                        runtime: .init(osBuild: "25F70", architecture: "arm64")).isEnabled)
        XCTAssertFalse(manifest.decision(for: .automaticSpaceContexts,
                                         runtime: .init(osBuild: "25F71", architecture: "arm64")).isEnabled)
    }
}
