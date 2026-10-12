//  EphemerisWindow.swift
//  KẸP BIÊN DỮ LIỆU THIÊN VĂN.
//
//  VẤN ĐỀ (đã đo, không phải suy đoán):
//    `Resources/ephe/` chỉ có 3 file khối `_18` (seas/sepl/semo) → phủ 1800–2399.
//    Nhưng `find_return_times` quét tới 146 100 ngày ≈ 400 năm
//    (`app/astro00_lib/core.py:396`, bản Swift `Src/Core/AstroCore.swift:566`).
//    Khởi hành 2026 → quét tới ~2426, VƯỢT biên.
//
//    Đo thực tế bằng `swe_calc_ut` + so cờ trả về (`retflag != iflag` ⇒ đã rơi về
//    Moshier, tức KHÔNG còn là số của Swiss Ephemeris):
//      • Cận dưới: Mặt Trời/Diêm Vương/Chiron chỉ "sạch" từ JD ≈ 2378496.5–2378496.74
//        (01/01/1800, khoảng 00:08–05:45 UT).
//      • Cận trên: sạch tới JD = 2597642.0 (01/01/2400 12:00 UT); JD lớn hơn → Moshier.
//      • Chiron ngoài biên còn ném hẳn lỗi "SwissEph file 'seas_12.se1'/'seas_24.se1' not found".
//    Python KHÔNG báo lỗi khi vượt biên — nó lặng lẽ trả số Moshier. Vì thế phải tự kẹp.
//
//  CÁCH XỬ Ở APP:
//    1. Chặn ngày bắt đầu nằm ngoài cửa sổ ngay từ ô nhập.
//    2. GỌI NGUYÊN hàm lõi (giữ parity với web, CẤM sửa `Src/Core/`), rồi LỌC BỎ
//       kết quả rơi ra ngoài cửa sổ và BÁO SỐ ĐÃ CẮT cho người dùng.

import Foundation

public struct EphemerisClampNotice: Equatable, Sendable {
    /// Số kết quả bị cắt vì nằm ngoài dữ liệu thiên văn.
    public var droppedCount: Int
    /// Kết quả cuối cùng có bị cắt cụt ở đuôi không.
    public var truncatedTail: Bool

    public var isEmpty: Bool { droppedCount == 0 && !truncatedTail }

    public var message: String? {
        guard !isEmpty else { return nil }
        var s = "Dữ liệu thiên văn trong máy chỉ phủ \(EphemerisWindow.rangeLabel)."
        if droppedCount > 0 { s += " Đã cắt \(droppedCount) kết quả nằm ngoài khoảng này." }
        if truncatedTail { s += " Mốc cuối bị cắt ở biên." }
        return s
    }
}

public enum EphemerisWindow {

    // MARK: - Biên (đã đo bằng swe_calc_ut, xem chú thích đầu file)

    /// 02/01/1800 00:00 UT — lùi 1 ngày an toàn so với biên đo được (JD 2378496.74).
    public static let minJD: Double = 2378497.5
    /// 31/12/2399 00:00 UT — lùi 1 ngày an toàn so với biên đo được (JD 2597642.0).
    public static let maxJD: Double = 2597640.5

    public static let minDate = CivilDateTime(year: 1800, month: 1, day: 2)
    public static let maxDate = CivilDateTime(year: 2399, month: 12, day: 31)

    public static let rangeLabel = "02/01/1800 – 31/12/2399"

    // MARK: - Kiểm tra

    public static func contains(year: Int, month: Int, day: Int) -> Bool {
        let d = CivilDateTime(year: year, month: month, day: day)
        return d.epochMicroseconds >= minDate.epochMicroseconds
            && d.epochMicroseconds <= maxDate.epochMicroseconds
    }

    public static func contains(_ d: CivilDateTime) -> Bool {
        d.epochMicroseconds >= minDate.epochMicroseconds
            && d.epochMicroseconds <= maxDate.epochMicroseconds
    }

    /// Chuỗi "dd/MM/yyyy" có nằm trong cửa sổ không.
    public static func containsDMY(_ s: String) -> Bool {
        guard let d = CivilDateTime.parseDMY(s) else { return false }
        return contains(d)
    }

    /// Kẹp một ngày về trong cửa sổ. Trả kèm cờ báo đã phải kẹp.
    public static func clamp(_ d: CivilDateTime) -> (date: CivilDateTime, clamped: Bool) {
        if d.epochMicroseconds < minDate.epochMicroseconds { return (minDate, true) }
        if d.epochMicroseconds > maxDate.epochMicroseconds { return (maxDate, true) }
        return (d, false)
    }

    /// Thông báo cho ô nhập ngày sai biên.
    public static func validationMessage(for d: CivilDateTime) -> String? {
        contains(d) ? nil
            : "Ngày phải nằm trong \(rangeLabel) — đó là toàn bộ khoảng mà 3 file ephemeris trong máy phủ được."
    }

    // MARK: - Lọc kết quả của 3 hàm dò thời điểm

    private static func inWindow(_ ts: TimeStamp) -> Bool {
        guard let d = CivilDateTime.parseDMY(ts.d) else { return false }
        return contains(d)
    }

    /// `find_exact_aspect_times` — giữ những kỳ nằm TRỌN trong cửa sổ.
    public static func clamp(aspects: [AspectPeriod]) -> ([AspectPeriod], EphemerisClampNotice) {
        var kept: [AspectPeriod] = []
        var dropped = 0
        var tail = false
        for p in aspects {
            if inWindow(p.start) && inWindow(p.end) {
                var q = p
                let before = q.exactHits.count
                q.exactHits = q.exactHits.filter(inWindow)
                if q.exactHits.count != before { tail = true }
                kept.append(q)
            } else {
                dropped += 1
                if inWindow(p.start) { tail = true }
            }
        }
        return (kept, EphemerisClampNotice(droppedCount: dropped, truncatedTail: tail))
    }

    /// `find_return_times`.
    public static func clamp(returns: [ReturnPeriod]) -> ([ReturnPeriod], EphemerisClampNotice) {
        var kept: [ReturnPeriod] = []
        var dropped = 0
        var tail = false
        for p in returns {
            if inWindow(p.start) && inWindow(p.end) {
                var q = p
                let before = q.exactHits.count
                q.exactHits = q.exactHits.filter(inWindow)
                if q.exactHits.count != before { tail = true }
                kept.append(q)
            } else {
                dropped += 1
                if inWindow(p.start) { tail = true }
            }
        }
        return (kept, EphemerisClampNotice(droppedCount: dropped, truncatedTail: tail))
    }

    /// `find_current_house_transit_period` — chỉ 1 kỳ, nên chỉ báo cắt đuôi.
    public static func clamp(house: HouseTransitPeriod?) -> (HouseTransitPeriod?, EphemerisClampNotice) {
        guard let h = house else { return (nil, EphemerisClampNotice(droppedCount: 0, truncatedTail: false)) }
        let sOK = inWindow(h.start), eOK = inWindow(h.end)
        if sOK && eOK { return (h, EphemerisClampNotice(droppedCount: 0, truncatedTail: false)) }
        return (h, EphemerisClampNotice(droppedCount: 0, truncatedTail: true))
    }
}
