//  TransitReports.swift
//  Port sang MÔ HÌNH DỮ LIỆU (không sinh HTML) của:
//    • `generate_current_sky_report`        — app/utils/reports/transit.py:8-26
//    • `generate_personal_transit_report`   — app/utils/reports/transit.py:55-160
//    • vòng quét góc `scan()` trong route    — app/routes/transits.py:126-136
//    • `get_outer_planet_cycle_data`         — app/routes/transits.py:55-76
//
//  Giữ ĐÚNG danh sách hiển thị, ĐÚNG thứ tự, ĐÚNG cách làm tròn của web.

import Foundation

// MARK: - Bảng "VỊ TRÍ HÀNH TINH" (Vận hạn chung / Current Sky) ---------------

public struct CurrentSkyRow: Identifiable, Hashable, Sendable {
    public var id: String { planet }
    public let planet: String
    public let planetSymbol: String
    public let zodiacIndex: Int
    public let zodiacSymbol: String
    public let zodiacName: String
    /// "12°34'" — web dùng `int(z_deg)` và `int((z_deg % 1) * 60)` (transit.py:22).
    public let degreeText: String
}

public enum TransitReports {

    /// `reports/transit.py:10-11` — đúng 13 đối tượng, KHÔNG có cột Nhà.
    public static let currentSkyOrder: [String] = [
        "Sun", "Moon", "Mercury", "Venus", "Mars", "Jupiter", "Saturn",
        "Uranus", "Neptune", "Pluto", "True Node", "Chiron", "Vertex"
    ]

    /// `int(deg)°int((deg % 1) * 60)'` — cắt phần thập phân, KHÔNG làm tròn.
    public static func degreeText(_ lon: Double) -> String {
        let z = AstroCore.getZodiac(lon)
        let d = Int(z.degInSign)
        let m = Int(pmod(z.degInSign, 1) * 60)
        return "\(d)°\(m)'"
    }

    public static func currentSky(_ chart: Chart) -> [CurrentSkyRow] {
        currentSkyOrder.compactMap { p in
            guard let info = chart.planets[p] else { return nil }
            let z = AstroCore.getZodiac(info.lon)
            return CurrentSkyRow(planet: p,
                                 planetSymbol: AstroConst.planetSymbols[p] ?? p,
                                 zodiacIndex: z.idx,
                                 zodiacSymbol: AstroConst.zodiacSymbols[z.idx],
                                 zodiacName: z.name,
                                 degreeText: degreeText(info.lon))
        }
    }

    // MARK: - Bảng "NHÀ TRANSIT" ---------------------------------------------

    public enum TransitMode: String, Sendable { case single, outerCycle }

    public struct TransitHouseRow: Identifiable, Hashable, Sendable {
        public var id: String { planet }
        public let planet: String
        public let planetSymbol: String
        public let houseStart: Int
        /// Chỉ có ở chế độ "Đại hạn" (`outer_cycle`) — web hiện "?" nếu thiếu.
        public let houseEnd: Int?
    }

    /// `reports/transit.py:72-83` — danh sách hiển thị khác nhau theo chế độ.
    public static func houseDisplayOrder(_ mode: TransitMode) -> [String] {
        mode == .outerCycle
            ? ["Jupiter", "Saturn", "Uranus", "Neptune", "Pluto"]
            : ["Sun", "Moon", "Mercury", "Venus", "Mars",
               "Jupiter", "Saturn", "Uranus", "Neptune", "Pluto"]
    }

    public static func houseRows(natal: Chart, transit: Chart,
                                 mode: TransitMode,
                                 transitEnd: Chart? = nil) -> [TransitHouseRow] {
        houseDisplayOrder(mode).compactMap { p in
            guard let tp = transit.planets[p] else { return nil }
            let hStart = AstroCore.getHouseOfPlanet(tp.lon, natal.cusps)
            var hEnd: Int? = nil
            if mode == .outerCycle, let te = transitEnd, let tep = te.planets[p] {
                hEnd = AstroCore.getHouseOfPlanet(tep.lon, natal.cusps)
            }
            return TransitHouseRow(planet: p,
                                   planetSymbol: AstroConst.planetSymbols[p] ?? p,
                                   houseStart: hStart, houseEnd: hEnd)
        }
    }

    // MARK: - Bảng "GÓC TRANSIT" ---------------------------------------------

    public struct TransitAspectRow: Identifiable, Hashable, Sendable {
        public var id: String { "\(transitPlanet)|\(aspectName)|\(natalPoint)" }
        public let transitPlanet: String
        public let transitSymbol: String
        public let aspectSymbol: String
        public let aspectName: String
        public let aspectType: String          // Hard / Soft / Minor
        public let natalPoint: String
        public let natalSymbol: String
        public let orb: Double
        /// `f"{int(orb)}º{int((orb % 1) * 60):02d}"` — transits.py:135.
        public let orbText: String

        /// Web rút gọn tên trong ô (`reports/transit.py:121`).
        public var natalDisplayName: String {
            natalPoint.replacingOccurrences(of: "True Node", with: "T.Node")
                      .replacingOccurrences(of: "South Node", with: "S.Node")
        }
    }

    /// Port `scan()` — `app/routes/transits.py:126-136`.
    /// Chỉ giữ góc thuộc `MAJOR_ASPECTS` và `orb < 3.0`.
    public static func aspectRows(natal: Chart, transit: Chart,
                                  natalTargets: [String]) -> [TransitAspectRow] {
        var out: [TransitAspectRow] = []
        for tp in AstroConst.transitPlanetOrder {
            guard let tpLon = transit.planets[tp]?.lon else { continue }
            for np in natalTargets {
                let nLon: Double
                if np == "South Node" {
                    nLon = pmod((natal.planets["True Node"]?.lon ?? 0) + 180, 360)
                } else {
                    guard let v = natal.planets[np]?.lon else { continue }
                    nLon = v
                }
                guard let asp = AstroCore.checkAspect(tpLon, nLon) else { continue }
                guard AstroConst.majorAspects.contains(asp.aspect), asp.orb < 3.0 else { continue }
                let orbText = "\(Int(asp.orb))º" + String(format: "%02d", Int(pmod(asp.orb, 1) * 60))
                out.append(TransitAspectRow(
                    transitPlanet: tp,
                    transitSymbol: AstroConst.planetSymbols[tp] ?? tp,
                    aspectSymbol: asp.symbol,
                    aspectName: asp.aspect,
                    aspectType: asp.type,
                    natalPoint: np,
                    natalSymbol: np == "South Node" ? "☋" : (AstroConst.planetSymbols[np] ?? np),
                    orb: asp.orb,
                    orbText: orbText))
            }
        }
        return out
    }

    /// Hai khối web hiển thị riêng: "Góc với các hành tinh" và "Góc với các điểm khác".
    public static func aspectSections(natal: Chart, transit: Chart)
        -> (planets: [TransitAspectRow], points: [TransitAspectRow]) {
        (aspectRows(natal: natal, transit: transit, natalTargets: AstroConst.transitPlanetOrder),
         aspectRows(natal: natal, transit: transit, natalTargets: AstroConst.natalSpecialPoints))
    }

    // MARK: - Dải quét của 5 hành tinh ngoài (Đại hạn) ------------------------

    public struct OuterCycleSpan: Identifiable, Hashable, Sendable {
        public var id: String { planet }
        public let planet: String
        public let lonA: Double     // vị trí đầu kỳ
        public let lonB: Double     // vị trí cuối kỳ
        public let spanStart: Double
        public let spanEnd: Double
        public let spanLength: Double
    }

    /// Port `get_outer_planet_cycle_data` — `app/routes/transits.py:55-76`.
    /// Bước quét 5 ngày, ĐÚNG như web.
    public static func outerCycleData(lat: Double, lon: Double,
                                      start: CivilDateTime, end: CivilDateTime) -> [OuterCycleSpan]? {
        let order = ["Jupiter", "Saturn", "Uranus", "Neptune", "Pluto"]
        guard let chartA = AstroCore.calculateChart(dobStr: start.dmy, tobStr: "00:00",
                                                    lat: lat, lon: lon, tzStr: "UTC"),
              let chartB = AstroCore.calculateChart(dobStr: end.dmy, tobStr: "00:00",
                                                    lat: lat, lon: lon, tzStr: "UTC")
        else { return nil }

        let jdStart = chartA.jd, jdEnd = chartB.jd
        let totalDays = Int(jdEnd - jdStart)
        let stepDays = 5
        let steps = max(1, totalDays / stepDays)

        var out: [OuterCycleSpan] = []
        for p in order {
            guard let a = chartA.planets[p]?.lon, let b = chartB.planets[p]?.lon,
                  let pid = AstroConst.planetIDMap[p] else { continue }
            var longitudes: [Double] = [a]
            if steps >= 1 {
                for i in 1...steps {
                    let res = SwissEph.calcUT(jdStart + Double(i * stepDays), pid,
                                              SweFlag.swieph | SweFlag.speed)
                    longitudes.append(res.xx[0])
                }
            }
            longitudes.append(b)
            let diffs = longitudes.map { pmod($0 - a + 180, 360) - 180 }
            guard let mn = diffs.min(), let mx = diffs.max() else { continue }
            out.append(OuterCycleSpan(planet: p, lonA: a, lonB: b,
                                      spanStart: pmod(a + mn, 360),
                                      spanEnd: pmod(a + mx, 360),
                                      spanLength: mx - mn))
        }
        return out
    }
}
