//  SynastryGuideView.swift
//  Nội dung DIỄN GIẢI của mảng Hợp đôi — lấy từ vault thầy oHa
//  (`Resources/Data/text/synastry.json`, worker khác nhồi vào bundle) qua
//  `VaultLoader` của `Src/Data`. File này KHÔNG chứa bản sao JSON nào.
//
//  Bao gồm: quy trình luận 3 phần · bảng ma trận ký hiệu 10×5 = 50 ô (CUỘN NGANG)
//  · 15 cặp hành tinh cá nhân × cá nhân · 25 cặp cá nhân × vòng ngoài
//  · 2 chìa khoá hạnh phúc · so sánh với Composite · đạo lý cuối buổi.

import SwiftUI

public struct SynastryGuideView: View {
    @State private var raw: JSONValue? = nil
    @State private var typed: VaultSynastryFile? = nil
    @State private var loadError: String? = nil

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.xl) {
            if let e = loadError {
                EmptyState(systemImage: "exclamationmark.triangle",
                           title: "Chưa nạp được nội dung",
                           message: e)
            } else if let raw, let typed {
                overview(raw, typed)
                processSection(raw)
                matrixSection(raw)
                keysSection(raw)
                pairsSection(typed)
                compareSection(raw)
                moralSection(raw)
            } else {
                LoadingBlock("Đang nạp nội dung…")
            }
        }
        .onAppear(perform: load)
    }

    private func load() {
        guard raw == nil else { return }
        do {
            raw = try VaultLoader.shared.raw(.synastry)
            typed = try VaultLoader.shared.synastry()
        } catch {
            loadError = String(describing: error)
        }
    }

    // MARK: - Tổng quan

    private func overview(_ v: JSONValue, _ t: VaultSynastryFile) -> some View {
        AstroCard(level: .raised) {
            VStack(alignment: .leading, spacing: Theme.Space.sm) {
                SectionHeader("Synastry là gì") { EmptyView() }
                Text(t.moTa).font(Theme.Fonts.callout).foregroundStyle(Theme.Colors.textSecondary)
                if let orb = t.orbSynastry {
                    labeledBlock("Orb dùng trong Synastry", [orb])
                }
                labeledBlock("Ba level tâm linh của mối quan hệ",
                             v["ba_level_tam_linh_cua_mqh"]?.arrayValue?.compactMap { $0.stringValue } ?? [])
                labeledBlock("Ưu việt của Synastry",
                             v["uu_viet_cua_synastry"]?.arrayValue?.compactMap { $0.stringValue } ?? [])
                labeledBlock("Công cụ", t.congCu)
            }
        }
    }

    // MARK: - Quy trình 3 phần

    private func processSection(_ v: JSONValue) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.md) {
            SectionHeader("Quy trình luận Synastry",
                          subtitle: "3 phần theo vault thầy oHa") { EmptyView() }
            ForEach(Array((v["quy_trinh"]?.arrayValue ?? []).enumerated()), id: \.offset) { _, part in
                AstroCard {
                    VStack(alignment: .leading, spacing: Theme.Space.sm) {
                        Text(part["phan"]?.stringValue ?? "—")
                            .font(Theme.Fonts.headline)
                            .foregroundStyle(Theme.Colors.accent)
                        // Thứ tự khoá cố định (dict Swift không giữ thứ tự file JSON).
                        ForEach(orderedKeys(of: part), id: \.self) { k in
                            if let child = part[k] { jsonBlock(title: label(k), value: child) }
                        }
                    }
                }
            }
        }
    }

    /// Thứ tự hiển thị các nhánh con của 1 phần quy trình — bám thứ tự file gốc.
    private func orderedKeys(of part: JSONValue) -> [String] {
        let preferred = ["noi_dung", "tong_quan", "tra_cuu_nhanh",
                         "quy_tac_hanh_tinh_roi_vao_nha", "hanh_tinh_roi_vao_nha_nguoi_kia",
                         "quy_tac", "buoc_1_tong_quan", "buoc_2a_theme_chinh",
                         "buoc_2b_theme_phu", "buoc_2c_hanh_tinh_trung_dinh_truc",
                         "buoc_2d_diem_tam_linh", "nguon"]
        let all = part.objectValue?.keys.sorted() ?? []
        let known = preferred.filter { all.contains($0) }
        let rest = all.filter { !preferred.contains($0) && $0 != "phan" }
        return known + rest
    }

    // MARK: - Bảng ma trận ký hiệu (50 ô) — CUỘN NGANG

    private func matrixSection(_ v: JSONValue) -> some View {
        let m = v["ma_tran_ky_hieu"]
        let cols = m?["cot"]?.arrayValue?.compactMap { $0.stringValue } ?? []
        let rows = m?["bang"]?.arrayValue ?? []
        return VStack(alignment: .leading, spacing: Theme.Space.sm) {
            SectionHeader("Bảng ma trận ký hiệu",
                          subtitle: m?["mo_ta"]?.stringValue) { EmptyView() }
            HStack(alignment: .top, spacing: 0) {
                // Cột trái GHIM
                VStack(spacing: 0) {
                    matrixCell("", width: 88, isHeader: true)
                    ForEach(Array(rows.enumerated()), id: \.offset) { _, r in
                        matrixCell(r["hang"]?.stringValue ?? "", width: 88, isHeader: true, alignLeft: true)
                    }
                }
                .overlay(alignment: .trailing) {
                    Rectangle().fill(Theme.Colors.borderStrong).frame(width: 1)
                }
                ScrollView(.horizontal, showsIndicators: true) {
                    VStack(spacing: 0) {
                        HStack(spacing: 0) {
                            ForEach(cols, id: \.self) { c in matrixCell(c, width: 84, isHeader: true) }
                        }
                        ForEach(Array(rows.enumerated()), id: \.offset) { _, r in
                            HStack(spacing: 0) {
                                ForEach(cols, id: \.self) { c in
                                    matrixCell(r[c]?.stringValue ?? "", width: 84, isHeader: false)
                                }
                            }
                        }
                    }
                }
            }
            .background(Theme.Colors.bgSunken)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                .stroke(Theme.Colors.border, lineWidth: 1))

            Text("Bảng tam giác dưới — nửa trên để trống đúng như bản gốc. Vuốt ngang để xem hết 5 cột.")
                .font(Theme.Fonts.caption)
                .foregroundStyle(Theme.Colors.textMuted)

            legendBlock(m)
            labeledBlock("Ghi chú bản gốc",
                         m?["ghi_chu_ban_goc"]?.arrayValue?.compactMap { $0.stringValue } ?? [])
        }
    }

    private func matrixCell(_ text: String, width: CGFloat,
                            isHeader: Bool, alignLeft: Bool = false) -> some View {
        Text(text.isEmpty ? " " : text)
            .font(isHeader ? Theme.Fonts.caps : Theme.Fonts.callout)
            .foregroundStyle(isHeader ? Theme.Colors.accent : Theme.Colors.textPrimary)
            .multilineTextAlignment(alignLeft ? .leading : .center)
            .lineLimit(2).minimumScaleFactor(0.7)
            .frame(width: width, height: 40, alignment: alignLeft ? .leading : .center)
            .padding(.horizontal, 4)
            .background(isHeader ? Theme.Colors.bgChip : Theme.Colors.bgSurface)
            .overlay(Rectangle().stroke(Theme.Colors.separator, lineWidth: 0.5))
    }

    private func legendBlock(_ m: JSONValue?) -> some View {
        let items = m?["chu_thich_ky_hieu"]?.arrayValue ?? []
        return AstroCard {
            VStack(alignment: .leading, spacing: 4) {
                SectionHeader("Chú thích ký hiệu", style: .caps) { EmptyView() }
                ForEach(Array(items.enumerated()), id: \.offset) { _, it in
                    HStack(alignment: .top, spacing: Theme.Space.sm) {
                        Text(it["ky_hieu"]?.stringValue ?? "")
                            .font(Theme.Fonts.numeric)
                            .foregroundStyle(Theme.Colors.accent)
                            .frame(width: 34, alignment: .leading)
                        Text(it["nghia"]?.stringValue ?? "")
                            .font(Theme.Fonts.footnote)
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                }
            }
        }
    }

    // MARK: - 2 chìa khoá hạnh phúc

    private func keysSection(_ v: JSONValue) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            SectionHeader("Chìa khoá hạnh phúc") { EmptyView() }
            ForEach(Array((v["chia_khoa_hanh_phuc"]?.arrayValue ?? []).enumerated()), id: \.offset) { _, k in
                AstroCard {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(k["ten"]?.stringValue ?? "—")
                            .font(Theme.Fonts.headline)
                            .foregroundStyle(Theme.Colors.accent)
                        ForEach(Array((k["noi_dung"]?.arrayValue ?? []).enumerated()), id: \.offset) { _, l in
                            bullet(l.stringValue ?? "")
                        }
                    }
                }
            }
        }
    }

    // MARK: - 15 + 25 cặp hành tinh

    private func pairsSection(_ t: VaultSynastryFile) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.md) {
            pairList("Cặp cá nhân × cá nhân (\(t.capCaNhanXCaNhan.count) cặp)", t.capCaNhanXCaNhan)
            pairList("Cặp cá nhân × vòng ngoài (\(t.capCaNhanXVongNgoai.count) cặp)", t.capCaNhanXVongNgoai)
        }
    }

    private func pairList(_ title: String, _ items: [VaultSynastryPair]) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            SectionHeader(title) { EmptyView() }
            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, p in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(p.cap).font(Theme.Fonts.caps).foregroundStyle(Theme.Colors.accent)
                        Text(p.luan.allStrings.joined(separator: "\n"))
                            .font(Theme.Fonts.footnote)
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 6).padding(.horizontal, Theme.Space.md)
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(Theme.Colors.separator).frame(height: 0.5)
                    }
                }
            }
            .background(Theme.Colors.bgSurface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                .stroke(Theme.Colors.border, lineWidth: 1))
        }
    }

    // MARK: - So sánh với Composite + đạo lý

    private func compareSection(_ v: JSONValue) -> some View {
        let s = v["so_sanh_voi_composite"]
        return AstroCard {
            VStack(alignment: .leading, spacing: Theme.Space.sm) {
                SectionHeader("Synastry so với Composite") { EmptyView() }
                if let m = s?["mo_ta"]?.stringValue {
                    Text(m).font(Theme.Fonts.callout).foregroundStyle(Theme.Colors.textSecondary)
                }
                labeledBlock("Lý do thầy không khuyến khích Composite",
                             s?["ly_do_khong_khuyen_khich"]?.arrayValue?.compactMap { $0.stringValue } ?? [])
                if let t = s?["composite_thiet_lap"]?.stringValue {
                    labeledBlock("Composite thiết lập thế nào", [t])
                }
            }
        }
    }

    private func moralSection(_ v: JSONValue) -> some View {
        AstroCard {
            VStack(alignment: .leading, spacing: Theme.Space.sm) {
                SectionHeader("Đạo lý cuối buổi") { EmptyView() }
                ForEach(Array((v["dao_ly_cuoi_buoi"]?.arrayValue ?? []).enumerated()), id: \.offset) { _, l in
                    bullet(l.stringValue ?? "")
                }
            }
        }
    }

    // MARK: - Tiện ích trình bày

    @ViewBuilder private func labeledBlock(_ title: String, _ lines: [String]) -> some View {
        if !lines.isEmpty {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(Theme.Fonts.caps).foregroundStyle(Theme.Colors.textMuted)
                ForEach(Array(lines.enumerated()), id: \.offset) { _, l in bullet(l) }
            }
        }
    }

    private func bullet(_ s: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text("•").foregroundStyle(Theme.Colors.accentDim)
            Text(s).font(Theme.Fonts.footnote).foregroundStyle(Theme.Colors.textSecondary)
        }
    }

    /// Nhãn tiếng Việt cho khoá JSON.
    private func label(_ k: String) -> String {
        switch k {
        case "noi_dung": return "Nội dung"
        case "tong_quan": return "Tổng quan"
        case "tra_cuu_nhanh": return "Tra cứu nhanh"
        case "quy_tac": return "Quy tắc"
        case "quy_tac_hanh_tinh_roi_vao_nha": return "Quy tắc hành tinh rơi vào nhà"
        case "hanh_tinh_roi_vao_nha_nguoi_kia": return "Hành tinh rơi vào nhà người kia"
        case "buoc_1_tong_quan": return "Bước 1 — Tổng quan"
        case "buoc_2a_theme_chinh": return "Bước 2a — Theme chính"
        case "buoc_2b_theme_phu": return "Bước 2b — Theme phụ"
        case "buoc_2c_hanh_tinh_trung_dinh_truc": return "Bước 2c — Hành tinh trùng đỉnh trục"
        case "buoc_2d_diem_tam_linh": return "Bước 2d — Điểm tâm linh"
        case "nguon": return "Nguồn"
        default: return k.replacingOccurrences(of: "_", with: " ")
        }
    }

    /// Render đệ quy 1 nhánh JSON bất kỳ (chuỗi / mảng / dict lồng nhau).
    @ViewBuilder private func jsonBlock(title: String, value: JSONValue) -> some View {
        switch value {
        case .string(let s):
            labeledBlock(title, [s])
        case .array(let a):
            if a.allSatisfy({ $0.stringValue != nil }) {
                labeledBlock(title, a.compactMap { $0.stringValue })
            } else {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(Theme.Fonts.caps).foregroundStyle(Theme.Colors.textMuted)
                    ForEach(Array(a.enumerated()), id: \.offset) { _, item in
                        bullet(item.allStrings.joined(separator: " · "))
                    }
                }
            }
        case .object(let o):
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(Theme.Fonts.caps).foregroundStyle(Theme.Colors.accentDim)
                ForEach(o.keys.sorted(), id: \.self) { k in
                    if let child = o[k] {
                        labeledBlock(label(k), child.allStrings)
                    }
                }
            }
        default:
            if let s = value.stringValue { labeledBlock(title, [s]) }
        }
    }
}
