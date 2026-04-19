import CryptoKit
import Foundation
import os

private let log = Logger(subsystem: "com.cactushack.MeshNode", category: "mesh.crypto")

/// AES-256-GCM symmetric encryption for mesh messages.
///
/// Every device that installs the app via Xcode receives the same pre-shared key.
/// Messages broadcast over BLE are encrypted so only devices with this key can
/// read them — providing both confidentiality and authenticity (GCM is AEAD).
enum MeshCrypto {
    // 256-bit pre-shared key (hex-encoded).
    // All devices running this app share this key.
    // Change this value to create a new "network" that older builds can't read.
    private static let keyHex = "a1b2c3d4e5f60718293a4b5c6d7e8f90a1b2c3d4e5f60718293a4b5c6d7e8f90"

    private static let symmetricKey: SymmetricKey = {
        var bytes = [UInt8]()
        var hex = keyHex[...]
        while hex.count >= 2 {
            let pair = hex.prefix(2)
            hex = hex.dropFirst(2)
            bytes.append(UInt8(pair, radix: 16)!)
        }
        return SymmetricKey(data: bytes)
    }()

    /// 4-byte magic header so receivers can distinguish encrypted from plaintext.
    private static let header = Data([0x4D, 0x45, 0x4E, 0x43]) // "MENC"

    /// Encrypt plaintext data with AES-256-GCM.
    /// Returns: header + nonce (12 bytes) + ciphertext + tag (16 bytes).
    static func encrypt(_ plaintext: Data) -> Data? {
        guard let sealed = try? AES.GCM.seal(plaintext, using: symmetricKey) else {
            return nil
        }
        guard let combined = sealed.combined else { return nil }
        return header + combined
    }

    /// Decrypt data produced by `encrypt(_:)`.
    /// Returns nil if the data is malformed, too short, or the key doesn't match.
    static func decrypt(_ data: Data) -> Data? {
        guard data.count > header.count else {
            log.warning("Decrypt: data too short (\(data.count) bytes)")
            return nil
        }
        guard data.prefix(header.count) == header else {
            log.warning("Decrypt: missing MENC header (\(data.count) bytes)")
            return nil
        }
        let payload = data.dropFirst(header.count)
        do {
            let box = try AES.GCM.SealedBox(combined: payload)
            let plaintext = try AES.GCM.open(box, using: symmetricKey)
            return plaintext
        } catch {
            log.warning("Decrypt failed (\(data.count) bytes): \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    /// True if the data starts with the encryption header.
    static func isEncrypted(_ data: Data) -> Bool {
        data.count > header.count && data.prefix(header.count) == header
    }
}
