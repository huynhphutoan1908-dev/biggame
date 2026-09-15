import Foundation
import Crypto

// Parsed summary of a .3105 container (same algorithm as update_pack_id.py).
struct PackInfo {
    var packageID = ""
    var schemaVersion = 0
    var passwordProtected = false
    var projectName = ""
    var author = ""
    var bundleIDs: [String] = []
    var rules: [(path: String, size: Int)] = []
    var digestCount = 0
    var internStrings: [String] = []
    var magicOK = false
    var fingerprintOK = false
}

enum PackError: LocalizedError {
    case badHeader, badEnvelope, decrypt(String), badPayload

    var errorDescription: String? {
        switch self {
        case .badHeader: return "Thieu magic header '3105PATCH\\0' — khong phai file .3105"
        case .badEnvelope: return "Envelope plist khong doc duoc"
        case .decrypt(let m): return "Giai ma AES-GCM that bai: \(m)"
        case .badPayload: return "Payload plist khong doc duoc"
        }
    }
}

func inspectPack(_ data: Data) throws -> PackInfo {
    var info = PackInfo()
    let magic = Data("3105PATCH\0".utf8)
    guard data.count > magic.count, data.prefix(magic.count) == magic else {
        throw PackError.badHeader
    }
    info.magicOK = true

    guard let env = try? PropertyListSerialization
            .propertyList(from: data.subdata(in: magic.count..<data.count), format: nil)
            as? [String: Any] else {
        throw PackError.badEnvelope
    }

    info.packageID = env["packageID"] as? String ?? "?"
    info.schemaVersion = env["schemaVersion"] as? Int ?? 0
    info.passwordProtected = env["isPasswordProtected"] as? Bool ?? false
    guard let ck = env["publicContentKey"] as? Data,
          let ep = env["encryptedPayload"] as? Data else {
        throw PackError.decrypt("thieu publicContentKey/encryptedPayload")
    }
    if let fp = env["keyFingerprint"] as? Data {
        info.fingerprintOK = (Data(SHA256.hash(data: ck)) == fp)
    }
    guard !info.passwordProtected else {
        throw PackError.decrypt("pack co bao ve mat khau")
    }

    // AES-256-GCM: encryptedPayload = nonce(12) + ciphertext + tag(16)
    // AAD = "3105PATCH/v{schema}/payload/{packageID}"
    do {
        let key = SymmetricKey(data: ck)
        let nonce = try AES.GCM.Nonce(data: ep.prefix(12))
        let box = try AES.GCM.SealedBox(
            nonce: nonce,
            ciphertext: ep.subdata(in: 12..<(ep.count - 16)),
            tag: ep.suffix(16))
        let aad = Data("3105PATCH/v\(info.schemaVersion)/payload/\(info.packageID)".utf8)
        let payload = try AES.GCM.open(box, using: key, authenticating: aad)
        guard let pl = try? PropertyListSerialization
                .propertyList(from: payload, format: nil) as? [String: Any] else {
            throw PackError.badPayload
        }
        if let proj = pl["project"] as? [String: Any] {
            info.projectName = proj["name"] as? String ?? "?"
            info.author = proj["author"] as? String ?? "?"
            info.bundleIDs = (proj["bundleIdentifiers"] as? [String]) ?? []
            if let rules = proj["rules"] as? [[String: Any]] {
                info.rules = rules.map {
                    ($0["relativePath"] as? String ?? "?",
                     ($0["replacementData"] as? Data)?.count ?? 0)
                }
                if let dig = pl["replacementDigests"] as? [String: Data] {
                    info.digestCount = dig.count
                }
                // internStrings table inside Assembly-CSharp-patch.bytes
                if let patchAny = rules.first(where: {
                        ($0["replacementFilename"] as? String ?? "")
                            == "Assembly-CSharp-patch.bytes" })?["replacementData"],
                   let patchData = patchAny as? Data,
                   let table = extractInternStrings([UInt8](patchData)) {
                    info.internStrings = table
                }
            }
        }
    } catch let e as PackError {
        throw e
    } catch {
        throw PackError.decrypt(error.localizedDescription)
    }
    return info
}

// 7-bit length-prefixed UTF-8 strings; table starts with count-prefixed "__cg".
private func extractInternStrings(_ b: [UInt8]) -> [String]? {
    let marker: [UInt8] = [0x04] + Array("__cg".utf8)
    guard let start = firstRange(of: marker, in: b)?.lowerBound else { return nil }
    var p = start              // marker bat dau tu chinh byte do dai (0x04)
    var out: [String] = []
    for _ in 0..<24 {
        guard p < b.count, let (s, next) = decodeNetString(b, p), !s.isEmpty else { break }
        out.append(s)
        if s.hasPrefix("/storage/") { break }   // past the interesting part
        p = next
    }
    return out.isEmpty ? nil : out
}

private func decodeNetString(_ b: [UInt8], _ p0: Int) -> (String, Int)? {
    var length = 0, shift = 0, p = p0
    while p < b.count {
        let byte = b[p]; p += 1
        length |= Int(byte & 0x7f) << shift
        if byte & 0x80 == 0 { break }
        shift += 7
    }
    guard p + length <= b.count, length > 0 else { return nil }
    guard let s = String(bytes: b[p..<(p + length)], encoding: .utf8) else { return nil }
    return (s, p + length)
}

private func firstRange(of needle: [UInt8], in hay: [UInt8]) -> Range<Int>? {
    guard !needle.isEmpty, hay.count >= needle.count else { return nil }
    for i in 0...(hay.count - needle.count) where Array(hay[i..<(i + needle.count)]) == needle {
        return i..<(i + needle.count)
    }
    return nil
}
