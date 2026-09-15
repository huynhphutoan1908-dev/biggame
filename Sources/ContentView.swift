import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var showingPicker = false
    @State private var packInfo: PackInfo?
    @State private var errorMessage: String?
    @State private var fileName = ""
    @State private var busy = false

    var body: some View {
        NavigationStack {
            Group {
                if busy {
                    ProgressView("Dang giai ma...")
                } else if let info = packInfo {
                    PackInfoView(info: info, fileName: fileName) {
                        packInfo = nil
                        fileName = ""
                        errorMessage = nil
                        showingPicker = true
                    }
                } else {
                    emptyState
                }
            }
            .navigationTitle("hi · Pack Inspector")
            .fileImporter(isPresented: $showingPicker,
                          allowedContentTypes: [.data, .item],
                          allowsMultipleSelection: false) { handleImport($0) }
            .padding(.horizontal)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.zipper")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
            Text("Chon file .3105 de xem ben trong")
                .font(.title3)
            Button {
                showingPicker = true
            } label: {
                Label("Chon file .3105", systemImage: "folder")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue, in: RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(.white)
            }
            if let err = errorMessage {
                Text(err)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        errorMessage = nil
        switch result {
        case .failure(let e):
            errorMessage = e.localizedDescription
        case .success(let urls):
            guard let url = urls.first else { return }
            busy = true
            fileName = url.lastPathComponent
            DispatchQueue.global().async {
                var info: PackInfo?
                var err: String?
                do {
                    guard url.startAccessingSecurityScopedResource() else {
                        throw PackError.decrypt("khong co quyen doc file")
                    }
                    defer { url.stopAccessingSecurityScopedResource() }
                    let data = try Data(contentsOf: url)
                    info = try inspectPack(data)
                } catch {
                    err = error.localizedDescription
                }
                DispatchQueue.main.async {
                    busy = false
                    packInfo = info
                    errorMessage = err
                }
            }
        }
    }
}

struct PackInfoView: View {
    let info: PackInfo
    let fileName: String
    let onReset: () -> Void

    var body: some View {
        List {
            Section("File") {
                row("Tên file", fileName)
                row("Magic header", info.magicOK ? "3105PATCH ✓" : "SAI ✗")
                row("Key fingerprint", info.fingerprintOK ? "SHA-256 khớp ✓" : "khong khop ✗")
            }
            Section("Container") {
                row("packageID", info.packageID)
                row("schemaVersion", "\(info.schemaVersion)")
                row("Mat khau", info.passwordProtected ? "CO" : "khong")
                row("Bundle", info.bundleIDs.joined(separator: ", "))
            }
            Section("Project") {
                row("name", info.projectName)
                row("author", info.author)
            }
            Section("Rules (\(info.rules.count), digests: \(info.digestCount))") {
                ForEach(info.rules, id: \.path) { r in
                    row(r.path, bytes(r.size))
                }
            }
            if !info.internStrings.isEmpty {
                Section("internStrings") {
                    ForEach(Array(info.internStrings.enumerated()), id: \.offset) { i, s in
                        row("[\(i)]", s)
                    }
                }
            }
            Section {
                Button("Chon file khac", action: onReset)
            }
        }
    }

    private func bytes(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.2f MB", Double(n) / 1e6) }
        if n >= 1000 { return String(format: "%.1f KB", Double(n) / 1e3) }
        return "\(n) B"
    }

    private func row(_ k: String, _ v: String) -> some View {
        HStack(alignment: .top) {
            Text(k).foregroundStyle(.secondary)
            Spacer()
            Text(v).multilineTextAlignment(.trailing).textSelection(.enabled)
        }
        .font(.system(.footnote, design: .monospaced))
    }
}

#Preview {
    ContentView()
}
