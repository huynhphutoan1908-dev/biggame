import Foundation
import Crypto

// Mot rule dang soan trong tab "Tao goi".
struct RuleDraft: Identifiable {
    let id = UUID().uuidString
    var sourceName: String     // ten file goc da chon
    var data: Data
    var path: String           // vi du "Documents/Assembly-CSharp-patch.bytes"

    var replacementFilename: String {
        (path as NSString).lastPathComponent
    }
    var directory: String {
        (path as NSString).deletingLastPathComponent  // "Documents"
    }
}

enum PackBuildError: LocalizedError {
    case noRules, badPath(String)
    var errorDescription: String? {
        switch self {
        case .noRules: return "Chua co file nao - them it nhat 1 file"
        case .badPath(let p): return "Duong dan rule khong hop le: \(p)"
        }
    }
}

// Dong goi container .3105 (ma hoa AES-256-GCM + envelope binary plist),
// thuat toan giong het update_pack_id.py: AAD = "3105PATCH/v{schema}/payload/{uuid}".
func buildPack(name: String,
               author: String,
               bundleID: String,
               rules: [RuleDraft],
               schemaVersion: Int = 9) throws -> Data {

    guard !rules.isEmpty else { throw PackBuildError.noRules }
    for r in rules where r.path.isEmpty || !r.path.contains("/") {
        throw PackBuildError.badPath(r.path)
    }

    let packageID = UUID().uuidString
    let projectID = UUID().uuidString
    let now = Date()

    // directories: suy ra tu parent cua tung rule, khoi trung lap
    var dirs: [[String: Any]] = []
    var seen = Set<String>()
    for r in rules {
        let d = r.directory
        if d.isEmpty || seen.contains(d) { continue }
        seen.insert(d)
        dirs.append(["id": UUID().uuidString,
                     "bundleID": bundleID,
                     "relativePath": d])
    }

    let ruleDicts: [[String: Any]] = rules.map { r in
        ["id": r.id,
         "bundleID": bundleID,
         "relativePath": r.path,
         "replacementFilename": r.replacementFilename,
         "replacementData": r.data]
    }

    var digests: [String: Data] = [:]
    for r in rules { digests[r.id] = Data(SHA256.hash(data: r.data)) }

    let project: [String: Any] = [
        "id": projectID,
        "name": name,
        "author": author,
        "isPrivate": false,
        "createdAt": now,
        "updatedAt": now,
        "bundleIdentifiers": [bundleID],
        "directories": dirs,
        "rules": ruleDicts,
    ]
    let payloadDict: [String: Any] = [
        "project": project,
        "replacementDigests": digests,
    ]
    let payload = try PropertyListSerialization.data(
        fromPropertyList: payloadDict, format: .binary, options: 0)

    let contentKey = SymmetricKey(data: Data((0..<32).map { _ in UInt8.random(in: .min ... .max) }))
    let aad = Data("3105PATCH/v\(schemaVersion)/payload/\(packageID)".utf8)
    let sealed = try AES.GCM.seal(payload, using: contentKey, authenticating: aad)
    guard let combined = sealed.combined else {
        throw PackBuildError.badPath("seal khong tra ve combined nonce+ct+tag")
    }

    let keyBytes = contentKey.withUnsafeBytes { Data($0) }
    let envelope: [String: Any] = [
        "schemaVersion": schemaVersion,
        "packageID": packageID,
        "isPasswordProtected": false,
        "publicContentKey": keyBytes,
        "keyFingerprint": Data(SHA256.hash(data: keyBytes)),
        "encryptedPayload": combined,
    ]
    let envData = try PropertyListSerialization.data(
        fromPropertyList: envelope, format: .binary, options: 0)

    let pkg = Data("3105PATCH\0".utf8) + envData

    // Round-trip test nhu script Python: tu giai ma lai dung 1 lan truoc khi xuat
    let keyBack = SymmetricKey(data: keyBytes)
    let box = try AES.GCM.SealedBox(combined: combined)
    _ = try AES.GCM.open(box, using: keyBack, authenticating: aad)

    return pkg
}
