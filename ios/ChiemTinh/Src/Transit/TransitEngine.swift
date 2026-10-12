//  TransitEngine.swift
//  CHẠY NỀN — HUỶ ĐƯỢC — CÓ ĐỆM cho mọi phép tính vận hạn.
//
//  VÌ SAO PHẢI CÓ:
//   1. Swiss Ephemeris (`Src/CSwissEph/*.c`) là thư viện C có TRẠNG THÁI TOÀN CỤC
//      (`swe_set_ephe_path`, `swe_set_topo`). Gọi song song từ nhiều luồng là hỏng.
//      → Bọc trong `actor` để tuần tự hoá, đồng thời đẩy khỏi luồng chính.
//   2. `/vanhan/chitiet` của web đã phải warm-up + chống sập + báo quá tải
//      (`app/routes/transits.py:12-22, 165, 231-234`). Trên iPhone còn nặng hơn
//      → cần tiến trình, huỷ khi rời màn, và đệm kết quả.
//
//  Bộ đệm là bộ nhớ trong tiến trình (mất khi thoát app) — giống 3 dict của web
//  (`app/cache.py`).

import Foundation

public actor TransitEngine {

    public static let shared = TransitEngine()

    private var warmedUp = false
    private var aspectCache: [String: ([AspectPeriod], EphemerisClampNotice)] = [:]
    private var returnCache: [String: ([ReturnPeriod], EphemerisClampNotice)] = [:]
    private var houseCache: [String: (HouseTransitPeriod?, EphemerisClampNotice)] = [:]
    private var timelineCache: [String: TimelineData] = [:]

    public init() {}

    // MARK: - Mồi engine (port `warmup_swe_engine` — transits.py:12-22)

    public func warmUp() {
        guard !warmedUp else { return }
        _ = SwissEph.bootstrapFromBundle()
        let jd = SwissEph.julday(2000, 1, 1, 12.0)
        _ = SwissEph.calcUT(jd, SwePlanet.sun, SweFlag.swieph)
        warmedUp = true
    }

    public func clearCache() {
        aspectCache.removeAll(); returnCache.removeAll()
        houseCache.removeAll(); timelineCache.removeAll()
    }

    // MARK: - Bản đồ sao (tính trên nền, không chặn UI)

    public func natalChart(for p: BirthProfile) -> Chart? {
        warmUp()
        return p.natalChart()
    }

    /// Bản đồ "Chart of the moment" — `transits.py:44-45`.
    public func currentSkyChart(now: CivilDateTime, lat: Double, lon: Double, tz: String) -> Chart? {
        warmUp()
        return AstroCore.calculateChart(dobStr: now.dmy,
                                        tobStr: String(format: "%02d:%02d", now.hour, now.minute),
                                        lat: lat, lon: lon, tzStr: tz)
    }

    /// Bản đồ transit của 1 ngày — `transits.py:121` (`"00:00"`, tz `"UTC"`, offset thủ công 0).
    public func transitChart(on d: CivilDateTime, lat: Double, lon: Double) -> Chart? {
        warmUp()
        return AstroCore.calculateChart(dobStr: d.dmy, tobStr: "00:00",
                                        lat: lat, lon: lon, tzStr: "UTC", manualOffset: "0")
    }

    // MARK: - 3 tra cứu (3 modal của web)

    /// `POST /api/tra-goc-transit` — `app/routes/api.py:151-166`.
    public func aspectPeriods(profile: BirthProfile, pTrans: String, pNatal: String,
                              aspect: String, day: Int, month: Int, year: Int)
        throws -> ([AspectPeriod], EphemerisClampNotice) {
        warmUp()
        let key = "A|\(profile.id)|\(pTrans)|\(pNatal)|\(aspect)|\(day)/\(month)/\(year)"
        if let hit = aspectCache[key] { return hit }
        try Task.checkCancellation()
        guard let natal = profile.natalChart() else { return ([], EphemerisClampNotice(droppedCount: 0, truncatedTail: false)) }
        let raw = AstroCore.findExactAspectTimes(pTrans: pTrans, pNatal: pNatal,
                                                 aspectName: aspect,
                                                 startDateStr: "\(day)/\(month)/\(year)",
                                                 natalChart: natal)
        let res = EphemerisWindow.clamp(aspects: raw)
        aspectCache[key] = res
        return res
    }

    /// `POST /api/tra-hoi-vi` — `app/routes/api.py:168-183`.
    public func returnPeriods(profile: BirthProfile, pTrans: String,
                              day: Int, month: Int, year: Int)
        throws -> ([ReturnPeriod], EphemerisClampNotice) {
        warmUp()
        let key = "R|\(profile.id)|\(pTrans)|\(day)/\(month)/\(year)"
        if let hit = returnCache[key] { return hit }
        try Task.checkCancellation()
        guard let natal = profile.natalChart() else { return ([], EphemerisClampNotice(droppedCount: 0, truncatedTail: false)) }
        let raw = AstroCore.findReturnTimes(pName: pTrans,
                                            startDateStr: "\(day)/\(month)/\(year)",
                                            natalChart: natal)
        let res = EphemerisWindow.clamp(returns: raw)
        returnCache[key] = res
        return res
    }

    /// `POST /api/tra-nha-transit` — `app/routes/api.py:185-198`.
    public func houseTransitPeriod(profile: BirthProfile, pTrans: String,
                                   day: Int?, month: Int?, year: Int?)
        throws -> (HouseTransitPeriod?, EphemerisClampNotice) {
        warmUp()
        let key = "H|\(profile.id)|\(pTrans)|\(day ?? -1)/\(month ?? -1)/\(year ?? -1)"
        if let hit = houseCache[key] { return hit }
        try Task.checkCancellation()
        guard let natal = profile.natalChart() else { return (nil, EphemerisClampNotice(droppedCount: 0, truncatedTail: false)) }
        let raw = AstroCore.findCurrentHouseTransitPeriod(pName: pTrans, natalChart: natal,
                                                          d: day, m: month, y: year)
        let res = EphemerisWindow.clamp(house: raw)
        houseCache[key] = res
        return res
    }

    // MARK: - Vận hạn chi tiết (phần nặng nhất)

    /// Trả về `TimelineData`. Có đệm; báo tiến trình; huỷ bằng cách huỷ `Task` bao ngoài.
    public func timeline(profile: BirthProfile,
                         start: CivilDateTime, end: CivilDateTime,
                         houses: [Int],
                         onProgress: @Sendable @escaping (Double) -> Void) throws -> TimelineData {
        warmUp()
        let key = "T|\(profile.id)|\(start.dmy)|\(end.dmy)|\(houses.sorted().map(String.init).joined(separator: "-"))"
        if let hit = timelineCache[key] { onProgress(1); return hit }
        try Task.checkCancellation()
        guard let natal = profile.natalChart() else { throw TransitEngineError.natalFailed }

        let data = try TransitTimelineBuilder.build(
            natal: natal, start: start, end: end, houseList: houses,
            onProgress: { done, total in onProgress(Double(done) / Double(max(1, total))) },
            isCancelled: { Task.isCancelled })
        timelineCache[key] = data
        return data
    }

    /// Khối kết quả của màn "Vận Hạn Riêng".
    public struct PersonalResult: Sendable {
        public var natal: Chart
        public var transit: Chart
        public var transitEnd: Chart?
        public var mode: TransitReports.TransitMode
        public var title: String
        public var houseRows: [TransitReports.TransitHouseRow]
        public var aspectPlanets: [TransitReports.TransitAspectRow]
        public var aspectPoints: [TransitReports.TransitAspectRow]
        public var cycle: [TransitReports.OuterCycleSpan]?
    }

    /// Port toàn bộ nhánh tính của `/vanhan/rieng` (`transits.py:114-155`).
    public func personal(profile: BirthProfile,
                         mode: TransitReports.TransitMode,
                         date: CivilDateTime,
                         rangeStart: CivilDateTime,
                         rangeEnd: CivilDateTime) throws -> PersonalResult {
        warmUp()
        try Task.checkCancellation()
        guard let natal = profile.natalChart() else { throw TransitEngineError.natalFailed }

        if mode == .single {
            guard let t = transitChart(on: date, lat: profile.lat, lon: profile.lon) else {
                throw TransitEngineError.transitFailed
            }
            let (ap, pt) = TransitReports.aspectSections(natal: natal, transit: t)
            return PersonalResult(
                natal: natal, transit: t, transitEnd: nil, mode: .single,
                title: "Transits: \(profile.name) (\(date.dmy))",
                houseRows: TransitReports.houseRows(natal: natal, transit: t, mode: .single),
                aspectPlanets: ap, aspectPoints: pt, cycle: nil)
        } else {
            guard let ts = transitChart(on: rangeStart, lat: profile.lat, lon: profile.lon),
                  let te = transitChart(on: rangeEnd, lat: profile.lat, lon: profile.lon) else {
                throw TransitEngineError.transitFailed
            }
            try Task.checkCancellation()
            let cycle = TransitReports.outerCycleData(lat: profile.lat, lon: profile.lon,
                                                      start: rangeStart, end: rangeEnd)
            return PersonalResult(
                natal: natal, transit: ts, transitEnd: te, mode: .outerCycle,
                title: "Đại Hạn: \(profile.name) (\(rangeStart.dmy) - \(rangeEnd.dmy))",
                houseRows: TransitReports.houseRows(natal: natal, transit: ts,
                                                    mode: .outerCycle, transitEnd: te),
                aspectPlanets: [], aspectPoints: [], cycle: cycle)
        }
    }
}

public enum TransitEngineError: Error, CustomStringConvertible {
    case natalFailed
    case transitFailed

    public var description: String {
        switch self {
        case .natalFailed:   return "Không dựng được bản đồ sao gốc (kiểm tra ngày/giờ/nơi sinh)."
        case .transitFailed: return "Không dựng được bản đồ transit cho ngày đã chọn."
        }
    }
}
