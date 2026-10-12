//  CivilDateTime.swift
//  Thay thế `datetime.datetime` "naive" của Python (lịch Gregory suy rộng, KHÔNG múi giờ).
//
//  VÌ SAO KHÔNG DÙNG Foundation.Date: `Date` là mốc tuyệt đối trên trục UTC, còn
//  `core.py` làm việc với GIỜ TƯỜNG (wall clock) không múi giờ rồi mới tự trừ offset.
//  Dùng Calendar/DateComponents dễ dính TimeZone ngầm của máy → sai kết quả.
//  Ở đây tự cài số học lịch để bám đúng ngữ nghĩa Python.

import Foundation

public struct CivilDateTime: Equatable, CustomStringConvertible {
    public var year: Int
    public var month: Int
    public var day: Int
    public var hour: Int
    public var minute: Int
    public var second: Int
    public var microsecond: Int

    public init(year: Int, month: Int, day: Int,
                hour: Int = 0, minute: Int = 0, second: Int = 0, microsecond: Int = 0) {
        self.year = year; self.month = month; self.day = day
        self.hour = hour; self.minute = minute; self.second = second
        self.microsecond = microsecond
    }

    // MARK: - Số học lịch Gregory suy rộng (thuật toán Howard Hinnant)

    /// Số ngày kể từ 1970-01-01 (âm nếu trước đó). Đúng cho cả năm âm.
    public static func daysFromCivil(_ y0: Int, _ m: Int, _ d: Int) -> Int {
        var y = y0
        y -= (m <= 2 ? 1 : 0)
        let era = (y >= 0 ? y : y - 399) / 400
        let yoe = y - era * 400                                   // [0, 399]
        let doy = (153 * (m + (m > 2 ? -3 : 9)) + 2) / 5 + d - 1  // [0, 365]
        let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy           // [0, 146096]
        return era * 146097 + doe - 719468
    }

    /// Nghịch đảo của `daysFromCivil`.
    public static func civilFromDays(_ z0: Int) -> (year: Int, month: Int, day: Int) {
        var z = z0
        z += 719468
        let era = (z >= 0 ? z : z - 146096) / 146097
        let doe = z - era * 146097                                        // [0, 146096]
        let yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365    // [0, 399]
        let y = yoe + era * 400
        let doy = doe - (365 * yoe + yoe / 4 - yoe / 100)                  // [0, 365]
        let mp = (5 * doy + 2) / 153                                       // [0, 11]
        let d = doy - (153 * mp + 2) / 5 + 1                                // [1, 31]
        let m = mp + (mp < 10 ? 3 : -9)                                     // [1, 12]
        return (y + (m <= 2 ? 1 : 0), m, d)
    }

    /// Tổng số micro-giây kể từ 1970-01-01T00:00:00 (giờ tường, không múi giờ).
    public var epochMicroseconds: Int {
        let days = CivilDateTime.daysFromCivil(year, month, day)
        let secs = days * 86_400 + hour * 3_600 + minute * 60 + second
        return secs * 1_000_000 + microsecond
    }

    public init(epochMicroseconds us: Int) {
        // Chia lấy sàn (floor) để đúng cả khi âm — Python cũng floor.
        let totalSec = CivilDateTime.floorDiv(us, 1_000_000)
        let micro = us - totalSec * 1_000_000
        let days = CivilDateTime.floorDiv(totalSec, 86_400)
        let rem = totalSec - days * 86_400
        let (y, m, d) = CivilDateTime.civilFromDays(days)
        self.init(year: y, month: m, day: d,
                  hour: rem / 3_600, minute: (rem % 3_600) / 60, second: rem % 60,
                  microsecond: micro)
    }

    static func floorDiv(_ a: Int, _ b: Int) -> Int {
        let q = a / b
        return (a % b != 0 && ((a < 0) != (b < 0))) ? q - 1 : q
    }

    /// `dt - timedelta(hours: h)` của Python.
    /// Python `timedelta` lưu tới micro-giây và làm tròn khi khởi tạo → dùng `rounded()`.
    public func minusHours(_ h: Double) -> CivilDateTime {
        let deltaUs = Int((h * 3_600.0 * 1_000_000.0).rounded())
        return CivilDateTime(epochMicroseconds: epochMicroseconds - deltaUs)
    }

    /// `dt + timedelta(seconds: s)` với `s` đã là số nguyên (core.py luôn `round()` trước).
    public func plusSeconds(_ s: Int) -> CivilDateTime {
        return CivilDateTime(epochMicroseconds: epochMicroseconds + s * 1_000_000)
    }

    public func plusDays(_ d: Int) -> CivilDateTime {
        return CivilDateTime(epochMicroseconds: epochMicroseconds + d * 86_400 * 1_000_000)
    }

    // MARK: - Phân tích / định dạng chuỗi (thay strptime/strftime)

    /// `datetime.strptime(s, "%d/%m/%Y")`
    public static func parseDMY(_ s: String) -> CivilDateTime? {
        let parts = s.split(separator: "/")
        guard parts.count == 3,
              let d = Int(parts[0]), let m = Int(parts[1]), let y = Int(parts[2]) else { return nil }
        guard m >= 1, m <= 12, d >= 1, d <= 31 else { return nil }
        return CivilDateTime(year: y, month: m, day: d)
    }

    /// `datetime.strptime(f"{dob} {tob}", "%d/%m/%Y %H:%M")`
    public static func parseDMYHM(dob: String, tob: String) -> CivilDateTime? {
        guard var dt = parseDMY(dob) else { return nil }
        let tp = tob.split(separator: ":")
        guard tp.count >= 2, let h = Int(tp[0]), let mi = Int(tp[1]) else { return nil }
        guard h >= 0, h <= 23, mi >= 0, mi <= 59 else { return nil }
        dt.hour = h; dt.minute = mi
        return dt
    }

    private static func pad(_ v: Int, _ n: Int) -> String {
        let s = String(v)
        return s.count >= n ? s : String(repeating: "0", count: n - s.count) + s
    }

    /// `strftime("%d/%m/%Y")`
    public var dmy: String { "\(Self.pad(day, 2))/\(Self.pad(month, 2))/\(Self.pad(year, 4))" }
    /// `strftime("%H:%M")`
    public var hm: String { "\(Self.pad(hour, 2)):\(Self.pad(minute, 2))" }
    /// `strftime("%H:%M:%S")`
    public var hms: String { "\(Self.pad(hour, 2)):\(Self.pad(minute, 2)):\(Self.pad(second, 2))" }
    /// `strftime("%d/%m/%Y %H:%M")`
    public var dmyhm: String { "\(dmy) \(hm)" }

    public var description: String { "\(dmy) \(hms).\(Self.pad(microsecond, 6))" }
}
