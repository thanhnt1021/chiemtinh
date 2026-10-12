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

    public init(chart: Chart, title: String, hideHouses: Bool = false, staticAriesAsc: Bool = false) {
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

// MARK: - Composite (midpoint)

/// Port `app/astro00_lib/composite_logic.py:1-13` `get_midpoint`.
public func compositeMidpoint(_ lon1: Double, _ lon2: Double) -> Double {
    let diff = abs(lon1 - lon2)
    var mid = (lon1 + lon2) / 2.0
    if diff > 180 { mid += 180.0 }
    return normDeg(mid)
}

public enum CompositeChartBuilder {
    /// Port `composite_logic.py:15-89` `calculate_composite_chart`.
    /// Web vẽ composite bằng chính hàm vẽ natal (`app/routes/charts.py:170`),
    /// nên ở đây cũng trả về một `Chart` để đưa thẳng vào `NatalWheelModel`.
    public static func build(_ cA: Chart, _ cB: Chart) -> Chart {
        var planets: [String: PlanetPosition] = [:]
        var order: [String] = []

        // composite_logic.py:37-53 — mọi hành tinh có ở CẢ hai lá số
        for name in cA.planetOrder {
            guard let a = cA.planets[name], let b = cB.planets[name] else { continue }
            if name == "Asc" || name == "MC" || name == "Vertex" { continue }
            planets[name] = PlanetPosition(lon: compositeMidpoint(a.lon, b.lon), lat: 0,
                                           speed: (a.speed + b.speed) / 2)
            order.append(name)
        }

        // composite_logic.py:56-64 — trung điểm Asc/MC/Vertex, đồng thời nhét vào planets
        var angles: [String: Double] = [:]
        for angle in ["Asc", "MC", "Vertex"] {
            guard let a1 = cA.angles[angle], let a2 = cB.angles[angle] else { continue }
            let m = compositeMidpoint(a1, a2)
            angles[angle] = m
            planets[angle] = PlanetPosition(lon: m, lat: 0, speed: 0)
        }
        for angle in ["Vertex", "Asc", "MC"] where planets[angle] != nil { order.append(angle) }

        // composite_logic.py:67-86 — cusps trung điểm, giữ phần tử dummy 0.0 ở đầu
        func real(_ c: [Double]) -> [Double] { c.count == 13 ? Array(c.dropFirst()) : c }
        let ra = real(cA.cusps), rb = real(cB.cusps)
        var cusps: [Double] = [0.0]
        for i in 0..<min(12, min(ra.count, rb.count)) {
            cusps.append(compositeMidpoint(ra[i], rb[i]))
        }

        let info = ChartTechnicalInfo(localTime: "Composite Chart", utTime: "N/A", lst: "N/A",
                                      latLon: "Midpoint Method", houseSys: "Composite Cusps")
        return Chart(jd: 0, cusps: cusps, angles: angles, planets: planets, planetOrder: order,
                     info: info, meta: ChartMeta(lat: 0, lon: 0, tz: nil, offsetUsed: 0))
    }
}
