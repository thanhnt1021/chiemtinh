//  AspectGridModel.swift
//  BẢNG GÓC CHIẾU (aspect grid) — mô hình dữ liệu thuần, port từ `app/utils/drawing/grid.py`.
//  · Natal  : bảng TAM GIÁC, ô chéo là ký hiệu hành tinh   — grid.py:225-359
//  · Synastry: bảng CHỮ NHẬT A(hàng) × B(cột)               — grid.py:141-224

import Foundation

public enum GridBorder { case normal, bold, dashed }

public struct GridAspectCell {
    public let rowName: String
    public let colName: String
    public let aspect: String
    public let aspectVN: String
    public let symbol: String
    public let type: String
    public let orb: Double
    /// `grid.py:349` — số nguyên hiển thị góc lệch (Python `round`, làm tròn về số chẵn).
    public let orbRounded: Int
    /// `grid.py:348` — chuỗi "3°24'".
    public let orbText: String
    public let visual: AspectVisual
    public let border: GridBorder
    /// `grid.py:207` — cặp có dính điểm ảo (True Node / Chiron / Vertex) thì nền khác.
    public let isExtended: Bool
}

public enum GridSlot {
    case empty(isExtended: Bool)
    case header(name: String, symbol: String)
    case aspect(GridAspectCell)
}

/// `grid.py:120-121` — điểm ảo chỉ hiện khi orb ≤ 3°.
public let gridSpecialPoints: Set<String> = ["True Node", "Chiron", "Vertex"]

private func orbText(_ orb: Double) -> String {
    let d = Int(orb)
    return "\(d)°\(Int((orb - Double(d)) * 60))'"
}

private func visual(_ hit: AspectHit) -> AspectVisual {
    if hit.aspect == "Conjunction" { return .conjunction }
    if hit.aspect == "Opposition" { return .opposition }
    if hit.type == "Hard" { return .hard }
    if hit.type == "Minor" { return .minor }
    return .soft
}

// MARK: - Bảng natal (tam giác)

public struct NatalAspectGridModel {
    /// `grid.py:110-111` NATAL_OBJS, lọc theo hành tinh thật sự có trong lá số.
    public let objects: [String]
    /// `grid.py:227-235` — đếm số góc CHÍNH (bỏ Minor) của 10 hành tinh lõi.
    public let counts: [String: Int]
    public let maxCount: Int
    /// rows[r] có đúng (max_c + 1) phần tử — `grid.py:259`.
    public let rows: [[GridSlot]]

    public init(chart: Chart) {
        let natalObjs = AstroConst.fullObjectsOrder                    // grid.py:110-111
        let objs = natalObjs.filter { chart.planets[$0] != nil }
        self.objects = objs

        // grid.py:227-235
        let core = AstroConst.corePlanets.filter { chart.planets[$0] != nil }
        var cnt: [String: Int] = [:]
        var maxC = 0
        for o in core {
            var n = 0
            for t in core where t != o {
                guard let lo = chart.planets[o]?.lon, let lt = chart.planets[t]?.lon else { continue }
                if let h = AstroCore.checkAspect(lo, lt), h.type != "Minor" { n += 1 }
            }
            cnt[o] = n
            if n > maxC { maxC = n }
        }
        self.counts = cnt
        self.maxCount = maxC

        var out: [[GridSlot]] = []
        for r in 0..<objs.count {
            let pRow = objs[r]
            // grid.py:256 — hàng MC bỏ cột Asc liền trước
            let maxCol = (pRow == "MC" && r > 0 && objs[r - 1] == "Asc") ? r - 1 : r
            var line: [GridSlot] = []
            for c in 0...max(maxCol, 0) {
                if c == maxCol {
                    line.append(.header(name: pRow, symbol: AstroConst.planetSymbols[pRow] ?? pRow))
                    continue
                }
                let pCol = objs[c]
                guard let l1 = chart.planets[pRow]?.lon, let l2 = chart.planets[pCol]?.lon,
                      let hit = AstroCore.checkAspect(l1, l2) else {
                    line.append(.empty(isExtended: false)); continue
                }
                // grid.py:266-271
                let special = gridSpecialPoints.contains(pRow) || gridSpecialPoints.contains(pCol)
                if special && hit.orb > 3.0 { line.append(.empty(isExtended: false)); continue }
                line.append(.aspect(GridAspectCell(
                    rowName: pRow, colName: pCol, aspect: hit.aspect, aspectVN: hit.nameVN,
                    symbol: hit.symbol, type: hit.type, orb: hit.orb,
                    orbRounded: AstroCore.roundOrb(hit.orb), orbText: orbText(hit.orb),
                    visual: visual(hit), border: .normal, isExtended: false)))
            }
            out.append(line)
        }
        self.rows = out
    }
}

// MARK: - Bảng synastry (chữ nhật)

public struct SynastryAspectGridModel {
    /// `grid.py:112-113` SYNASTRY_OBJS.
    public static let synastryObjs: [String] = [
        "Sun", "Moon", "Mercury", "Venus", "Mars", "Jupiter", "Saturn", "Uranus",
        "Neptune", "Pluto", "Asc", "True Node", "Chiron", "Vertex"
    ]
    /// `grid.py:124` ASC_INDEX = 10 — từ sau Asc là nhóm "mở rộng" (nền xám).
    public static let ascIndex = 10

    public let rowsObjects: [String]     // của người A
    public let colsObjects: [String]     // của người B
    public let cells: [[GridSlot]]

    public init(chartA: Chart, chartB: Chart) {
        let objs = Self.synastryObjs
        let pa = objs.filter { chartA.planets[$0] != nil }
        let pb = objs.filter { chartB.planets[$0] != nil }
        self.rowsObjects = pa
        self.colsObjects = pb

        var grid: [[GridSlot]] = []
        for rowName in pa {
            var line: [GridSlot] = []
            for colName in pb {
                let iA = objs.firstIndex(of: rowName) ?? 0
                let iB = objs.firstIndex(of: colName) ?? 0
                let isExt = iA > Self.ascIndex || iB > Self.ascIndex          // grid.py:207
                guard let l1 = chartA.planets[rowName]?.lon,
                      let l2 = chartB.planets[colName]?.lon,
                      let hit = AstroCore.checkAspect(l1, l2) else {
                    line.append(.empty(isExtended: isExt)); continue
                }
                // grid.py:210-217 — Minor bị ẩn hoàn toàn; điểm ảo chỉ hiện khi orb ≤ 3
                if hit.type == "Minor" { line.append(.empty(isExtended: isExt)); continue }
                let special = gridSpecialPoints.contains(rowName) || gridSpecialPoints.contains(colName)
                if special && hit.orb > 3.0 { line.append(.empty(isExtended: isExt)); continue }
                // grid.py:224 — viền đậm khi orb < 1°, viền đứt khi orb > 6.5°
                let border: GridBorder = hit.orb < 1.0 ? .bold : (hit.orb > 6.5 ? .dashed : .normal)
                line.append(.aspect(GridAspectCell(
                    rowName: rowName, colName: colName, aspect: hit.aspect, aspectVN: hit.nameVN,
                    symbol: hit.symbol, type: hit.type, orb: hit.orb,
                    orbRounded: AstroCore.roundOrb(hit.orb), orbText: orbText(hit.orb),
                    visual: visual(hit), border: border, isExtended: isExt)))
            }
            grid.append(line)
        }
        self.cells = grid
    }
}
