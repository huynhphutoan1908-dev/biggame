import SwiftUI

struct ContentView: View {
    @State private var urlText: String = "https://jsonplaceholder.typicode.com/todos/1"
    @State private var result: String = "Nhấn Fetch để gọi API"
    @State private var loading = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                TextField("URL API", text: $urlText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .padding()
                    .background(Color(.secondarySystemBackground),
                                in: RoundedRectangle(cornerRadius: 12))

                Button(action: fetch) {
                    HStack(spacing: 8) {
                        if loading { ProgressView().tint(.white) }
                        Text(loading ? "Đang gọi..." : "Fetch API")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue, in: RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(.white)
                }
                .disabled(loading)

                ScrollView {
                    Text(result)
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .padding()
                        .textSelection(.enabled)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.secondarySystemBackground),
                            in: RoundedRectangle(cornerRadius: 12))
            }
            .padding()
            .navigationTitle("hi")
        }
    }

    private func fetch() {
        guard let url = URL(string: urlText) else {
            result = "URL không hợp lệ"
            return
        }
        loading = true
        result = ""
        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                loading = false
                if let error {
                    result = "Lỗi: \(error.localizedDescription)"
                    return
                }
                var text = ""
                if let http = response as? HTTPURLResponse {
                    text += "HTTP \(http.statusCode)\n\n"
                }
                if let data {
                    if let obj = try? JSONSerialization.jsonObject(with: data),
                       let pretty = try? JSONSerialization.data(
                        withJSONObject: obj, options: .prettyPrinted) {
                        text += String(data: pretty, encoding: .utf8) ?? ""
                    } else {
                        text += String(data: data, encoding: .utf8) ?? "(rỗng)"
                    }
                }
                result = text.isEmpty ? "(không có dữ liệu)" : text
            }
        }.resume()
    }
}

#Preview {
    ContentView()
}
