//  TransitTimeline.swift
//  Port phần CHUẨN BỊ DỮ LIỆU của `create_detailed_timeline_image`
//  (`app/utils/drawing/timeline.py:36-198`) sang Swift.
//  Phần VẼ nằm ở `TimelineChartView.swift` (SwiftUI Canvas, thay matplotlib).
//
//  ĐÂY LÀ PHẦN NẶNG NHẤT CỦA CẢ ỨNG DỤNG. Web đã phải warm-up engine + bọc
//  try/except chống sập + báo "Hệ thống đang quá tải" (`app/routes/transits.py:165, 231-234`).
//  Bản iOS: chạy nền, báo tiến trình, huỷ được, có bộ nhớ đệm — xem `TransitEngine`.
//
//  Hai mẹo tối ưu của web ĐƯỢC GIỮ NGUYÊN:
//    A. `transit_house_cache`  — quét nhà 1 lần cho 5 hành tinh ngoài (timeline.py:75-78).
//    B. `aspect_memo`          — nhớ theo khoá "tP_nP_asp" (timeline.py:82-89).

import Foundation

public struct TimelinePeriod: Hashable, Sendable {
    public enum Kind: String, Sendable { case entry, aspect }
    public var start: CivilDateTime
    public var end: CivilDateTime
    public var isClampedStart: Bool
    public var isClampedEnd: Bool
    /// Mốc góc chính xác nằm TRONG khoảng xem.
    public var exacts: [CivilDateTime]
    public var hasEarlyE: Bool
    public var hasLateE: Bool
    public var kind: Kind
}

public struct TimelineRow: Identifiable, Hashable, Sendable {
    public enum Kind: String, Sendable { case separator, houseEntry, aspect }
    public let id = UUID()
    public var kind: Kind
    /// Với `separator` là "NHÀ 7"; với 2 loại còn lại là nhãn ký hiệu, vd "♄□☉".
    public var label: String
    public var periods: [TimelinePeriod]
}

public struct TimelineData: Sendable {
    public var rows: [TimelineRow]
    public var start: CivilDateTime
    public var end: CivilDateTime
    public var totalDays: Int
    public var notice: EphemerisClampNotice

    public var isEmpty: Bool { rows.allSatisfy { $0.kind == .separator } }

    /// Toạ độ 0…1 trên trục thời gian — `get_x` của web (timeline.py:41-46).
    public func x(_ d: CivilDateTime) -> Double {
        let days = (d.epochMicroseconds - start.epochMicroseconds) / (86_400 * 1_000_000)
        return Double(days) / Double(max(1, totalDays))
    }
}

public enum TransitTimelineBuilder {

    /// `timeline.py:50` — thứ tự này quyết định thứ tự dòng, giữ nguyên.
    static let outerPlanets = ["Pluto", "Neptune", "Uranus", "Saturn", "Jupiter"]
    /// `timeline.py:51`
    static let corePlanets = AstroConst.corePlanets

    /// Ước lượng số "đơn vị công việc" để chạy thanh tiến trình.
    /// = 5 hành tinh quét nhà + (số điểm natal duy nhất × 5 hành tinh × 5 góc).
    public static func estimatedUnits(houseList: [Int], natal: Chart) -> Int {
        var targets = Set<String>()
        for h in houseList {
            if let p = AstroCore.getNatalPlanetNearCusp(chart: natal, houseNum: h),
               corePlanets.contains(p) { targets.insert(p) }
            if let r = AstroCore.getHouseRulerPlanet(chart: natal, houseNum: h),
               corePlanets.contains(r) { targets.insert(r) }
        }
        return outerPlanets.count + targets.count * outerPlanets.count * AstroConst.majorAspects.count
    }

    /// Dựng dữ liệu timeline.
    /// - Parameters:
    ///   - onProgress: gọi sau mỗi đơn vị công việc (đã hoàn thành, tổng).
    ///   - isCancelled: trả `true` thì dừng và ném `CancellationError`.
    public static func build(natal: Chart,
                             start: CivilDateTime,
                             end: CivilDateTime,
                             houseList: [Int],
                             onProgress: ((Int, Int) -> Void)? = nil,
                             isCancelled: () -> Bool = { false }) throws -> TimelineData {

        let totalUnits = max(1, estimatedUnits(houseList: houseList, natal: natal))
        var done = 0
        func tick() throws {
            done += 1
            onProgress?(done, totalUnits)
            if isCancelled() { throw CancellationError() }
        }

        var totalDays = (end.epochMicroseconds - start.epochMicroseconds) / (86_400 * 1_000_000)
        if totalDays <= 0 { totalDays = 1 }

        // Vùng đệm mốc E — timeline.py:56-61
        let limitEarlyE = start.plusDays(-10)
        let limitLateE  = end.plusDays(10)
        let limitLateEStr = limitLateE.dmy
        let scanStartStr = start.plusDays(-30).dmy      // timeline.py:92

        var notice = EphemerisClampNotice(droppedCount: 0, truncatedTail: false)

        // --- A. Quét nhà 1 lần cho 5 hành tinh ngoài (timeline.py:75-78) ---
        var houseCache: [String: [HouseInterval]] = [:]
        for p in outerPlanets {
            if isCancelled() { throw CancellationError() }
            houseCache[p] = AstroCore.scanHouseTransitsInRange(pName: p, natalChart: natal,
                                                               startDate: start, endDate: end)
            try tick()
        }

        // --- B. Bộ nhớ đệm kỳ tạo góc (timeline.py:82-89) ---
        var aspectMemo: [String: [AspectPeriod]] = [:]
        func cachedAspectTimes(_ tP: String, _ nP: String, _ asp: String) -> [AspectPeriod] {
            let key = "\(tP)_\(nP)_\(asp)"
            if let hit = aspectMemo[key] { return hit }
            let raw = AstroCore.findExactAspectTimes(pTrans: tP, pNatal: nP, aspectName: asp,
                                                     startDateStr: scanStartStr, natalChart: natal,
                                                     endDateStr: limitLateEStr)
            let (kept, n) = EphemerisWindow.clamp(aspects: raw)
            if !n.isEmpty {
                notice = EphemerisClampNotice(
                    droppedCount: notice.droppedCount + n.droppedCount,
                    truncatedTail: notice.truncatedTail || n.truncatedTail)
            }
            aspectMemo[key] = kept
            return kept
        }

        /// Lọc kỳ tạo góc về khoảng xem — timeline.py:118-149 (dùng chung cho BƯỚC 2 và 3).
        func validPeriods(_ res: [AspectPeriod]) -> [TimelinePeriod] {
            var out: [TimelinePeriod] = []
            for r in res {
                guard let sD = CivilDateTime.parseDMY(r.start.d),
                      let eD = CivilDateTime.parseDMY(r.end.d) else { continue }
                if eD.epochMicroseconds < limitEarlyE.epochMicroseconds
                    || sD.epochMicroseconds > limitLateE.epochMicroseconds { continue }

                var exList: [CivilDateTime] = []
                var hasEarly = false, hasLate = false
                for hit in r.exactHits {
                    guard let hd = CivilDateTime.parseDMY(hit.d) else { continue }
                    if hd.epochMicroseconds >= start.epochMicroseconds
                        && hd.epochMicroseconds <= end.epochMicroseconds { exList.append(hd) }
                    if hd.epochMicroseconds >= limitEarlyE.epochMicroseconds
                        && hd.epochMicroseconds < start.epochMicroseconds { hasEarly = true }
                    if hd.epochMicroseconds > end.epochMicroseconds
                        && hd.epochMicroseconds <= limitLateE.epochMicroseconds { hasLate = true }
                }

                let clampedStart = sD.epochMicroseconds <= start.epochMicroseconds
                let clampedEnd   = eD.epochMicroseconds >= end.epochMicroseconds
                let inRangeS = sD.epochMicroseconds >= start.epochMicroseconds
                            && sD.epochMicroseconds <= end.epochMicroseconds
                let inRangeE = eD.epochMicroseconds >= start.epochMicroseconds
                            && eD.epochMicroseconds <= end.epochMicroseconds

                if (clampedStart && clampedEnd) || inRangeS || inRangeE || hasEarly || hasLate {
                    out.append(TimelinePeriod(
                        start: max(sD, start), end: min(eD, end),
                        isClampedStart: clampedStart, isClampedEnd: clampedEnd,
                        exacts: exList, hasEarlyE: hasEarly, hasLateE: hasLate, kind: .aspect))
                }
            }
            return out
        }

        /// BƯỚC 2 & 3 dùng chung (timeline.py:110-197 lặp y hệt nhau 2 lần).
        func aspectRowsFor(_ natalPoint: String) throws -> [TimelineRow] {
            var rows: [TimelineRow] = []
            for pOuter in outerPlanets {
                for aspName in AstroConst.majorAspects {
                    if isCancelled() { throw CancellationError() }
                    let res = cachedAspectTimes(pOuter, natalPoint, aspName)
                    let periods = validPeriods(res)
                    try tick()
                    guard !periods.isEmpty else { continue }
                    let symT = AstroConst.planetSymbols[pOuter] ?? ""
                    let symA = AstroConst.aspectByName[aspName]?.symbol ?? ""
                    let symN = AstroConst.planetSymbols[natalPoint] ?? ""
                    rows.append(TimelineRow(kind: .aspect, label: "\(symT)\(symA)\(symN)",
                                            periods: periods))
                }
            }
            return rows
        }

        // --- Vòng chính qua các nhà (timeline.py:95-197) ---
        var rows: [TimelineRow] = []
        var seenTargets = Set<String>()      // để `tick()` khớp với ước lượng
        for hNum in houseList {
            rows.append(TimelineRow(kind: .separator, label: "NHÀ \(hNum)", periods: []))

            // BƯỚC 1: hành tinh ngoài vào/ra nhà (timeline.py:98-125)
            for pOuter in outerPlanets {
                let all = houseCache[pOuter] ?? []
                var periods: [TimelinePeriod] = []
                for iv in all where iv.house == hNum {
                    let sD = iv.start, eD = iv.end
                    let vStart = max(sD, start), vEnd = min(eD, end)
                    if vEnd.epochMicroseconds < start.epochMicroseconds
                        || vStart.epochMicroseconds > end.epochMicroseconds { continue }
                    periods.append(TimelinePeriod(
                        start: vStart, end: vEnd,
                        isClampedStart: (sD.epochMicroseconds < start.epochMicroseconds) || iv.clampedStart,
                        isClampedEnd:   (eD.epochMicroseconds > end.epochMicroseconds) || iv.clampedEnd,
                        exacts: [], hasEarlyE: false, hasLateE: false, kind: .entry))
                }
                if !periods.isEmpty {
                    let symT = AstroConst.planetSymbols[pOuter] ?? ""
                    rows.append(TimelineRow(kind: .houseEntry, label: "\(symT)=H\(hNum)",
                                            periods: periods))
                }
            }

            // BƯỚC 2: hành tinh natal gần đỉnh nhà nhất (timeline.py:128-166)
            let pNear = AstroCore.getNatalPlanetNearCusp(chart: natal, houseNum: hNum)
            if let pNear, corePlanets.contains(pNear) {
                let isNew = seenTargets.insert(pNear).inserted
                rows.append(contentsOf: try aspectRowsFor(pNear))
                if !isNew { done -= outerPlanets.count * AstroConst.majorAspects.count }
            }

            // BƯỚC 3: chủ tinh đỉnh nhà (timeline.py:169-197)
            // ⚠️ GIỮ NGUYÊN: web dùng `continue` — bỏ luôn phần còn lại của VÒNG NHÀ,
            //    chứ không phải chỉ bỏ bước 3 (timeline.py:172).
            let pRuler = AstroCore.getHouseRulerPlanet(chart: natal, houseNum: hNum)
            if let pRuler, corePlanets.contains(pRuler) {
                if pRuler == pNear { continue }
                let isNew = seenTargets.insert(pRuler).inserted
                rows.append(contentsOf: try aspectRowsFor(pRuler))
                if !isNew { done -= outerPlanets.count * AstroConst.majorAspects.count }
            }
        }

        onProgress?(totalUnits, totalUnits)
        return TimelineData(rows: rows, start: start, end: end,
                            totalDays: totalDays, notice: notice)
    }
}

// MARK: - Tiện ích so sánh ngày ----------------------------------------------

/// `CivilDateTime` (ở `Src/Core/`, CẤM sửa) mới chỉ `Equatable`.
/// Bổ sung `Comparable` + `Hashable` từ ngoài để dùng được trong `TimelinePeriod`.
extension CivilDateTime: Comparable {
    public static func < (a: CivilDateTime, b: CivilDateTime) -> Bool {
        a.epochMicroseconds < b.epochMicroseconds
    }
}

extension CivilDateTime: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(epochMicroseconds)
    }
}
