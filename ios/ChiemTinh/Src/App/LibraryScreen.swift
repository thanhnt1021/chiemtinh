//  LibraryScreen.swift
//  TAB "TRA CỨU" — đọc thẳng 14 file JSON nội dung + 8 bảng Markdown trong bundle
//  (`Resources/Data/`), qua `Src/Data/VaultLoader.swift`. KHÔNG gọi mạng.
//
//  W21 dựng màn này vì 4 worker trước không ai làm: `RootTabView` còn `PlaceholderScreen`
//  ở tab Tra cứu. Cách hiển thị: danh sách mục -> mở ra cây JSON đệ quy giữ NGUYÊN VĂN
//  (dùng `JSONValue` nên không mất mảnh dữ liệu nào — `Src/Data/JSONValue.swift:11`).

import SwiftUI

public struct LibraryScreen: View {

    private enum Item: Hashable {
        case json(VaultFileName)
        case table(VaultTableName)
    }

    @State private var query: String = ""
    @State private var loadError: String?

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                ScreenBackground()
                List {
                    Section("Nội dung diễn giải (\(VaultFileName.allCases.count) mục)") {
                        ForEach(filteredJSON, id: \.self) { f in
                            NavigationLink {
                                VaultJSONDetail(file: f)
                            } label: {
                                row(title: f.nhan, subtitle: f.rawValue + ".json",
                                    icon: "text.book.closed")
                            }
                        }
                    }
                    Section("Bảng trích từ buổi học (\(VaultTableName.allCases.count) bảng)") {
                        ForEach(filteredTables, id: \.self) { t in
                            NavigationLink {
                                VaultMarkdownDetail(table: t)
                            } label: {
                                row(title: prettyTable(t), subtitle: t.rawValue + ".md",
                                    icon: "tablecells")
                            }
                        }
                    }
                    Section {
                        Text("Toàn bộ nội dung nằm trong bundle app, đọc được khi không có mạng.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .searchable(text: $query, prompt: "Tìm trong nội dung")
            .navigationTitle("Tra cứu")
            .navigationBarTitleDisplayMode(.inline)   // W21: .large không vẽ chữ trên iOS 26
        }
    }

    private func row(title: String, subtitle: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 17))
                .foregroundStyle(Theme.Colors.accent)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline).fontWeight(.medium)
                Text(subtitle).font(.caption2).foregroundStyle(.secondary)
            }
        }
        .frame(minHeight: 44)
    }

    private var filteredJSON: [VaultFileName] {
        let q = LocationDirectory.normalize(query)
        guard !q.isEmpty else { return VaultFileName.allCases }
        return VaultFileName.allCases.filter {
            LocationDirectory.normalize($0.nhan).contains(q)
            || LocationDirectory.normalize($0.rawValue).contains(q)
        }
    }

    private var filteredTables: [VaultTableName] {
        let q = LocationDirectory.normalize(query)
        guard !q.isEmpty else { return VaultTableName.allCases }
        return VaultTableName.allCases.filter { LocationDirectory.normalize($0.rawValue).contains(q) }
    }

    private func prettyTable(_ t: VaultTableName) -> String {
        t.rawValue
            .replacingOccurrences(of: "bang-", with: "")
            .replacingOccurrences(of: "-", with: " ")
            .capitalizedFirst
    }
}

// MARK: - Xem một file JSON ---------------------------------------------------

struct VaultJSONDetail: View {
    let file: VaultFileName

    @State private var value: JSONValue?
    @State private var error: String?

    var body: some View {
        ZStack {
            ScreenBackground()
            Group {
                if let e = error {
                    ContentUnavailableView("Không đọc được", systemImage: "exclamationmark.triangle",
                                           description: Text(e))
                } else if let v = value {
                    List {
                        JSONNodeView(label: file.nhan, value: v, depth: 0)
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                } else {
                    ProgressView("Đang nạp \(file.rawValue).json…")
                }
            }
        }
        .navigationTitle(file.nhan)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard value == nil, error == nil else { return }
            do { value = try VaultLoader.shared.raw(file) }
            catch { self.error = String(describing: error) }
        }
    }
}

/// Vẽ cây `JSONValue` đệ quy. Lá là chuỗi/số/bool; nhánh là `DisclosureGroup`.
struct JSONNodeView: View {
    let label: String
    let value: JSONValue
    let depth: Int

    var body: some View {
        switch value {
        case .object(let o):
            DisclosureGroup(isExpanded: .constant(depth == 0) ) {
                ForEach(o.keys.sorted(), id: \.self) { k in
                    JSONNodeView(label: prettyKey(k), value: o[k] ?? .null, depth: depth + 1)
                }
            } label: {
                branchLabel("\(o.count) mục")
            }
        case .array(let a):
            DisclosureGroup {
                ForEach(Array(a.enumerated()), id: \.offset) { i, v in
                    JSONNodeView(label: itemTitle(v) ?? "#\(i + 1)", value: v, depth: depth + 1)
                }
            } label: {
                branchLabel("\(a.count) phần tử")
            }
        default:
            leaf
        }
    }

    private func branchLabel(_ count: String) -> some View {
        HStack {
            Text(label).font(.subheadline).fontWeight(.medium)
            Spacer(minLength: 8)
            Text(count).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(minHeight: 44)
    }

    @ViewBuilder private var leaf: some View {
        let text = value.stringValue ?? "—"
        if text.count > 60 {
            VStack(alignment: .leading, spacing: 4) {
                Text(label).font(.caption).foregroundStyle(Theme.Colors.accent)
                Text(text).font(.callout).fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 2)
        } else {
            HStack(alignment: .firstTextBaseline) {
                Text(label).font(.caption).foregroundStyle(.secondary)
                Spacer(minLength: 12)
                Text(text).font(.callout).multilineTextAlignment(.trailing)
            }
        }
    }

    /// Đặt tên cho phần tử mảng bằng khoá "tên" thường gặp trong vault.
    private func itemTitle(_ v: JSONValue) -> String? {
        for k in ["ten", "ten_cung", "ten_nha", "ten_hanh_tinh", "ten_goc", "name", "tieu_de", "cap"] {
            if let s = v[k]?.stringValue { return s }
        }
        return nil
    }

    private func prettyKey(_ k: String) -> String {
        k.replacingOccurrences(of: "_", with: " ").capitalizedFirst
    }
}

// MARK: - Xem một bảng Markdown ----------------------------------------------

struct VaultMarkdownDetail: View {
    let table: VaultTableName

    @State private var text: String?
    @State private var error: String?

    var body: some View {
        ZStack {
            ScreenBackground()
            Group {
                if let e = error {
                    ContentUnavailableView("Không đọc được", systemImage: "exclamationmark.triangle",
                                           description: Text(e))
                } else if let t = text {
                    ScrollView([.vertical, .horizontal]) {
                        Text(t)
                            .font(.system(.footnote, design: .monospaced))
                            .textSelection(.enabled)
                            .padding(16)
                    }
                } else {
                    ProgressView("Đang nạp…")
                }
            }
        }
        .navigationTitle(table.rawValue)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard text == nil, error == nil else { return }
            do { text = try VaultLoader.shared.markdown(table) }
            catch { self.error = String(describing: error) }
        }
    }
}

#Preview { LibraryScreen() }
