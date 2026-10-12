//  ChartModels.swift
//  MÔ HÌNH DỮ LIỆU VẼ — thuần tính toán, KHÔNG import SwiftUI (chạy được trong harness CLI).
//  Mọi quy tắc chọn màu / độ mờ / độ dày đều bám nguyên văn code Python của web.
//
//  NGUỒN:
//    · app/utils/drawing/natal.py:150-215      -> danh sách hành tinh, lane, aspect natal
//    · app/utils/drawing/synastry.py:84-176    -> 2 vòng A/B + bộ orb riêng
//    · app/astro00_lib/composite_logic.py:1-89 -> chart composite (midpoint)

import Foundation

// MARK: - Phân loại đường góc chiếu

/// 5 nhóm màu của web — `natal.py:203-211`, bảng màu `styles.py:2-6`.
public enum AspectVisual: String {
    case conjunction, opposition, hard, soft, minor
}

public struct AspectEdge: Identifiable {
    public let id: String
    public let nameA: String
    public let nameB: String
    public let lonA: Double
    public let lonB: Double
    public let aspect: String        // "Conjunction", "Square", …
    public let aspectVN: String
    public let symbol: String
    public let type: String          // "Hard" / "Soft" / "Minor"
    public let orb: Double
    public let visual: AspectVisual
    /// 1 = khít tuyệt đối, 0 = sát mép orb — `natal.py:213-216`.
    public let orbRatio: Double
    /// `natal.py:217` alpha = 0.4 + 0.4*orbRatio (góc thường);
    /// `natal.py:208-209` alpha = 0.8/0.4 (trùng tụ).
    public let alpha: Double
    /// Chỉ có nghĩa với Conjunction — `natal.py:207`.
    public let lineWidth: Double

    public func involves(_ name: String) -> Bool { nameA == name || nameB == name }
}

/// Các điểm KHÔNG vẽ đường góc chiếu — `natal.py:198`, `synastry.py:130`.
public let chartNonPlanets: Set<String> = ["Asc", "MC", "True Node", "Chiron", "Lilith", "Vertex"]

/// Bộ orb siêu chặt riêng cho bánh xe synastry — `synastry.py:133-141`.
public let synastryChartOrbs: [String: Double] = [
    "Conjunction": 5.0, "Opposition": 5.0, "Square": 5.0,
    "Trine": 5.0, "Sextile": 3.0, "Semisextile": 1.5, "Quincunx": 1.5
]

private func visualFor(_ hit: AspectHit) -> AspectVisual {
    if hit.aspect == "Conjunction" { return .conjunction }
    if hit.aspect == "Opposition" { return .opposition }
    if hit.type == "Hard" { return .hard }
    if hit.type == "Minor" { return .minor }
    return .soft
}

private func makeEdge(_ a: String, _ lonA: Double, _ b: String, _ lonB: Double,
                      _ hit: AspectHit, maxOrb: Double) -> AspectEdge {
    var ratio = 1.0 - (hit.orb / maxOrb)
    if ratio < 0 { ratio = 0 }
    let isConj = hit.aspect == "Conjunction"
    let alpha = isConj ? (hit.orb < 3 ? 0.8 : 0.4) : (0.4 + 0.4 * ratio)
    let lw = isConj ? (hit.orb < 2 ? 4.0 : 2.0) : 0.0
    return AspectEdge(id: "\(a)|\(b)|\(hit.aspect)", nameA: a, nameB: b, lonA: lonA, lonB: lonB,
                      aspect: hit.aspect, aspectVN: hit.nameVN, symbol: hit.symbol, type: hit.type,
                      orb: hit.orb, visual: visualFor(hit), orbRatio: ratio, alpha: alpha, lineWidth: lw)
}

// MARK: - Thông tin 1 hành tinh (phục vụ chạm để xem chi tiết)

public struct PlanetDetail: Identifiable {
    public var id: String { name }
    public let name: String
    public let symbol: String
    public let lon: Double
    public let signIndex: Int
    public let signName: String
    public let signSymbol: String
    public let degInSign: Double
    public let house: Int
    public let speed: Double
    public var isRetrograde: Bool { speed < 0 }
    /// Chuỗi "12°34′ ♌" kiểu chiêm tinh.
    public var degreeText: String {
        let d = Int(degInSign)
        let m = Int((degInSign - Double(d)) * 60)
        return String(format: "%d°%02d′", d, m)
    }
}

// MARK: - Vòng ngoài TRANSIT (tham số `transit_data` / `transit_mode`)
//
//  Port `app/utils/drawing/natal.py:36` — chữ ký web:
//      create_natal_chart_image(chart_data, name, hide_houses=False,
//                               transit_data=None, transit_mode='single',
//                               static_aries_asc=False)
//  Hai chế độ:
//   · 'single'      (natal.py:222-239) — vẽ ký hiệu hành tinh transit ở vòng ngoài,
//                    có 2 vạch chân tại kinh độ thật + nét đứt nối tới ký hiệu đã giãn.
//   · 'outer_cycle' (natal.py:45-77, 241-270) — mỗi hành tinh ngoài một DẢI QUÉT
//                    (start→end) xếp vào lane không chồng nhau; R_OUTER giãn theo số lane.

public enum WheelTransitMode: String, Sendable {
    case single
    case outerCycle
}

/// Một hành tinh transit ở chế độ `single` — `natal.py:226-230` (`transit_data["planets"]`).
public struct TransitPoint: Sendable, Hashable {
    public let name: String
    public let lon: Double
    public init(name: String, lon: Double) { self.name = name; self.lon = lon }
}

/// Một dải quét đại hạn — `natal.py:49-55` (`transit_data[p_name]`).
public struct TransitArcInput: Sendable, Hashable {
    public let name: String
    /// `natal.py:53` — mép đầu/cuối của dải (đã chuẩn hoá 0…360).
    public let start: Double
    public let end: Double
    /// `natal.py:53` `len` — khoá SẮP XẾP lane (dài trước).
    public let length: Double
    /// `natal.py:54` `A`/`B` — vị trí đầu kỳ và cuối kỳ (vẽ vạch tick trên dải).
    public let lonA: Double
    public let lonB: Double
    public init(name: String, start: Double, end: Double, length: Double,
                lonA: Double, lonB: Double) {
        self.name = name; self.start = start; self.end = end
        self.length = length; self.lonA = lonA; self.lonB = lonB
    }
}

/// Gói dữ liệu transit đưa vào `NatalWheelModel` — tương đương cặp
/// (`transit_data`, `transit_mode`) của web.
public struct WheelTransitData: Sendable {
    public let mode: WheelTransitMode
    /// Chỉ dùng ở `.single`.
    public let planets: [TransitPoint]
    /// Chỉ dùng ở `.outerCycle`.
    public let arcs: [TransitArcInput]

    public init(mode: WheelTransitMode, planets: [TransitPoint] = [], arcs: [TransitArcInput] = []) {
        self.mode = mode; self.planets = planets; self.arcs = arcs
    }

    /// Dựng nhanh từ một `Chart` transit — `natal.py:226-230` bỏ Asc/MC/Lilith.
    public static func single(from chart: Chart) -> WheelTransitData {
        var pts: [TransitPoint] = []
        for n in chart.planetOrder {
            guard AstroConst.planetSymbols[n] != nil else { continue }   // natal.py:227
            if n == "Asc" || n == "MC" || n == "Lilith" { continue }     // natal.py:228
            guard let p = chart.planets[n] else { continue }
            pts.append(TransitPoint(name: n, lon: p.lon))
        }
        return WheelTransitData(mode: .single, planets: pts)
    }
}

/// Dải quét sau khi đã chia lane — `natal.py:57-75`.
public struct PlacedTransitArc: Sendable, Hashable {
    public let arc: TransitArcInput
    public let laneIndex: Int
    public let symbol: String
}

/// Bán kính riêng của vòng transit — `natal.py:223` (single) và `natal.py:242,238` (outer_cycle).
public enum TransitRing {
    // --- single: natal.py:223 ---
    public static let singleRootBase: Double = NatalRing.zodiacOuter            // 9.5
    public static let singleRootTip:  Double = NatalRing.zodiacOuter + 0.5      // 10.0
    public static let singleTextPos:  Double = NatalRing.zodiacOuter + 0.5 + 1.5 // 11.5
    // --- outer_cycle: natal.py:242 ---
    public static let cycleRootBase: Double = NatalRing.zodiacOuter             // 9.5
    public static let cycleRootTip:  Double = NatalRing.zodiacOuter + 0.5       // 10.0
    public static let cycleTextPos:  Double = NatalRing.zodiacOuter + 1.5       // 11.0
    /// natal.py:238 — LƯU Ý: web dùng 11.5+0.5 ở phần VẼ, khác 9.5+0.5 ở phần TÍNH
    /// R_OUTER (natal.py:46). Giữ nguyên cả hai để khỏi lệch hình.
    public static let laneBaseDraw: Double  = 11.5 + 0.5                        // 12.0
    /// natal.py:46 — dùng để TÍNH lại R_OUTER.
    public static let laneBaseCalc: Double  = NatalRing.zodiacOuter + 0.5       // 10.0
    public static let laneHeight: Double    = 0.5                               // natal.py:47
    public static let laneBarThickness: Double = 0.05                           // natal.py:265
    public static let laneTickLen: Double   = 0.2                               // natal.py:238

    /// natal.py:45-77 — chia lane không đè nhau + tính lại R_OUTER.
    public static func layout(_ arcs: [TransitArcInput]) -> (placed: [PlacedTransitArc], outer: Double) {
        guard !arcs.isEmpty else { return ([], NatalRing.outer) }
        // natal.py:56 — dài trước. `sorted(key=..., reverse=True)` của Python ỔN ĐỊNH,
        // nên kèm chỉ số gốc làm khoá phụ cho khớp.
        let sorted = arcs.enumerated().sorted { a, b in
            a.element.length == b.element.length ? a.offset < b.offset
                                                 : a.element.length > b.element.length
        }
        var lanes: [[TransitArcInput]] = []
        var placed: [PlacedTransitArc] = []
        for item in sorted {
            let p = item.element
            var assigned = -1
            for (idx, laneObjs) in lanes.enumerated() {                       // natal.py:59-68
                var collision = false
                for existing in laneObjs
                where checkArcCollision((p.start, p.end), (existing.start, existing.end)) {
                    collision = true; break
                }
                if !collision { assigned = idx; break }
            }
            if assigned == -1 { lanes.append([]); assigned = lanes.count - 1 } // natal.py:69-71
            lanes[assigned].append(p)
            placed.append(PlacedTransitArc(arc: p, laneIndex: assigned,
                                           symbol: AstroConst.planetSymbols[p.name] ?? "?"))
        }
        // natal.py:76-77
        let calculated = laneBaseCalc + Double(lanes.count) * laneHeight + 0.5
        return (placed, max(NatalRing.outer, calculated))
    }
}

// MARK: - Bánh xe 1 vòng (natal / composite / current sky)

public struct NatalWheelModel {
    public let title: String
    public let ascDeg: Double
    /// 12 cusp đã bỏ phần tử dummy đầu — `natal.py:139`.
    public let cusps: [Double]
    public let placements: [PlacedPlanet]
    public let aspects: [AspectEdge]
    public let details: [String: PlanetDetail]
    /// (số nhà, kinh độ giữa nhà) — `natal.py:154-156`.
    public let houseLabels: [(number: Int, lon: Double)]
    public let hideHouses: Bool

    // --- Vòng ngoài transit — `natal.py:36` (transit_data / transit_mode) ---
    /// `nil` = không có vòng transit (đúng mặc định `transit_data=None` của web).
    public let transitMode: WheelTransitMode?
    /// Ký hiệu transit đã giãn cách (cả 2 chế độ) — `natal.py:231-232` / `natal.py:244-246`.
    public let transitPlacements: [PlacedPlanet]
    /// Dải quét đại hạn đã chia lane — chỉ có ở `.outerCycle` (`natal.py:57-75`).
    public let transitArcs: [PlacedTransitArc]
    /// Bán kính ngoài cùng THỰC TẾ — `natal.py:38-77`. Không có transit thì bằng 11.5.
    public let outerRadius: Double
    /// Đuôi tiêu đề web thêm vào — `natal.py:272-274`.
    public var titleSuffix: String {
        guard let m = transitMode else { return "" }
        return m == .single ? " & TRANSITS" : " & OUTER CYCLES"
    }

    public init(chart: Chart, title: String, hideHouses: Bool = false, staticAriesAsc: Bool = false,
                transit: WheelTransitData? = nil) {
        self.title = title
        self.hideHouses = hideHouses
        self.ascDeg = staticAriesAsc ? 0 : (chart.angles["Asc"] ?? 0)          // natal.py:110-116

        let rawCusps = chart.cusps
        let realCusps = rawCusps.count == 13 ? Array(rawCusps.dropFirst()) : rawCusps
        self.cusps = realCusps

        // natal.py:150-157 — bỏ Lilith, Asc, MC khỏi vòng ký hiệu
        var list: [PlanetGlyphInput] = []
        for name in chart.planetOrder {
            guard let sym = AstroConst.planetSymbols[name] else { continue }
            if name == "Lilith" || name == "Asc" || name == "MC" { continue }
            guard let p = chart.planets[name] else { continue }
            list.append(PlanetGlyphInput(name: name, lon: p.lon, symbol: sym))
        }
        // natal.py:160-164 — Aries tĩnh thì dùng cusps giả đều 30°
        let drawCusps = staticAriesAsc ? (0..<12).map { Double($0) * 30.0 } : realCusps
        self.placements = optimizePlanetPositionsByHouse(list, cusps: drawCusps, lanes: NatalRing.lanes)

        // natal.py:196-219 — đường góc chiếu
        var edges: [AspectEdge] = []
        let keys = chart.planetOrder.filter { AstroConst.planetSymbols[$0] != nil }
        for i in 0..<keys.count {
            for j in (i + 1)..<keys.count {
                let p1 = keys[i], p2 = keys[j]
                if chartNonPlanets.contains(p1) || chartNonPlanets.contains(p2) { continue }
                guard let l1 = chart.planets[p1]?.lon, let l2 = chart.planets[p2]?.lon else { continue }
                guard let hit = AstroCore.checkAspect(l1, l2) else { continue }
                let maxOrb = AstroConst.aspectByName[hit.aspect]?.orb ?? 10.0    // natal.py:213
                edges.append(makeEdge(p1, l1, p2, l2, hit, maxOrb: maxOrb))
            }
        }
        self.aspects = edges

        var det: [String: PlanetDetail] = [:]
        for name in chart.planetOrder {
            guard let p = chart.planets[name], let sym = AstroConst.planetSymbols[name] else { continue }
            let z = AstroCore.getZodiac(p.lon)
            det[name] = PlanetDetail(name: name, symbol: sym, lon: p.lon,
                                     signIndex: z.idx, signName: z.name,
                                     signSymbol: AstroConst.zodiacSymbols[z.idx],
                                     degInSign: z.degInSign,
                                     house: AstroCore.getHouseOfPlanet(p.lon, realCusps),
                                     speed: p.speed)
        }
        self.details = det

        var labels: [(number: Int, lon: Double)] = []
        for i in 0..<12 {
            let deg = realCusps[i]
            let next = realCusps[(i + 1) % 12]
            let mid = next > deg ? (deg + next) / 2 : (deg + next + 360) / 2   // natal.py:155
            labels.append((i + 1, normDeg(mid)))
        }
        self.houseLabels = labels

        // ── Vòng ngoài transit — natal.py:38-77 + 222-270 ────────────────────
        self.transitMode = transit?.mode
        // natal.py:230 / 247 — cả 2 chế độ đều giãn ký hiệu trên cusps GIẢ đều 30°.
        let dummyCusps = (0..<12).map { Double($0) * 30.0 }
        switch transit?.mode {
        case .none:
            self.transitPlacements = []
            self.transitArcs = []
            self.outerRadius = NatalRing.outer                    // natal.py:40

        case .some(.single):
            let pts = transit?.planets ?? []
            let inputs = pts.map { PlanetGlyphInput(name: $0.name, lon: $0.lon,
                                                    symbol: AstroConst.planetSymbols[$0.name] ?? "?") }
            // natal.py:231 — lanes=[R_TEXT_POS] (một lane duy nhất).
            self.transitPlacements = optimizePlanetPositionsByHouse(inputs, cusps: dummyCusps,
                                                                    lanes: [TransitRing.singleTextPos])
            self.transitArcs = []
            // natal.py:40 giữ R_OUTER = 11.5, nhưng ký hiệu transit nằm ĐÚNG 11.5
            // (natal.py:223 R_TEXT_POS) nên trên màn hẹp của iPhone chúng bị cắt mất một nửa
            // (đã chụp ảnh thấy ♄ ở mép trái, ♀ ở mép phải bị xén).
            // matplotlib có lề ngoài; ở đây nới KHUNG NHÌN thêm 0.9 đơn vị.
            // CHỈ đổi tỉ lệ vẽ, KHÔNG đổi bất kỳ toạ độ chiêm tinh nào.
            self.outerRadius = TransitRing.singleTextPos + 0.9

        case .some(.outerCycle):
            let arcs = transit?.arcs ?? []
            let (placedArcs, outer) = TransitRing.layout(arcs)
            self.transitArcs = placedArcs
            // natal.py:243-245 — ký hiệu đặt tại vị trí ĐẦU KỲ ('A'), lane [R_TRANSIT_TEXT].
            let inputs = placedArcs.map { PlanetGlyphInput(name: $0.arc.name, lon: $0.arc.lonA,
                                                           symbol: $0.symbol) }
            self.transitPlacements = optimizePlanetPositionsByHouse(inputs, cusps: dummyCusps,
                                                                    lanes: [TransitRing.cycleTextPos])
            // natal.py:77 + lề 0.9 cho ký hiệu ở lane ngoài cùng khỏi bị xén.
            self.outerRadius = outer + 0.9
        }
    }

    /// Các góc mà một hành tinh tham gia — dùng cho thẻ chi tiết khi chạm.
    public func aspects(of name: String) -> [AspectEdge] {
        aspects.filter { $0.involves(name) }.sorted { $0.orb < $1.orb }
    }
}

// MARK: - Bánh xe synastry 2 vòng

public struct SynastryWheelModel {
    public let nameA: String
    public let nameB: String
    public let ascDeg: Double                 // synastry.py:27 — luôn lấy Asc của A
    public let cuspsA: [Double]
    public let cuspsB: [Double]
    public let placementsA: [PlacedPlanet]
    public let placementsB: [PlacedPlanet]
    public let aspects: [AspectEdge]          // A × B
    public let detailsA: [String: PlanetDetail]
    public let detailsB: [String: PlanetDetail]
    public let anglesA: [String: Double]
    public let anglesB: [String: Double]

    public init(chartA: Chart, chartB: Chart, nameA: String, nameB: String) {
        self.nameA = nameA; self.nameB = nameB
        self.ascDeg = chartA.angles["Asc"] ?? 0
        func real(_ c: [Double]) -> [Double] { c.count == 13 ? Array(c.dropFirst()) : c }
        self.cuspsA = real(chartA.cusps)
        self.cuspsB = real(chartB.cusps)
        self.anglesA = chartA.angles
        self.anglesB = chartB.angles

        func glyphs(_ ch: Chart) -> [PlanetGlyphInput] {          // synastry.py:84-89 / 102-107
            var out: [PlanetGlyphInput] = []
            for n in ch.planetOrder {
                guard let sym = AstroConst.planetSymbols[n] else { continue }
                if n == "Lilith" || n == "Asc" || n == "MC" { continue }
                guard let p = ch.planets[n] else { continue }
                out.append(PlanetGlyphInput(name: n, lon: p.lon, symbol: sym))
            }
            return out
        }
        self.placementsA = optimizePlanetPositionsByHouse(glyphs(chartA), cusps: chartA.cusps,
                                                          lanes: SynastryRing.lanesA)
        self.placementsB = optimizePlanetPositionsByHouse(glyphs(chartB), cusps: chartB.cusps,
                                                          lanes: SynastryRing.lanesB)

        // synastry.py:144-176 — mọi cặp A×B, orb siêu chặt, bỏ điểm ảo
        var edges: [AspectEdge] = []
        for na in chartA.planetOrder where AstroConst.planetSymbols[na] != nil {
            if chartNonPlanets.contains(na) { continue }
            guard let la = chartA.planets[na]?.lon else { continue }
            for nb in chartB.planetOrder where AstroConst.planetSymbols[nb] != nil {
                if chartNonPlanets.contains(nb) { continue }
                guard let lb = chartB.planets[nb]?.lon else { continue }
                guard let hit = AstroCore.checkAspect(la, lb, customOrbs: synastryChartOrbs) else { continue }
                let maxOrb = synastryChartOrbs[hit.aspect] ?? 10.0        // synastry.py:170
                edges.append(makeEdge(na, la, nb, lb, hit, maxOrb: maxOrb))
            }
        }
        self.aspects = edges

        func details(_ ch: Chart, _ cusps: [Double]) -> [String: PlanetDetail] {
            var d: [String: PlanetDetail] = [:]
            for n in ch.planetOrder {
                guard let p = ch.planets[n], let sym = AstroConst.planetSymbols[n] else { continue }
                let z = AstroCore.getZodiac(p.lon)
                d[n] = PlanetDetail(name: n, symbol: sym, lon: p.lon, signIndex: z.idx,
                                    signName: z.name, signSymbol: AstroConst.zodiacSymbols[z.idx],
                                    degInSign: z.degInSign,
                                    house: AstroCore.getHouseOfPlanet(p.lon, cusps), speed: p.speed)
            }
            return d
        }
        self.detailsA = details(chartA, cuspsA)
        self.detailsB = details(chartB, cuspsB)
    }

    public func aspects(of name: String, owner: SynastryOwner) -> [AspectEdge] {
        aspects.filter { owner == .a ? $0.nameA == name : $0.nameB == name }.sorted { $0.orb < $1.orb }
    }
}

public enum SynastryOwner { case a, b }

// MARK: - Composite (midpoint) — ĐÃ GỘP, KHÔNG CÒN BẢN PORT THỨ HAI Ở ĐÂY
//
//  W21: trước đây file này có bản port riêng của `composite_logic.py`
//  (`compositeMidpoint` + `CompositeChartBuilder.build`), song song với
//  `Src/Relationship/CompositeLogic.swift` (bản đã đối chiếu parity 0 lệch).
//  Hai bản cho CÙNG số nhưng khác thứ tự `planetOrder` và khác độ dài `cusps`
//  (13 phần tử có dummy 0.0 so với 12) → nguy cơ lệch về sau.
//  Nay chỉ còn MỘT nguồn: `CompositeLogic`. Phần dưới chỉ là lớp vỏ gọi sang.

/// Trung điểm cung ngắn nhất — `composite_logic.py:1-11`.
/// Gọi thẳng `CompositeLogic.getMidpoint` (Src/Relationship/CompositeLogic.swift:33).
@inline(__always)
public func compositeMidpoint(_ lon1: Double, _ lon2: Double) -> Double {
    CompositeLogic.getMidpoint(lon1, lon2)
}

public enum CompositeChartBuilder {
    /// Vỏ mỏng cho `CompositeLogic.calculateCompositeChart`
    /// (Src/Relationship/CompositeLogic.swift:48 — port `composite_logic.py:13-81`).
    /// Web vẽ composite bằng chính hàm vẽ natal (`app/routes/charts.py:170`),
    /// nên trả về `Chart` để đưa thẳng vào `NatalWheelModel`.
    /// Trả `nil` khi thiếu cusp — đúng chỗ Python ném IndexError rồi ra trang trắng.
    public static func build(_ cA: Chart, _ cB: Chart) -> Chart? {
        CompositeLogic.calculateCompositeChart(cA, cB)?.chart
    }
}
