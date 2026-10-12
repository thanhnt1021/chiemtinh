//  SynastryGridView.swift
//  Khối "BẢNG TƯƠNG TÁC GÓC" (`app/templates/synastry.html:108-113`).
//  Web xuất ảnh PNG matplotlib (`app/utils/drawing/grid.py:141-224`); ở đây dựng
//  bảng NATIVE cuộn ngang được, cột trái GHIM cố định để không vỡ trên điện thoại.
//
//  Ô góc hợp lấy từ `SynastryAspectGridModel` của W18 (`Src/Chart/AspectGridModel.swift`)
//  — KHÔNG tính lại. File này chỉ dựng phần HEADER (cung, độ, số góc, nhấn mạnh
//  hành tinh trội / hành tinh kèm) mà mô hình của W18 chưa có.

import SwiftUI

// MARK: - Mô hình header (grid.py:177-224)

public struct SynastryGridHeader: Identifiable, Equatable {
    public let name: String
    public let shortName: String        // grid.py:220 `pA[:3]`
    public let signIndex: Int
    public let degWhole: Int            // grid.py:222 `int(z_deg)`
    public let degMinutes: Int          // grid.py:222 `int((z_deg % 1) * 60)`
    public let count: Int?              // grid.py:185 / 226 — số góc tạo với người kia
    public let isWinner: Bool           // grid.py:187 — hành tinh trội
    public let isAccompanying: Bool     // grid.py:188 — hành tinh "kèm"
    public let isExtended: Bool         // grid.py:182 — sau cột Asc thì nền khác
    public var id: String { name }

    static func make(_ p: String, chart: Chart, objs: [String],
                     scores: [String: SynastryScore], dominant: String?,
                     acc: AccompanyingPlanet?, owner: String) -> SynastryGridHeader {
        let z = AstroCore.getZodiac(chart.planets[p]?.lon ?? 0)
        let s = scores[p]
        // grid.py:197 / 234 — ⚠️ GIỮ NGUYÊN: riêng Asc bỏ mọi nhấn mạnh.
        let isAsc = (p == "Asc")
        return SynastryGridHeader(
            name: p,
            shortName: String(p.prefix(3)),
            signIndex: z.idx,
            degWhole: Int(z.degInSign),
            degMinutes: Int(pmod(z.degInSign, 1) * 60),
            count: s?.count,
            isWinner: !isAsc && s != nil && p == dominant,
            isAccompanying: !isAsc && s != nil && acc?.owner == owner && acc?.name == p,
            isExtended: (objs.firstIndex(of: p) ?? 0) > SynastryAspectGridModel.ascIndex)
    }

    public static func rowsAndCols(cA: Chart, cB: Chart, model: SynastryAspectGridModel,
                                   analysis: SynastryAnalysis?)
        -> (rows: [SynastryGridHeader], cols: [SynastryGridHeader]) {
        let objs = SynastryAspectGridModel.synastryObjs
        let rows = model.rowsObjects.map {
            make($0, chart: cA, objs: objs, scores: analysis?.scoresA ?? [:],
                 dominant: analysis?.dominantA, acc: analysis?.accompanying, owner: "A")
        }
        let cols = model.colsObjects.map {
            make($0, chart: cB, objs: objs, scores: analysis?.scoresB ?? [:],
                 dominant: analysis?.dominantB, acc: analysis?.accompanying, owner: "B")
        }
        return (rows, cols)
    }
}

// MARK: - Màu ô

enum RelAspectColor {
    /// Web: Trùng = đen (`styles.py:3`), Đối đỉnh/Cứng = đỏ (`styles.py:2,4`),
    /// Mềm = xanh (`styles.py:5`), Phụ = xanh lá (`styles.py:6`).
    /// Bản app dùng token dark-first của W17 — ĐEN đổi thành `textPrimary`
    /// để còn nhìn thấy trên nền xanh đêm; các màu còn lại giữ đúng vai trò.
    static func color(_ cell: GridAspectCell) -> Color {
        switch cell.visual {
        case .conjunction: return Theme.Colors.textPrimary
        case .opposition, .hard: return Theme.Colors.aspectHard
        case .minor: return Theme.Colors.aspectMinor
        case .soft: return Theme.Colors.aspectSoft
        }
    }
}

// MARK: - View

public struct SynastryGridView: View {
    public let chartA: Chart
    public let chartB: Chart
    public let nameA: String
    public let nameB: String
    public let analysis: SynastryAnalysis?
    public let showRealOrb: Bool

    public init(chartA: Chart, chartB: Chart, nameA: String, nameB: String,
                analysis: SynastryAnalysis?, showRealOrb: Bool) {
        self.chartA = chartA; self.chartB = chartB
        self.nameA = nameA; self.nameB = nameB
        self.analysis = analysis; self.showRealOrb = showRealOrb
    }

    private let cell: CGFloat = 46
    private let headWidth: CGFloat = 92
    private let topHeight: CGFloat = 58

    public var body: some View {
        let model = SynastryAspectGridModel(chartA: chartA, chartB: chartB)
        let hdr = SynastryGridHeader.rowsAndCols(cA: chartA, cB: chartB, model: model, analysis: analysis)

        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            legend
            HStack(alignment: .top, spacing: 0) {
                pinnedColumn(hdr.rows)
                ScrollView(.horizontal, showsIndicators: true) {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(spacing: 0) { ForEach(hdr.cols) { colHeader($0) } }
                        ForEach(Array(hdr.rows.enumerated()), id: \.element.id) { r, _ in
                            HStack(spacing: 0) {
                                ForEach(Array(model.cells[r].enumerated()), id: \.offset) { c, slot in
                                    slotView(slot)
                                        .frame(width: cell, height: cell)
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
            Text("Hàng = \(nameA) (trong) · Cột = \(nameB) (ngoài). Vuốt ngang để xem hết bảng.")
                .font(Theme.Fonts.caption)
                .foregroundStyle(Theme.Colors.textMuted)
        }
    }

    // Cột trái GHIM — gồm ô góc rỗng cao bằng header trên.
    private func pinnedColumn(_ rows: [SynastryGridHeader]) -> some View {
        VStack(spacing: 0) {
            Text("A \\ B")
                .font(Theme.Fonts.caps)
                .foregroundStyle(Theme.Colors.textMuted)
                .frame(width: headWidth, height: topHeight)
                .background(Theme.Colors.bgChip)
            ForEach(rows) { h in rowHeader(h) }
        }
        .overlay(alignment: .trailing) {
            Rectangle().fill(Theme.Colors.borderStrong).frame(width: 1)
        }
    }

    private func rowHeader(_ h: SynastryGridHeader) -> some View {
        HStack(spacing: 4) {
            AstroGlyph(planet: h.name, size: 16, tint: emphasisTint(h, base: Theme.Colors.aspectSoft))
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 0) {
                Text(h.shortName)
                    .font(Theme.Fonts.caps)
                    .foregroundStyle(Theme.Colors.textPrimary)
                HStack(spacing: 2) {
                    AstroGlyph(signIndex: h.signIndex, size: 10, tint: Theme.Colors.textMuted)
                    Text("\(h.degWhole)°\(h.degMinutes)'")
                        .font(Theme.Fonts.numericSmall)
                        .foregroundStyle(Theme.Colors.textMuted)
                }
            }
            Spacer(minLength: 0)
            countBadge(h, base: Theme.Colors.aspectSoft)
        }
        .padding(.horizontal, 6)
        .frame(width: headWidth, height: cell)
        .background(h.isExtended ? Theme.Colors.bgChip : Theme.Colors.bgSurface)
    }

    private func colHeader(_ h: SynastryGridHeader) -> some View {
        VStack(spacing: 1) {
            AstroGlyph(signIndex: h.signIndex, size: 11, tint: Theme.Colors.textMuted)
            Text("\(h.degWhole)°\(h.degMinutes)'")
                .font(.system(size: 8))
                .foregroundStyle(Theme.Colors.textMuted)
            countBadge(h, base: Theme.Colors.aspectHard)
            AstroGlyph(planet: h.name, size: 15, tint: emphasisTint(h, base: Theme.Colors.aspectHard))
        }
        .frame(width: cell, height: topHeight)
        .background(h.isExtended ? Theme.Colors.bgChip : Theme.Colors.bgSurface)
    }

    @ViewBuilder private func countBadge(_ h: SynastryGridHeader, base: Color) -> some View {
        if let c = h.count {
            Text("\(c)")
                .font(h.isWinner ? Theme.Fonts.numeric : Theme.Fonts.numericSmall)
                .fontWeight(h.isWinner || h.isAccompanying ? .bold : .regular)
                .foregroundStyle(emphasisTint(h, base: base))
                .padding(.horizontal, 4)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(h.isWinner ? Theme.Colors.accent
                                : (h.isAccompanying ? Theme.Colors.accentDim : .clear),
                                lineWidth: h.isWinner ? 2 : 1))
        } else {
            Color.clear.frame(height: 12)
        }
    }

    private func emphasisTint(_ h: SynastryGridHeader, base: Color) -> Color {
        if h.name == "Asc" { return Theme.Colors.textPrimary }   // grid.py:197 / 234
        if h.isWinner { return Theme.Colors.accent }
        return base
    }

    @ViewBuilder private func slotView(_ slot: GridSlot) -> some View {
        switch slot {
        case .empty(let isExt):
            Rectangle()
                .fill(isExt ? Theme.Colors.bgChip.opacity(0.6) : Theme.Colors.bgSunken)
                .overlay(Rectangle().stroke(Theme.Colors.separator, lineWidth: 0.5))
        case .header(_, let symbol):
            Text(symbol)
                .font(Theme.Fonts.glyph(size: 16))
                .foregroundStyle(Theme.Colors.textPrimary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.Colors.bgChip)
        case .aspect(let a):
            ZStack {
                Rectangle()
                    .fill(a.isExtended ? Theme.Colors.bgSurfaceRaised : Theme.Colors.bgSurface)
                AstroGlyph(aspect: a.aspect, size: 18, tint: RelAspectColor.color(a))
                if showRealOrb {
                    // grid.py:281 — "Góc thật" hiện ở góc dưới-trái ô.
                    VStack { Spacer(); HStack { Text(a.orbText)
                        .font(.system(size: 7))
                        .foregroundStyle(Theme.Colors.textMuted); Spacer() } }
                    .padding(2)
                }
            }
            .overlay(border(a))
        }
    }

    @ViewBuilder private func border(_ a: GridAspectCell) -> some View {
        switch a.border {
        case .bold:                                   // grid.py:224 — orb < 1°
            Rectangle().stroke(Theme.Colors.accent, lineWidth: 2)
        case .dashed:                                 // grid.py:224 — orb > 6.5°
            Rectangle().stroke(Theme.Colors.textMuted,
                               style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
        case .normal:
            Rectangle().stroke(Theme.Colors.separator, lineWidth: 0.5)
        }
    }

    private var legend: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Space.sm) {
                Chip("Trùng", glyph: "☌", tone: .neutral)
                Chip("Lục hợp", glyph: "⚹", tone: .accent)
                Chip("Vuông", glyph: "□", tone: .danger)
                Chip("Tam hợp", glyph: "△", tone: .accent)
                Chip("Đối đỉnh", glyph: "☍", tone: .danger)
                Chip("Viền đậm = orb < 1°", tone: .success)
                Chip("Viền đứt = orb > 6.5°", tone: .warning)
            }
        }
    }
}
