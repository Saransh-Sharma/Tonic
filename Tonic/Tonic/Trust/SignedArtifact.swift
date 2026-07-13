import CryptoKit
import Foundation

public enum ArtifactSignatureAlgorithm: String, Codable, Sendable {
    case ed25519
}

public struct ArtifactSignature: Codable, Equatable, Sendable {
    public var algorithm: ArtifactSignatureAlgorithm
    public var value: String

    public init(algorithm: ArtifactSignatureAlgorithm = .ed25519, value: String) {
        self.algorithm = algorithm
        self.value = value
    }

    public var decodedValue: Data? { Data(base64Encoded: value) }
}

public struct ArtifactValidity: Codable, Equatable, Sendable {
    public var issuedAt: Date
    public var expiresAt: Date

    public init(issuedAt: Date, expiresAt: Date) {
        self.issuedAt = issuedAt
        self.expiresAt = expiresAt
    }

    public func contains(_ date: Date) -> Bool {
        issuedAt <= date && date < expiresAt
    }
}

public struct SignedArtifactBody<Payload: Codable & Equatable & Sendable>: Codable, Equatable, Sendable {
    public var schemaVersion: Int
    public var kind: String
    public var revision: Int64
    public var validity: ArtifactValidity
    public var payload: Payload

    public init(schemaVersion: Int = 1, kind: String, revision: Int64,
                validity: ArtifactValidity, payload: Payload) {
        self.schemaVersion = schemaVersion
        self.kind = kind
        self.revision = revision
        self.validity = validity
        self.payload = payload
    }
}

public struct SignedArtifactEnvelope<Payload: Codable & Equatable & Sendable>: Codable, Equatable, Sendable {
    public var body: SignedArtifactBody<Payload>
    public var signature: ArtifactSignature

    public init(body: SignedArtifactBody<Payload>, signature: ArtifactSignature) {
        self.body = body
        self.signature = signature
    }
}

public enum SignedArtifactError: Error, Equatable, Sendable {
    case unsupportedSchema
    case unsupportedAlgorithm
    case invalidPublicKey
    case malformedSignature
    case invalidSignature
    case notYetValid
    case expired
    case rollback(current: Int64, proposed: Int64)
    case unexpectedKind(expected: String, actual: String)
}

public enum SignedArtifactCoding {
    public static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .millisecondsSince1970
        return encoder
    }

    public static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        return decoder
    }

    public static func canonicalData<Value: Encodable>(for value: Value) throws -> Data {
        try encoder().encode(value)
    }
}

public struct SignedArtifactVerifier: Sendable {
    private let publicKey: Curve25519.Signing.PublicKey

    public init(publicKeyData: Data) throws {
        do {
            publicKey = try Curve25519.Signing.PublicKey(rawRepresentation: publicKeyData)
        } catch {
            throw SignedArtifactError.invalidPublicKey
        }
    }

    public func verify<Payload>(
        _ envelope: SignedArtifactEnvelope<Payload>,
        expectedKind: String,
        minimumRevision: Int64? = nil,
        now: Date = Date()
    ) throws -> Payload where Payload: Codable & Equatable & Sendable {
        guard envelope.body.schemaVersion == 1 else { throw SignedArtifactError.unsupportedSchema }
        guard envelope.signature.algorithm == .ed25519 else { throw SignedArtifactError.unsupportedAlgorithm }
        guard envelope.body.kind == expectedKind else {
            throw SignedArtifactError.unexpectedKind(expected: expectedKind, actual: envelope.body.kind)
        }
        if now < envelope.body.validity.issuedAt { throw SignedArtifactError.notYetValid }
        if now >= envelope.body.validity.expiresAt { throw SignedArtifactError.expired }
        if let minimumRevision, envelope.body.revision < minimumRevision {
            throw SignedArtifactError.rollback(current: minimumRevision, proposed: envelope.body.revision)
        }
        guard let signature = envelope.signature.decodedValue else {
            throw SignedArtifactError.malformedSignature
        }
        let canonicalBody = try SignedArtifactCoding.canonicalData(for: envelope.body)
        guard publicKey.isValidSignature(signature, for: canonicalBody) else {
            throw SignedArtifactError.invalidSignature
        }
        return envelope.body.payload
    }
}

#if DEBUG
public enum SignedArtifactTestSupport {
    public static func sign<Payload>(
        body: SignedArtifactBody<Payload>,
        privateKey: Curve25519.Signing.PrivateKey
    ) throws -> SignedArtifactEnvelope<Payload> where Payload: Codable & Equatable & Sendable {
        let data = try SignedArtifactCoding.canonicalData(for: body)
        let signature = try privateKey.signature(for: data)
        return SignedArtifactEnvelope(
            body: body,
            signature: ArtifactSignature(value: signature.base64EncodedString())
        )
    }
}
#endif
