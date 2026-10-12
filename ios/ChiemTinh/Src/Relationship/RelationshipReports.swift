//  RelationshipReports.swift
//  PORT 1-1 phần TÍNH TOÁN của các báo cáo web sang dữ liệu thuần (không HTML):
//    · `app/utils/reports/logic.py`     (87 dòng)  — get_dominant_houses_sorted, get_dominant_planets_logic
//    · `app/utils/reports/synastry.py`  (240 dòng) — 5 mục của "PHÂN TÍCH CHI TIẾT"
//    · `app/utils/reports/natal.py`     (115 dòng) — báo cáo dùng lại cho màn Composite
//    · `app/utils/reports/components.py`(128 dòng) — bảng Nguyên tố–Tính chất, khối Show Time
//  Repo HEAD 73e2e63.
//
//  NGUYÊN TẮC: GIỮ NGUYÊN HÀNH VI, KỂ CẢ CHỖ TRÔNG NHƯ SAI (`⚠️ GIỮ NGUYÊN`).
//  Web sinh chuỗi HTML; ở đây chỉ sinh SỐ + CHUỖI, phần trình bày để SwiftUI lo.
//
//  Toàn bộ kiểu công khai nằm trong namespace `RelReports` để không đụng tên
//  với file của worker khác.

import Foundation

public enum RelReports {

    // MARK: - Kiểu dữ liệu chung

    /// (số nhà, điểm)
    public struct HouseScore: Equatable, Identifiable {
        public var house: Int
        public var score: Int
        public var id: Int { house }
    }

    /// Khối "LÕI": AC / Sun / Moon + tên cung tiếng Việt.
    public struct CoreSigns: Equatable {
        public var ascSign: String
        public var sunSign: String
        public var moonSign: String
    }

    /// Khối "Xem thông tin chi tiết (Show Time)" — components.py:96-128.
    public struct ShowTimeInfo: Equatable {
        public var dateOfBirthLocal: String
        public var universalTime: String
        public var localSiderealTime: String
        public var houseSystem: String
        public var latLon: String
        public var city: String
        public var country: String
    }

    // MARK: - components.py:96-128  generate_info_html

    /// `address` là chuỗi địa chỉ trong hồ sơ (`profile['loc']['address']`).
    public static func showTimeInfo(chart: Chart, address: String) -> ShowTimeInfo {
        // py:98-100
        let addrParts = address.components(separatedBy: ",")
        // ⚠️ GIỮ NGUYÊN: khi địa chỉ KHÔNG có dấu phẩy (ví dụ "Midpoint Method" của
        // màn Composite), `country` = phần tử cuối = cả chuỗi, và `city` = phần tử
        // đầu = CŨNG cả chuỗi → City và Country hiện GIỐNG HỆT NHAU. Web đang vậy.
        let country = addrParts.count > 0 ? addrParts[addrParts.count - 1].trimmingCharacters(in: .whitespaces) : ""
        let city: String = addrParts.count > 1
            ? addrParts.dropLast().joined(separator: ", ").trimmingCharacters(in: .whitespaces)
            : addrParts[0].trimmingCharacters(in: .whitespaces)

        return ShowTimeInfo(
            dateOfBirthLocal: chart.info.localTime,     // py:115
            universalTime: chart.info.utTime,           // py:116
            localSiderealTime: chart.info.lst,          // py:117
            houseSystem: chart.info.houseSys,           // py:118 (mặc định 'Placidus' nếu rỗng)
            latLon: chart.info.latLon,                  // py:119
            city: city,                                 // py:120
            country: country                            // py:121
        )
    }

    // MARK: - logic.py:76-87  get_dominant_houses_sorted

    /// "Tính điểm nhà trội (>=4), trả về list sorted High->Low".
    public static func dominantHousesSorted(_ chart: Chart) -> [HouseScore] {
        var scores: [Int: Int] = [:]                       // py:78
        for h in 1...12 { scores[h] = 0 }
        let cusps = chart.cusps                            // py:79

        // py:80 — Python duyệt `chart_data["planets"].items()` (thứ tự chèn).
        // Chỉ cộng dồn nên thứ tự KHÔNG ảnh hưởng kết quả.
        for p in chart.planetOrder {
            guard let info = chart.planets[p] else { continue }
            if p == "Asc" { continue }                     // py:81
            guard let pts = AstroConst.planetPoints[p] else { continue }  // py:82
            let h = AstroCore.getHouseOfPlanet(info.lon, cusps)           // py:83
            scores[h, default: 0] += pts                                  // py:84
        }

        // py:85-86 — lọc >= 4, sort giảm dần theo điểm (Python `sort` ỔN ĐỊNH →
        // các nhà cùng điểm giữ thứ tự nhà tăng dần 1..12).
        let dom = (1...12).compactMap { h -> HouseScore? in
            let s = scores[h] ?? 0
            return s >= 4 ? HouseScore(house: h, score: s) : nil
        }
        return SynastryLogic.stableSorted(dom) { $0.score > $1.score }
    }

    // MARK: - reports/synastry.py:6-126 — 5 mục "PHÂN TÍCH CHI TIẾT"

    /// Một dòng của "2. BẢNG TƯƠNG TÁC NHÀ".
    public struct HouseInteractionRow: Equatable, Identifiable {
        public var planet: String
        public var symbol: String
        public var points: Int
        /// Cột "KÍCH HOẠT NHÀ CỦA <A>" — hành tinh của B rơi vào nhà nào của A (py:70).
        public var houseInA: Int
        /// Cột "KÍCH HOẠT NHÀ CỦA <B>" — hành tinh của A rơi vào nhà nào của B (py:67).
        public var houseInB: Int
        public var id: String { planet }
    }

    public struct SynastryReport {
        public var infoA: ShowTimeInfo
        public var infoB: ShowTimeInfo
        // Mục 1
        public var coreA: CoreSigns
        public var coreB: CoreSigns
        public var dominantHousesA: [HouseScore]
        public var dominantHousesB: [HouseScore]
        // Mục 2
        public var rows: [HouseInteractionRow]
        // Mục 3
        public var activatedHousesOfA: [HouseScore]
        public var activatedHousesOfB: [HouseScore]
        // Mục 4
        public var relationshipHouses: [HouseScore]
        // Mục 5
        public var emptyHouses: [Int]
        public var specialEmptyHouses: [Int]
        // Khối THEME
        public var analysis: SynastryAnalysis?
    }

    /// py:14-21 `get_core`
    static func getCore(_ c: Chart) -> CoreSigns {
        // ⚠️ GIỮ NGUYÊN: lấy Asc từ `c["angles"]["Asc"]`, KHÔNG phải `planets["Asc"]`
        // (hai giá trị này bằng nhau ở bản hiện tại).
        let a = c.angles["Asc"] ?? 0
        let s = c.planets["Sun"]?.lon ?? 0
        let m = c.planets["Moon"]?.lon ?? 0
        return CoreSigns(ascSign: AstroCore.getZodiac(a).name,
                         sunSign: AstroCore.getZodiac(s).name,
                         moonSign: AstroCore.getZodiac(m).name)
    }

    /// PORT `generate_synastry_report` — reports/synastry.py:6-126 (phần tính toán).
    /// `addressA/addressB` là `profile['loc']['address']` của 2 hồ sơ.
    public static func synastryReport(cA: Chart, cB: Chart,
                                      addressA: String, addressB: String) -> SynastryReport {

        // ── Mục 1 — py:23-32
        let domA = dominantHousesSorted(cA)
        let domB = dominantHousesSorted(cB)

        // ── Mục 2 — py:60-81
        var sAB: [Int: Int] = [:]        // điểm rót vào NHÀ CỦA B  (py:60)
        var sBA: [Int: Int] = [:]        // điểm rót vào NHÀ CỦA A  (py:61)
        for h in 1...12 { sAB[h] = 0; sBA[h] = 0 }
        var occ: Set<Int> = []           // py:62

        var rows: [HouseInteractionRow] = []
        for p in AstroConst.planetOrder {                       // py:64 — PLANET_ORDER (Sun..Pluto)
            guard let pa = cA.planets[p], let pb = cB.planets[p] else { continue }   // py:65
            let pts = AstroConst.planetPoints[p] ?? 1                                // py:66
            let hB = AstroCore.getHouseOfPlanet(pa.lon, cB.cusps)                    // py:67
            sAB[hB, default: 0] += pts                                               // py:68
            occ.insert(hB)                                                           // py:69
            let hA = AstroCore.getHouseOfPlanet(pb.lon, cA.cusps)                    // py:70
            sBA[hA, default: 0] += pts                                               // py:71
            occ.insert(hA)                                                           // py:72
            let sym = AstroConst.planetSymbols[p] ?? ""                              // py:73

            rows.append(HouseInteractionRow(planet: p, symbol: sym, points: pts,
                                            houseInA: hA, houseInB: hB))             // py:75-79
        }

        // ── Mục 3 — py:84-85
        let actA = SynastryLogic.stableSorted(
            (1...12).compactMap { h -> HouseScore? in
                let s = sBA[h] ?? 0
                return s >= 4 ? HouseScore(house: h, score: s) : nil
            }) { $0.score > $1.score }
        let actB = SynastryLogic.stableSorted(
            (1...12).compactMap { h -> HouseScore? in
                let s = sAB[h] ?? 0
                return s >= 4 ? HouseScore(house: h, score: s) : nil
            }) { $0.score > $1.score }

        // ── Mục 4 — py:97-110
        var totalScores: [HouseScore] = []
        for h in 1...12 {                                       // py:98
            let s = (sAB[h] ?? 0) + (sBA[h] ?? 0)               // py:99
            if s >= 4 { totalScores.append(HouseScore(house: h, score: s)) }   // py:100
        }
        totalScores = SynastryLogic.stableSorted(totalScores) { $0.score > $1.score }  // py:101

        var finalHouses: [HouseScore] = []                      // py:102
        if !totalScores.isEmpty {                               // py:103
            let limitIdx = min(3, totalScores.count)            // py:104
            finalHouses = Array(totalScores[0..<limitIdx])      // py:105
            if totalScores.count > 3 {                          // py:106
                let thresholdScore = totalScores[2].score       // py:107
                for i in 3..<totalScores.count {                // py:108
                    if totalScores[i].score == thresholdScore {
                        finalHouses.append(totalScores[i])      // py:109
                    } else if totalScores[i].score < thresholdScore {
                        break                                   // py:110
                    }
                }
            }
        }

        // ── Mục 5 — py:122-124
        let empty = (1...12).filter { !occ.contains($0) }                                 // py:122
        let indDom = Set(domA.map { $0.house }).union(Set(domB.map { $0.house }))         // py:123
        let spEmpty = empty.filter { indDom.contains($0) }.sorted()                       // py:124

        // ── Khối THEME — py:129
        let analysis = SynastryLogic.analyzeSynastryGrid(cA, cB)

        return SynastryReport(
            infoA: showTimeInfo(chart: cA, address: addressA),
            infoB: showTimeInfo(chart: cB, address: addressB),
            coreA: getCore(cA), coreB: getCore(cB),
            dominantHousesA: domA, dominantHousesB: domB,
            rows: rows,
            activatedHousesOfA: actA, activatedHousesOfB: actB,
            relationshipHouses: finalHouses,
            emptyHouses: empty, specialEmptyHouses: spEmpty,
            analysis: analysis)
    }

    // MARK: - logic.py:3-73  get_dominant_planets_logic

    public struct DominantPlanetAspect: Equatable {
        public var target: String
        public var orbRound: Int
        public var type: String
    }

    public struct DominantPlanet: Equatable, Identifiable {
        public var name: String
        public var count: Int
        public var aspects: [DominantPlanetAspect]
        public var totalOrb: Int
        public var reason: String
        public var id: String { name }
    }

    /// "Tìm hành tinh trội (Logic phễu 4 bước: Số lượng -> Chặt -> Cá nhân -> Tổng Orb)".
    public static func dominantPlanetsLogic(_ chart: Chart) -> [DominantPlanet] {
        let candidates = AstroConst.corePlanets            // py:5
        let pPos = chart.planets                           // py:6
        let coreTargets = AstroConst.corePlanets           // py:7

        var order: [String] = []                           // thứ tự chèn của `planet_stats`
        var counts: [String: Int] = [:]
        var aspectsMap: [String: [DominantPlanetAspect]] = [:]

        for p in candidates {                              // py:10
            guard let pp = pPos[p] else { continue }       // py:11
            var count = 0
            var asps: [DominantPlanetAspect] = []
            for target in coreTargets {                    // py:13
                guard let tp = pPos[target] else { continue }   // py:14
                if p == target { continue }                     // py:15
                guard let asp = AstroCore.checkAspect(pp.lon, tp.lon) else { continue }  // py:16-17
                if asp.type == "Minor" { continue }             // py:18-19
                count += 1                                      // py:21
                asps.append(DominantPlanetAspect(target: target, orbRound: asp.orbRound, type: asp.type))  // py:22
            }
            order.append(p); counts[p] = count; aspectsMap[p] = asps   // py:23
        }

        if order.isEmpty { return [] }                     // py:25

        func orbSum(_ name: String) -> Int {               // py:27-28
            (aspectsMap[name] ?? []).reduce(0) { $0 + $1.orbRound }
        }
        func entry(_ name: String, _ reason: String) -> DominantPlanet {
            DominantPlanet(name: name, count: counts[name] ?? 0,
                           aspects: aspectsMap[name] ?? [], totalOrb: orbSum(name), reason: reason)
        }

        // Bước 1: Max Count — py:31-36
        let maxCount = order.map { counts[$0] ?? 0 }.max()!
        let group1 = order.filter { (counts[$0] ?? 0) == maxCount }
        if group1.count == 1 { return [entry(group1[0], "Số lượng góc nhiều nhất")] }

        // Bước 2: Tightest Orb — py:39-49
        var pMinOrbs: [String: Int] = [:]
        for p in group1 {
            let asps = aspectsMap[p] ?? []
            pMinOrbs[p] = asps.isEmpty ? 999 : asps.map { $0.orbRound }.min()!   // py:42
        }
        let globalMinOrb = group1.map { pMinOrbs[$0]! }.min()!                   // py:44
        let group2 = group1.filter { pMinOrbs[$0]! == globalMinOrb }             // py:45
        if group2.count == 1 { return [entry(group2[0], "Góc chặt nhất nhỏ hơn")] }

        // Bước 3: Personal Planet Priority — py:52-64
        let personalPlanets = Set(AstroConst.personalPlanets)
        var hasPersonal: [String: Bool] = [:]
        for p in group2 {
            let tightest = (aspectsMap[p] ?? []).filter { $0.orbRound == globalMinOrb }  // py:55
            var flag = false
            for a in tightest where personalPlanets.contains(p) || personalPlanets.contains(a.target) {
                flag = true; break                                                       // py:58-60
            }
            hasPersonal[p] = flag
        }
        let group3 = group2.filter { hasPersonal[$0] == true }                            // py:63
        // py:64 — ⚠️ GIỮ NGUYÊN: chỉ thu hẹp khi group_3 KHÁC RỖNG và NHỎ HƠN group_2.
        let current = (group3.count > 0 && group3.count < group2.count) ? group3 : group2

        // Bước 4: Total Orb (Ascending) — py:67-73
        var finalList = current.map { p -> DominantPlanet in
            let total = orbSum(p)
            return entry(p, "Tổng Orb: \(total)")
        }
        finalList = SynastryLogic.stableSorted(finalList) { $0.totalOrb < $1.totalOrb }   // py:72
        return finalList
    }

    // MARK: - components.py:4-93  generate_element_matrix_html (phần tính toán)

    public struct ElementMatrix: Equatable {
        /// 4 hàng (Fire/Earth/Air/Water) × 3 cột (Cardinal/Fixed/Mutable)
        public var scores: [[Int]]
        /// Ký hiệu hành tinh trong từng ô, theo đúng thứ tự chèn của Python.
        public var symbols: [[[String]]]
        public var rowTotals: [Int]
        public var colTotals: [Int]
        public static let rowNames = ["Fire", "Earth", "Air", "Water"]
        public static let colNames = ["Cardinal", "Fixed", "Mutable"]
    }

    public static func elementMatrix(_ chart: Chart) -> ElementMatrix {
        var scores = [[Int]](repeating: [Int](repeating: 0, count: 3), count: 4)     // py:16
        var symbols = [[[String]]](repeating: [[String]](repeating: [], count: 3), count: 4)  // py:17

        // py:19 — `list(PLANET_POINTS.keys()) + ["True Node","Chiron","Vertex","MC"]`.
        // Thứ tự khoá của dict PLANET_POINTS trong const.py:38-41 là:
        // Asc, Sun, Moon, Mercury, Venus, Mars, Jupiter, Saturn, Uranus, Neptune, Pluto.
        let displayObjects = ["Asc", "Sun", "Moon", "Mercury", "Venus", "Mars",
                              "Jupiter", "Saturn", "Uranus", "Neptune", "Pluto",
                              "True Node", "Chiron", "Vertex", "MC"]

        for p in displayObjects {
            guard let info = chart.planets[p] else { continue }          // py:22
            let zIdx = AstroCore.getZodiac(info.lon).idx                 // py:24
            guard let rc = AstroConst.zodiacMatrix[zIdx] else { continue }  // py:25
            if let pts = AstroConst.planetPoints[p] {                    // py:26-27
                scores[rc.row][rc.col] += pts
            }
            let sym = AstroConst.planetSymbols[p] ?? p                   // py:28
            symbols[rc.row][rc.col].append(sym)                          // py:29
        }

        var colTotals = [Int](repeating: 0, count: 3)                    // py:32
        var rowTotals = [Int](repeating: 0, count: 4)
        for r in 0..<4 {
            for c in 0..<3 {
                rowTotals[r] += scores[r][c]                             // py:69
                colTotals[c] += scores[r][c]                             // py:70
            }
        }
        return ElementMatrix(scores: scores, symbols: symbols,
                             rowTotals: rowTotals, colTotals: colTotals)
    }

    // MARK: - reports/natal.py:7-115 (dùng cho màn Composite)

    public struct PlanetRow: Equatable, Identifiable {
        public var planet: String
        public var planetSymbol: String
        public var zodiacSymbol: String
        public var degreeText: String     // "12°34'"
        public var house: Int
        public var id: String { planet }
    }

    public struct InnerAspect: Equatable, Identifiable {
        public var p1: String
        public var p2: String
        public var nameVN: String
        public var orbRound: Int
        public var id: String { p1 + "-" + p2 }
    }

    public struct NatalReport {
        public var info: ShowTimeInfo
        public var planetRows: [PlanetRow]
        public var core: CoreSigns
        public var elements: ElementMatrix
        public var dominantHouses: [HouseScore]
        public var dominantPlanets: [DominantPlanet]
        public var tightestInnerAspects: [InnerAspect]
    }

    /// PORT `generate_natal_report` — reports/natal.py:7-115 (phần tính toán).
    /// Màn Composite của web gọi đúng hàm này trên dữ liệu composite (charts.py:170-171).
    public static func natalReport(_ data: Chart, address: String) -> NatalReport {
        let cusps = data.cusps                              // py:18
        // py:19-20
        let disp = ["Asc", "Sun", "Moon", "Mercury", "Venus", "Mars", "Jupiter",
                    "Saturn", "Uranus", "Neptune", "Pluto", "True Node", "Chiron", "Vertex"]

        var planetRows: [PlanetRow] = []
        for p in disp {
            guard let info = data.planets[p] else { continue }    // py:23
            let z = AstroCore.getZodiac(info.lon)                 // py:25-26
            let zSym = AstroConst.zodiacSymbols[z.idx]            // py:27
            // py:28 — ⚠️ GIỮ NGUYÊN: Asc luôn bị GÁN CỨNG là nhà 1, không tính lại.
            let h = (p != "Asc") ? AstroCore.getHouseOfPlanet(info.lon, cusps) : 1
            // py:29 — `int(z_deg)°int((z_deg % 1) * 60)'` (CẮT, không làm tròn)
            let dStr = "\(Int(z.degInSign))°\(Int(pmod(z.degInSign, 1) * 60))'"
            let pSym = AstroConst.planetSymbols[p] ?? p           // py:30
            planetRows.append(PlanetRow(planet: p, planetSymbol: pSym, zodiacSymbol: zSym,
                                        degreeText: dStr, house: h))
        }

        // py:86-101 — GÓC INNER CHẶT NHẤT
        let core = AstroConst.corePlanets                    // py:87
        let personal = Set(AstroConst.personalPlanets)       // py:88
        var tempAsps: [InnerAspect] = []                     // py:89
        var minOrbInner = 999                                // py:90
        for i in 0..<core.count {                            // py:91
            for j in (i + 1)..<core.count {                  // py:92
                let p1 = core[i], p2 = core[j]               // py:93
                if !personal.contains(p1) && !personal.contains(p2) { continue }   // py:94
                guard let a = data.planets[p1], let b = data.planets[p2] else { continue }  // py:95
                guard let asp = AstroCore.checkAspect(a.lon, b.lon) else { continue }       // py:96-97
                if asp.type == "Minor" { continue }                                        // py:98
                tempAsps.append(InnerAspect(p1: p1, p2: p2, nameVN: asp.nameVN, orbRound: asp.orbRound))  // py:99
                if asp.orbRound < minOrbInner { minOrbInner = asp.orbRound }               // py:100
            }
        }
        let finalInners = tempAsps.filter { $0.orbRound == minOrbInner }                   // py:101

        return NatalReport(
            info: showTimeInfo(chart: data, address: address),
            planetRows: planetRows,
            core: getCore(data),                            // py:39-56
            elements: elementMatrix(data),                  // py:58
            dominantHouses: dominantHousesSorted(data),     // py:60
            // py:70-71 — gọi rồi sort lại theo total_orb (đã ổn định sẵn trong hàm)
            dominantPlanets: SynastryLogic.stableSorted(dominantPlanetsLogic(data)) { $0.totalOrb < $1.totalOrb },
            tightestInnerAspects: finalInners)
    }
}
