import SwiftUI
import UniformTypeIdentifiers

struct CreatePackView: View {
    @State private var name = "My Patch"
    @State private var author = "@toanbakhi"
    @State private var bundleID = "com.dts.freefireth"
    @State private var rules: [RuleDraft] = []
    @State private var showingPicker = false
    @State private var status: String?
    @State private var exportedURL: URL?
    @State private var exportedData: Data?

    var body: some View {
        NavigationStack {
            Form {
                Section("Thong tin") {
                    TextField("Ten goi", text: $name)
                    TextField("Nguoi tao", text: $author)
                    Picker("Ung dung dich", selection: $bundleID) {
                        Text("Free Fire (com.dts.freefireth)").tag("com.dts.freefireth")
                        Text("Free Fire MAX (com.dts.freefiremax)").tag("com.dts.freefiremax")
                    }
                }

                Section("Tep & quy tac") {
                    ForEach($rules) { $r in
                        VStack(alignment: .leading, spacing: 4) {
                            TextField("Duong dan rule (vi du Documents/localConfig.json)",
                                      text: $r.path)
                                .font(.system(.footnote, design: .monospaced))
                            Text("\(r.sourceName) · \(r.data.count) bytes")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    Button {
                        showingPicker = true
                    } label: {
                        Label("Them tep...", systemImage: "plus")
                    }
                    if !rules.isEmpty {
                        Button("Xoa het", role: .destructive) { rules.removeAll() }
                    }
                }

                Section("Xuat file") {
                    outputRows
                }
            }
            .navigationTitle("hi · Tao goi")
            .fileImporter(isPresented: $showingPicker,
                          allowedContentTypes: [.data, .item],
                          allowsMultipleSelection: true) { handleFiles($0) }
        }
    }

    @ViewBuilder private var outputRows: some View {
        Button {
            build()
        } label: {
            Text("Tao goi .3105")
                .frame(maxWidth: .infinity)
                .fontWeight(.semibold)
        }
        .disabled(rules.isEmpty)

        if let url = exportedURL {
            ShareLink(item: url,
                      preview: ShareLink("Goi .3105", url)) {
                Label("Chia se / luu \(url.lastPathComponent)",
                      systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
        }
        if let s = status {
            Text(s).font(.footnote)
                .foregroundStyle(s.hasPrefix("Lỗi") ? .red : .green)
        }
    }

    private func handleFiles(_ result: Result<[URL], Error>) {
        status = nil
        guard case .success(let urls) = result else { return }
        for url in urls {
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            guard let data = try? Data(contentsOf: url) else { continue }
            var path = "Documents/" + url.lastPathComponent
            if url.lastPathComponent == "Assembly-CSharp-patch.bytes" {
                path = "Documents/Assembly-CSharp-patch.bytes"
            }
            rules.append(RuleDraft(sourceName: url.lastPathComponent,
                                   data: data, path: path))
        }
        status = rules.isEmpty ? "Khong doc duoc tep nao" : "\(rules.count) quy tac"
    }

    private func build() {
        status = nil
        do {
            let pkg = try buildPack(name: name, author: author,
                                    bundleID: bundleID, rules: rules)
            let docs = FileManager.default
                .urls(for: .documentDirectory, in: .userDomainMask)[0]
            let safe = name.isEmpty ? "pack" : name
                .replacingOccurrences(of: "/", with: "-")
            let url = docs.appendingPathComponent("\(safe).3105")
            try pkg.write(to: url)
            exportedData = pkg
            exportedURL = url
            status = "OK — \(pkg.count) bytes, da round-trip test"
        } catch {
            status = "Lỗi: \(error.localizedDescription)"
        }
    }
}

#Preview {
    CreatePackView()
}
