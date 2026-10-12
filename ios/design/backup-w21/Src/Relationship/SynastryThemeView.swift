//  SynastryThemeView.swift
//  Khối "THEME CHÍNH CỦA MỐI QUAN HỆ" (`app/templates/synastry.html:114-119`),
//  render `theme_html` của `app/utils/reports/synastry.py:139-238`:
//    · 2 cột "Hành tinh trội của <A>" / "<B>" (synastry.py:206-209)
//    · hành tinh "kèm" (TÍNH THÊM) dán cạnh cột chủ nhân (synastry.py:174-204)
//    · "THEME PHỤ CỦA MỐI QUAN HỆ" — danh sách cặp mutual aspect (synastry.py:211-236)
//  Kèm nội dung diễn giải rút từ vault thầy oHa (`text/synastry.json`) qua
//  `VaultLoader` của `Src/Data` — KHÔNG tự chép JSON vào vùng này.

import SwiftUI

// MARK: - Tra nội dung "luận cặp hành tinh" trong vault

public enum SynastryVaultText {

    /// Tên hành tinh tiếng Anh -> ký hiệu dùng trong `text/synastry.json`
    /// (`luan_hanh_tinh_ca_nhan_x_ca_nhan[].cap`, `..._x_vong_ngoai[].cap`).
    static let vaultToken: [String: String] = [
        "Sun": "Sun", "Moon": "Moon", "Mercury": "Thủy", "Venus": "Kim", "Mars": "Hỏa",
        "Jupiter": "Mộc", "Saturn": "Thổ", "Uranus": "Uranus",
        "Neptune": "Neptune", "Pluto": "Pluto"
    ]

    /// Trả về đoạn luận cho cặp (p1, p2); thử cả 2 chiều. nil nếu vault không có cặp đó.
    public static func luan(_ p1: String, _ p2: String) -> String? {
        guard let file = try? VaultLoader.shared.synastry(),
              let t1 = vaultToken[p1], let t2 = vaultToken[p2] else { return nil }
        let all = file.capCaNhanXCaNhan + file.capCaNhanXVongNgoai
        let want = ["\(t1)-\(t2)", "\(t2)-\(t1)"]
        guard let hit = all.first(where: { want.contains($0.cap) }) else { return nil }
        let lines = hit.luan.allStrings
        return lines.isEmpty ? hit.luan.stringValue : lines.joined(separator: "\n")
    }
}

// MARK: - View

public struct SynastryThemeView: View {
    public let analysis: SynastryAnalysis
    public let nameA: String
    public let nameB: String

    public init(analysis: SynastryAnalysis, nameA: String, nameB: String) {
        self.analysis = analysis; self.nameA = nameA; self.nameB = nameB
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.lg) {
            mainTheme
            if let text = SynastryVaultText.luan(analysis.dominantA, analysis.dominantB) {
                AstroCard {
                    VStack(alignment: .leading, spacing: 4) {
                        SectionHeader("Luận cặp trội", style: .caps) { EmptyView() }
                        Text(text)
                            .font(Theme.Fonts.callout)
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                }
            }
            if !analysis.subThemes.isEmpty { subThemes }
        }
    }

    // synastry.py:206-209
    private var mainTheme: some View {
        HStack(alignment: .top, spacing: Theme.Space.md) {
            themeColumn(owner: "A", name: nameA, planet: analysis.dominantA,
                        tint: Theme.Colors.aspectSoft)
            themeColumn(owner: "B", name: nameB, planet: analysis.dominantB,
                        tint: Theme.Colors.aspectHard)
        }
    }

    private func themeColumn(owner: String, name: String, planet: String, tint: Color) -> some View {
        let acc = analysis.accompanying
        let hasAcc = (acc?.owner == owner)
        return VStack(spacing: Theme.Space.xs) {
            Text("Hành tinh trội của \(name)")
                .font(Theme.Fonts.caps)
                .foregroundStyle(Theme.Colors.textMuted)
                .multilineTextAlignment(.center)
                .lineLimit(2)
            AstroCard(level: .raised) {
                HStack(spacing: Theme.Space.sm) {
                    // synastry.py:175-204 — hành tinh "kèm" đứng bên TRÁI ở cột A,
                    // bên PHẢI ở cột B. Giữ đúng bố cục đó.
                    if hasAcc && owner == "A", let k = acc?.name { planetTile(k, tint: tint, extra: true) }
                    planetTile(planet, tint: tint, extra: false)
                    if hasAcc && owner == "B", let k = acc?.name { planetTile(k, tint: tint, extra: true) }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func planetTile(_ planet: String, tint: Color, extra: Bool) -> some View {
        VStack(spacing: 2) {
            AstroGlyph(planet: planet, size: extra ? 24 : 30, tint: extra ? tint.opacity(0.75) : tint)
            Text(planet)
                .font(extra ? Theme.Fonts.footnote : Theme.Fonts.headline)
                .foregroundStyle(Theme.Colors.textPrimary)
                .lineLimit(1).minimumScaleFactor(0.7)
            // synastry.py:181 — nhãn "(TÍNH THÊM)"
            Text(extra ? "(TÍNH THÊM)" : " ")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(extra ? Theme.Colors.textMuted : .clear)
        }
        .frame(maxWidth: .infinity)
    }

    // synastry.py:211-236
    private var subThemes: some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            SectionHeader("Theme phụ của mối quan hệ",
                          subtitle: "Cặp tạo góc đôi (double whammy), ít nhất 1 hành tinh cá nhân") { EmptyView() }
            VStack(spacing: 0) {
                ForEach(Array(analysis.subThemes.enumerated()), id: \.offset) { _, pair in
                    subThemeRow(pair)
                }
            }
            .background(Theme.Colors.bgSurface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                .stroke(Theme.Colors.border, lineWidth: 1))
        }
    }

    private func subThemeRow(_ pair: SubThemePair) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: Theme.Space.md) {
                AstroGlyph(planet: pair.first, size: 20, tint: Theme.Colors.accent)
                Text("—").foregroundStyle(Theme.Colors.textMuted)
                AstroGlyph(planet: pair.second, size: 20, tint: Theme.Colors.accent)
            }
            Text("\(pair.first) – \(pair.second)")
                .font(Theme.Fonts.caps)
                .foregroundStyle(Theme.Colors.textSecondary)
            if let luan = SynastryVaultText.luan(pair.first, pair.second) {
                Text(luan)
                    .font(Theme.Fonts.footnote)
                    .foregroundStyle(Theme.Colors.textMuted)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Space.sm)
        .padding(.horizontal, Theme.Space.md)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.Colors.separator).frame(height: 1)
        }
    }
}
