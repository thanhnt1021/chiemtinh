//  SynastryLogic.swift
//  PORT 1-1 từ `app/astro00_lib/synastry_logic.py` (264 dòng) — repo
//  `git@github.com:hentaiikidd/chiemtinh.git` HEAD 73e2e63bbc23c3dad856aa523b264481eb3b7c93.
//
//  NGUYÊN TẮC (luật univ3): GIỮ NGUYÊN HÀNH VI, KỂ CẢ CHỖ TRÔNG NHƯ SAI.
//  Mỗi khối đều ghi số dòng của BẢN PYTHON GỐC. Mọi chỗ "trông như sai" mà vẫn
//  giữ nguyên đều có chú thích `⚠️ GIỮ NGUYÊN` kèm lý do.
//
//  KHÔNG tự tính chart ở đây — dùng `AstroCore.checkAspect` của `Src/Core/AstroCore.swift`.

import Foundation

// MARK: - Kiểu dữ liệu

/// Bản Swift của dict `stats` trong `calculate_score` (synastry_logic.py:22-29).
public struct SynastryScore: Equatable {
    public var count: Int          // "count"
    public var tightCount: Int     // "tight_count"      — orb < 1.0
    public var looseCount: Int     // "loose_count"      — 6.5 < orb <= 10.0
    public var totalOrbRound: Int  // "total_orb_round"  — CỘNG DỒN int(orb) (CẮT, không làm tròn)
    public var totalOrbRaw: Double // "total_orb_raw"
    public var isPersonal: Bool    // "is_personal"

    public init(count: Int = 0, tightCount: Int = 0, looseCount: Int = 0,
                totalOrbRound: Int = 0, totalOrbRaw: Double = 0, isPersonal: Bool = false) {
        self.count = count; self.tightCount = tightCount; self.looseCount = looseCount
        self.totalOrbRound = totalOrbRound; self.totalOrbRaw = totalOrbRaw
        self.isPersonal = isPersonal
    }
}

/// Bản Swift của `{"name": ..., "owner": "A"|"B"}` (synastry_logic.py:184-186).
public struct AccompanyingPlanet: Equatable {
    public var name: String
    public var owner: String   // "A" hoặc "B"
}

/// Một cặp theme phụ (mutual / double-whammy aspect) — `pair_key` của Python.
public struct SubThemePair: Equatable {
    public var first: String
    public var second: String
}

/// Bản Swift của dict trả về ở synastry_logic.py:257-264.
///
/// Python trả về `dict`; ở đây tách thêm `orderA/orderB` để GIỮ ĐÚNG THỨ TỰ CHÈN
/// của dict Python — thứ tự đó ẢNH HƯỞNG KẾT QUẢ ở tầng 5.2 (`min()` của Python
/// trả về phần tử ĐẦU TIÊN trong các phần tử nhỏ nhất).
public struct SynastryAnalysis {
    public var scoresA: [String: SynastryScore]
    public var scoresB: [String: SynastryScore]
    /// Thứ tự chèn của `scores_A` (= `list_A` — lọc theo OBJS_IN_ORDER).
    public var orderA: [String]
    /// Thứ tự chèn của `scores_B`.
    public var orderB: [String]
    public var dominantA: String
    public var dominantB: String
    public var accompanying: AccompanyingPlanet?
    public var subThemes: [SubThemePair]

    /// Lý do thắng của A/B (Python có trả `reason_A/reason_B` trong biến cục bộ
    /// nhưng KHÔNG đưa vào dict trả về — synastry_logic.py:130-131).
    /// Giữ lại ở đây để hiển thị/gỡ lỗi; KHÔNG ảnh hưởng parity vì là trường thêm.
    public var reasonA: String
    public var reasonB: String
}

// MARK: - SynastryLogic

public enum SynastryLogic {

    /// synastry_logic.py:13-14 — "chỉ tính tới cột/hàng AC".
    public static let objsInOrder: [String] = [
        "Sun", "Moon", "Mercury", "Venus", "Mars", "Jupiter", "Saturn",
        "Uranus", "Neptune", "Pluto", "Asc"
    ]

    /// synastry_logic.py:196 — thứ tự chuẩn để sắp xếp theme phụ.
    public static let sortOrder: [String] = [
        "Sun", "Moon", "Mercury", "Venus", "Mars", "Jupiter", "Saturn",
        "Uranus", "Neptune", "Pluto"
    ]

    /// synastry_logic.py:202
    static let specialPoints: Set<String> = ["True Node", "Chiron", "Vertex"]

    /// `const.py:13` — PERSONAL_PLANETS_SET
    static let personalPlanetsSet: Set<String> = Set(AstroConst.personalPlanets)

    // ═══════════════════════════════════════════════════════════════════
    // calculate_score  — synastry_logic.py:21-58
    // ═══════════════════════════════════════════════════════════════════
    static func calculateScore(pName: String, pLon: Double,
                               targetList: [String], targetChart: Chart) -> SynastryScore {
        // py:22-29
        var stats = SynastryScore(isPersonal: personalPlanetsSet.contains(pName))

        for targetName in targetList {
            // py:32 — `target_list` đã được lọc sẵn nên nhánh này không bao giờ chạy,
            // ⚠️ GIỮ NGUYÊN vì bản gốc có: đổi thứ tự lọc có thể lệch khi chart thiếu hành tinh.
            guard let target = targetChart.planets[targetName] else { continue }
            let targetLon = target.lon

            // py:35
            guard let asp = AstroCore.checkAspect(pLon, targetLon) else { continue }

            // py:37-39 — bỏ góc Minor (30°, 150°) khỏi bộ đếm
            if asp.type == "Minor" { continue }

            let orb = asp.orb                          // py:41
            // py:42 — ⚠️ GIỮ NGUYÊN: `int(orb)` của Python là CẮT PHẦN THẬP PHÂN,
            // KHÔNG phải `round_orb()`. orb luôn >= 0 nên Int(orb) của Swift khớp y hệt.
            let orbRound = Int(orb)

            // py:44-45 — ⚠️ GIỮ NGUYÊN: nhánh CHẾT. `check_aspect` (core.py:66-67) đã
            // trả None khi raw_orb >= 10.0, nên `orb >= 10.0` không bao giờ đúng ở đây.
            if orb >= 10.0 { continue }

            stats.count += 1                           // py:47
            stats.totalOrbRound += orbRound            // py:48
            stats.totalOrbRaw += orb                   // py:49

            if orb < 1.0 { stats.tightCount += 1 }      // py:51-52

            // py:54-56 — ⚠️ GIỮ NGUYÊN: vế `<= 10.0` là ĐIỀU KIỆN CHẾT (orb < 10 do py:45).
            if orb > 6.5 && orb <= 10.0 { stats.looseCount += 1 }
        }

        return stats
    }

    // ═══════════════════════════════════════════════════════════════════
    // solve_tie_breaker — PHỄU LỌC 6 TẦNG — synastry_logic.py:73-122
    //
    // Tham số `candidates` là MẢNG CÓ THỨ TỰ, thay cho `dict` của Python:
    // `list(candidates_dict.keys())` (py:76) phụ thuộc THỨ TỰ CHÈN, và thứ tự đó
    // quyết định kết quả ở tầng 5.2 (`min` của Python lấy phần tử đầu tiên).
    // ═══════════════════════════════════════════════════════════════════
    static func solveTieBreaker(_ candidates: [(name: String, score: SynastryScore)],
                                checkPersonalAtLevel4: Bool = true) -> (winner: String?, reason: String) {
        // py:74
        if candidates.isEmpty { return (nil, "No candidates") }

        let currentCandidates = candidates                                  // py:76

        // ── Level 1: Max Count — py:79-81
        let maxCount = currentCandidates.map { $0.score.count }.max()!
        let group1 = currentCandidates.filter { $0.score.count == maxCount }
        if group1.count == 1 { return (group1[0].name, "Max Count") }

        // ── Level 2: Max Tight Count (<1) — py:84-86
        let maxTight = group1.map { $0.score.tightCount }.max()!
        let group2 = group1.filter { $0.score.tightCount == maxTight }
        if group2.count == 1 { return (group2[0].name, "Max Tight Count") }

        // ── Level 3: Min Loose Count (>6.5) — py:89-91
        let minLoose = group2.map { $0.score.looseCount }.min()!
        let group3 = group2.filter { $0.score.looseCount == minLoose }
        if group3.count == 1 { return (group3[0].name, "Min Loose Count") }

        // ── Level 4: Personal Planet — py:94-113
        var group4 = group3                                                 // py:94 (mặc định = TH3)

        if checkPersonalAtLevel4 {                                          // py:96
            let personalInGroup = group3.filter { $0.score.isPersonal }     // py:97

            // TH1: đúng 1 hành tinh cá nhân -> chốt luôn — py:99-102
            if personalInGroup.count == 1 {
                return (personalInGroup[0].name, "Unique Personal Planet")
            }
            // TH2: >1 hành tinh cá nhân -> thu hẹp rồi đi tiếp Level 5 — py:104-108
            if personalInGroup.count > 1 {
                group4 = personalInGroup
            }
            // TH3: 0 hành tinh cá nhân -> giữ nguyên group_3 đi tiếp Level 5 — py:110-113
        }

        // ── Level 5: Min Total Orb Round — py:116-118
        let minOrbRound = group4.map { $0.score.totalOrbRound }.min()!
        let group5 = group4.filter { $0.score.totalOrbRound == minOrbRound }
        if group5.count == 1 { return (group5[0].name, "Min Total Orb Round") }

        // ── Level 5.2: Min Total Orb Raw — py:121-122
        // ⚠️ GIỮ NGUYÊN: `min(iterable, key=...)` của Python trả về phần tử ĐẦU TIÊN
        // trong số các phần tử nhỏ nhất (so sánh STRICT `<`). Swift `min(by:)` cũng vậy
        // nhưng viết tay cho rõ ràng, khỏi phụ thuộc chi tiết cài đặt thư viện.
        var best = group5[0]
        for c in group5.dropFirst() where c.score.totalOrbRaw < best.score.totalOrbRaw {
            best = c
        }
        return (best.name, "Min Total Orb Raw")
    }

    // ═══════════════════════════════════════════════════════════════════
    // analyze_synastry_grid — synastry_logic.py:5-264
    //
    // Trả về nil ở đúng những chỗ Python NÉM LỖI (KeyError / TypeError) — khi đó
    // route Flask bắt exception và trang không hiện gì (charts.py:129-131).
    // ═══════════════════════════════════════════════════════════════════
    public static func analyzeSynastryGrid(_ cA: Chart, _ cB: Chart) -> SynastryAnalysis? {

        // py:17-18 — lọc hành tinh có trong chart, GIỮ thứ tự OBJS_IN_ORDER
        let listA = objsInOrder.filter { cA.planets[$0] != nil }
        let listB = objsInOrder.filter { cB.planets[$0] != nil }

        // py:61-63 — Stats cho A
        var orderA: [String] = []
        var scoresA: [String: SynastryScore] = [:]
        for p in listA {
            scoresA[p] = calculateScore(pName: p, pLon: cA.planets[p]!.lon,
                                        targetList: listB, targetChart: cB)
            orderA.append(p)
        }

        // py:66-68 — Stats cho B
        var orderB: [String] = []
        var scoresB: [String: SynastryScore] = [:]
        for p in listB {
            scoresB[p] = calculateScore(pName: p, pLon: cB.planets[p]!.lon,
                                        targetList: listA, targetChart: cA)
            orderB.append(p)
        }

        // ═══ QUY TẮC CHECK TRỘI SỐ 1 (GLOBAL) — py:127-131 ═══
        // dict comprehension của Python GIỮ thứ tự chèn của `scores_A`.
        let candidatesA = orderA.filter { $0 != "Asc" }.map { (name: $0, score: scoresA[$0]!) }
        let candidatesB = orderB.filter { $0 != "Asc" }.map { (name: $0, score: scoresB[$0]!) }

        let (winnerAOpt, reasonA) = solveTieBreaker(candidatesA)
        let (winnerBOpt, reasonB) = solveTieBreaker(candidatesB)

        // ⚠️ GIỮ NGUYÊN (hành vi lỗi): nếu không có ứng viên nào, Python trả winner=None
        // rồi py:140 `scores_A[None]` -> KeyError -> route bắt exception -> trang trắng.
        // Swift: trả nil để tầng trên xử lý (không cho phép crash app).
        guard let winnerA = winnerAOpt, let winnerB = winnerBOpt else { return nil }
        guard let scoreWinA = scoresA[winnerA], let scoreWinB = scoresB[winnerB] else { return nil }

        // ═══ LOGIC THEME & KÈM (QUY TẮC 2, 3, 4) — py:133-186 ═══
        // ⚠️ GIỮ NGUYÊN: py:136-137 gán final_theme = winner NGAY TỪ ĐẦU và
        // KHÔNG khối nào bên dưới ghi đè. Nghĩa là QUY TẮC 3 (winner_A1/winner_B1)
        // KHÔNG hề đổi hành tinh trội hiển thị — nó chỉ dùng để chọn hành tinh "kèm".
        // Trông như thiếu bước nhưng web đang chạy đúng như vậy → giữ y hệt.
        let finalThemeA = winnerA                                            // py:136
        let finalThemeB = winnerB                                            // py:137
        var accompanyingPlanet: AccompanyingPlanet? = nil                    // py:138

        let isAPersonal = scoreWinA.isPersonal                               // py:140
        let isBPersonal = scoreWinB.isPersonal                               // py:141

        if isAPersonal || isBPersonal {
            // py:143-144 — QUY TẮC 2: `pass`. ⚠️ GIỮ NGUYÊN: KHÔNG làm gì cả,
            // không có hành tinh kèm khi ít nhất một bên trội là hành tinh cá nhân.
        } else {
            // QUY TẮC 3: cả 2 đều KHÔNG phải Personal — py:146-151
            // dict comprehension py:147-148 chạy trên `scores_A` (CÓ CẢ 'Asc'),
            // nhưng 'Asc' không phải personal nên bị loại tự nhiên.
            let subsetA = orderA.filter { scoresA[$0]!.isPersonal }.map { (name: $0, score: scoresA[$0]!) }
            let subsetB = orderB.filter { scoresB[$0]!.isPersonal }.map { (name: $0, score: scoresB[$0]!) }

            let (winnerA1Opt, _) = solveTieBreaker(subsetA, checkPersonalAtLevel4: false)
            let (winnerB1Opt, _) = solveTieBreaker(subsetB, checkPersonalAtLevel4: false)

            // ⚠️ GIỮ NGUYÊN (hành vi lỗi): py:154-155 `subset_A[winner_A1]` sẽ KeyError
            // nếu chart không có hành tinh cá nhân nào. Swift trả nil thay vì crash.
            guard let winnerA1 = winnerA1Opt, let winnerB1 = winnerB1Opt,
                  let statA1 = scoresA[winnerA1], let statB1 = scoresB[winnerB1] else { return nil }

            // QUY TẮC 4: tìm hành tinh Kèm — py:153-186
            var kemWinner: String
            if statA1.count > statB1.count {                       // py:158-159
                kemWinner = "A"
            } else if statB1.count > statA1.count {                // py:160-161
                kemWinner = "B"
            } else {
                if statA1.tightCount > statB1.tightCount {         // py:163-164
                    kemWinner = "A"
                } else if statB1.tightCount > statA1.tightCount {  // py:165-166
                    kemWinner = "B"
                } else {
                    if statA1.looseCount < statB1.looseCount {         // py:168-169
                        kemWinner = "A"
                    } else if statB1.looseCount < statA1.looseCount {  // py:170-171
                        kemWinner = "B"
                    } else {
                        if statA1.totalOrbRound < statB1.totalOrbRound {         // py:173-174
                            kemWinner = "A"
                        } else if statB1.totalOrbRound < statA1.totalOrbRound {  // py:175-176
                            kemWinner = "B"
                        } else {
                            // py:178-181 — ⚠️ GIỮ NGUYÊN: dấu `<=` ở đây, HOÀ THÌ A THẮNG.
                            // Không đối xứng với các tầng trên (đều dùng `<`/`>` chặt).
                            kemWinner = (statA1.totalOrbRaw <= statB1.totalOrbRaw) ? "A" : "B"
                        }
                    }
                }
            }

            // py:183-186
            if kemWinner == "A" {
                accompanyingPlanet = AccompanyingPlanet(name: winnerA1, owner: "A")
            } else {
                accompanyingPlanet = AccompanyingPlanet(name: winnerB1, owner: "B")
            }
        }

        // ═══ TÌM THEME PHỤ (MUTUAL ASPECTS) — py:188-255 ═══
        var subThemes: [SubThemePair] = []                                   // py:192
        var foundPairs: Set<String> = []                                     // py:193

        // py:199 — ⚠️ GIỮ NGUYÊN: `check_list = SORT_ORDER` KHÔNG có 'Asc',
        // dù bảng lưới (grid) vẫn hiển thị cột/hàng Asc. Theme phụ bỏ qua Asc.
        let checkList = sortOrder

        for i in 0..<checkList.count {
            for j in 0..<checkList.count {
                let pX = checkList[i]                                        // py:205
                let pY = checkList[j]                                        // py:206

                if pX == pY { continue }                                     // py:210

                // py:214-220 — chuẩn hoá cặp theo SORT_ORDER
                let idxX = sortOrder.firstIndex(of: pX)!
                let idxY = sortOrder.firstIndex(of: pY)!
                let pairKey: SubThemePair = (idxX < idxY)
                    ? SubThemePair(first: pX, second: pY)
                    : SubThemePair(first: pY, second: pX)
                let pairID = pairKey.first + "|" + pairKey.second

                if foundPairs.contains(pairID) { continue }                  // py:222

                // py:224-228 — ít nhất 1 trong 2 phải là hành tinh cá nhân
                let isXPersonal = personalPlanetsSet.contains(pX)
                let isYPersonal = personalPlanetsSet.contains(pY)
                if !(isXPersonal || isYPersonal) { continue }

                // py:230-231
                guard let aX = cA.planets[pX], let bY = cB.planets[pY] else { continue }
                guard let aY = cA.planets[pY], let bX = cB.planets[pX] else { continue }

                let aspect1 = AstroCore.checkAspect(aX.lon, bY.lon)          // py:233
                let aspect2 = AstroCore.checkAspect(aY.lon, bX.lon)          // py:234

                if let a1 = aspect1, let a2 = aspect2 {                      // py:236
                    // py:237-240 — loại góc Minor (grid đang ẩn góc Minor)
                    if a1.type == "Minor" || a2.type == "Minor" { continue }

                    // py:242-247 — ⚠️ GIỮ NGUYÊN: `is_sp1` và `is_sp2` là HAI BIỂU THỨC
                    // GIỐNG HỆT NHAU (`(pX in SP) or (pY in SP)` viết đảo thứ tự).
                    // Hơn nữa `check_list` không chứa điểm đặc biệt nào nên cả hai
                    // luôn = false → nhánh chết. Vẫn port đủ để khớp 1-1.
                    let isSP1 = specialPoints.contains(pX) || specialPoints.contains(pY)
                    if isSP1 && a1.orb > 3.0 { continue }

                    let isSP2 = specialPoints.contains(pY) || specialPoints.contains(pX)
                    if isSP2 && a2.orb > 3.0 { continue }

                    subThemes.append(pairKey)                                // py:250
                    foundPairs.insert(pairID)                                // py:251
                }
            }
        }

        // py:253-255 — sắp xếp theo (index X, index Y)
        // `list.sort()` của Python là ỔN ĐỊNH; dùng sort ổn định thủ công cho chắc.
        subThemes = stableSorted(subThemes) { lhs, rhs in
            let lx = sortOrder.firstIndex(of: lhs.first)!, ly = sortOrder.firstIndex(of: lhs.second)!
            let rx = sortOrder.firstIndex(of: rhs.first)!, ry = sortOrder.firstIndex(of: rhs.second)!
            if lx != rx { return lx < rx }
            return ly < ry
        }

        // py:257-264
        return SynastryAnalysis(scoresA: scoresA, scoresB: scoresB,
                                orderA: orderA, orderB: orderB,
                                dominantA: finalThemeA, dominantB: finalThemeB,
                                accompanying: accompanyingPlanet,
                                subThemes: subThemes,
                                reasonA: reasonA, reasonB: reasonB)
    }

    /// Sắp xếp ỔN ĐỊNH (Swift `sort` KHÔNG bảo đảm ổn định, Python `list.sort` thì CÓ).
    static func stableSorted<T>(_ arr: [T], by less: (T, T) -> Bool) -> [T] {
        return arr.enumerated()
            .sorted { a, b in
                if less(a.element, b.element) { return true }
                if less(b.element, a.element) { return false }
                return a.offset < b.offset
            }
            .map { $0.element }
    }
}
