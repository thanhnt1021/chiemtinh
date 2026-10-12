//  SwissEph.swift
//  Lớp bọc Swift MỎNG quanh thư viện C Swiss Ephemeris (libswe 2.10.03).
//
//  MỤC TIÊU: mỗi hàm ở đây phải hành xử Y HỆT hàm cùng tên trong `pyswisseph`
//  mà web Python đang gọi, kể cả THỨ TỰ THAM SỐ (xem ghi chú `setTopo`).
//  Nguồn C: libswe kèm trong sdist pyswisseph 2.10.3.2 — trùng phiên bản với web.

import Foundation

/// Cờ tính toán — đối chiếu `swephexp.h`
public enum SweFlag {
    public static let swieph: Int32 = 2      // SEFLG_SWIEPH
    public static let speed: Int32 = 256     // SEFLG_SPEED
}

/// ID thiên thể — đối chiếu `swephexp.h` và `astro00_lib/const.py:4-10`
public enum SwePlanet {
    public static let sun: Int32 = 0
    public static let moon: Int32 = 1
    public static let mercury: Int32 = 2
    public static let venus: Int32 = 3
    public static let mars: Int32 = 4
    public static let jupiter: Int32 = 5
    public static let saturn: Int32 = 6
    public static let uranus: Int32 = 7
    public static let neptune: Int32 = 8
    public static let pluto: Int32 = 9
    public static let meanNode: Int32 = 10
    public static let trueNode: Int32 = 11
    public static let meanApog: Int32 = 12   // Lilith
    public static let oscuApog: Int32 = 13
    public static let earth: Int32 = 14
    public static let chiron: Int32 = 15
}

/// Cờ lịch cho julday/revjul. pyswisseph mặc định GREG_CAL (=1).
public let SWE_GREG_CAL: Int32 = 1

public enum SwissEph {

    /// Đã nạp đường dẫn ephemeris chưa
    private static var ephePathSet = false

    /// Tương đương `swe.set_ephe_path(path)` — `core.py:23`
    public static func setEphePath(_ path: String) {
        path.withCString { cs in
            swe_set_ephe_path(UnsafeMutablePointer(mutating: cs))
        }
        ephePathSet = true
    }

    /// Trỏ vào thư mục Resources của app bundle (nơi chứa seas_18/semo_18/sepl_18.se1).
    /// Gọi một lần khi app khởi động. Idempotent.
    @discardableResult
    public static func bootstrapFromBundle(_ bundle: Bundle = .main) -> String? {
        guard let res = bundle.resourcePath else { return nil }
        setEphePath(res)
        return res
    }

    public static var isEphePathSet: Bool { ephePathSet }

    /// Tương đương `swe.julday(y, m, d, hourFloat)` (pyswisseph mặc định cal = GREG_CAL)
    public static func julday(_ year: Int, _ month: Int, _ day: Int, _ hour: Double) -> Double {
        return swe_julday(Int32(year), Int32(month), Int32(day), hour, SWE_GREG_CAL)
    }

    /// Tương đương `swe.revjul(jd)` → (year, month, day, hourFloat)
    public static func revjul(_ jd: Double) -> (year: Int, month: Int, day: Int, hour: Double) {
        var y: Int32 = 0, m: Int32 = 0, d: Int32 = 0
        var ut: Double = 0
        swe_revjul(jd, SWE_GREG_CAL, &y, &m, &d, &ut)
        return (Int(y), Int(m), Int(d), ut)
    }

    /// Kết quả `swe.calc_ut` — 6 số + cờ trả về
    public struct CalcResult {
        public var xx: [Double]      // [lon, lat, dist, speedLon, speedLat, speedDist]
        public var retFlag: Int32
        public var error: String?
        public var lon: Double { xx[0] }
        public var lat: Double { xx[1] }
        public var speed: Double { xx[3] }
    }

    /// Tương đương `swe.calc_ut(jd, ipl, iflag)`
    public static func calcUT(_ jd: Double, _ ipl: Int32, _ iflag: Int32) -> CalcResult {
        var xx = [Double](repeating: 0, count: 6)
        var serr = [CChar](repeating: 0, count: 256)
        let ret = xx.withUnsafeMutableBufferPointer { xp -> Int32 in
            serr.withUnsafeMutableBufferPointer { ep -> Int32 in
                swe_calc_ut(jd, ipl, iflag, xp.baseAddress, ep.baseAddress)
            }
        }
        let err = String(cString: serr)
        return CalcResult(xx: xx, retFlag: ret, error: err.isEmpty ? nil : err)
    }

    /// Tương đương `swe.houses(jd, lat, lon, b'P')`.
    /// pyswisseph trả về **12** cusp (C `cusps[1...12]`) + **8** ascmc — xem `pyswisseph.c :: pyswe_houses`.
    /// `ret < 0` ⇒ pyswisseph NÉM `swisseph.Error` ⇒ `calculate_chart` rơi vào `except` và
    /// trả về `None` (`core.py:216-218`). Bản Swift phải tái hiện ĐÚNG hành vi đó.
    public static func houses(_ jd: Double, _ lat: Double, _ lon: Double, _ hsys: Character = "P")
        -> (cusps: [Double], ascmc: [Double], ret: Int32) {
        var cusps = [Double](repeating: 0, count: 37)
        var ascmc = [Double](repeating: 0, count: 10)
        let h = Int32(hsys.asciiValue ?? 80)
        let ret = cusps.withUnsafeMutableBufferPointer { cp -> Int32 in
            ascmc.withUnsafeMutableBufferPointer { ap -> Int32 in
                Int32(swe_houses(jd, lat, lon, h, cp.baseAddress, ap.baseAddress))
            }
        }
        return (Array(cusps[1...12]), Array(ascmc[0...7]), ret)
    }

    /// Tương đương `swe.difdeg2n(p1, p2)` — hiệu góc chuẩn hoá về (-180, 180]
    public static func difdeg2n(_ p1: Double, _ p2: Double) -> Double {
        return swe_difdeg2n(p1, p2)
    }

    /// Tương đương `swe.sidtime(jd)` — Greenwich Sidereal Time (giờ)
    public static func sidtime(_ jd: Double) -> Double {
        return swe_sidtime(jd)
    }

    /// ⚠️ GIỮ NGUYÊN HÀNH VI WEB — KHÔNG "SỬA CHO ĐÚNG".
    ///
    /// `core.py:176` gọi `swe.set_topo(lat, lon, 0)`.
    /// Nhưng chữ ký pyswisseph là `set_topo(lon, lat, alt)` (`pyswisseph.c :: pyswe_set_topo`,
    /// dòng 3033-3041) → hai tham số đang bị HOÁN ĐỔI ở web.
    /// Ngoài ra `calc_ut` KHÔNG truyền cờ `SEFLG_TOPOCTR` (`core.py:199`) nên lệnh này
    /// hiện KHÔNG có tác dụng lên kết quả.
    /// Bản Swift gọi Y HỆT (đối số thứ nhất nhận giá trị vĩ độ) để kết quả trùng web tuyệt đối.
    public static func setTopoAsWeb(lat: Double, lon: Double, alt: Double = 0) {
        swe_set_topo(lat, lon, alt)   // cố ý: geolon <- lat, geolat <- lon (y hệt core.py:176)
    }

    public static func close() {
        swe_close()
    }

    /// Chuỗi phiên bản libswe đang biên dịch trong app (để chứng minh trùng bản với web)
    public static func version() -> String {
        var buf = [CChar](repeating: 0, count: 32)
        return buf.withUnsafeMutableBufferPointer { bp -> String in
            _ = swe_version(bp.baseAddress)
            return String(cString: bp.baseAddress!)
        }
    }
}
