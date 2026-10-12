//  AstroCore.swift
//  PORT 1-1 từ `app/astro00_lib/core.py` — BẢN REPO `git@github.com:hentaiikidd/chiemtinh.git`
//  HEAD 73e2e63bbc23c3dad856aa523b264481eb3b7c93 (571 dòng, 25 hàm cấp cao nhất).
//
//  NGUYÊN TẮC: GIỮ NGUYÊN HÀNH VI, KỂ CẢ CHỖ TRÔNG NHƯ SAI.
//  Mọi khác biệt so với "cách làm đúng" đều được chú thích `⚠️ GIỮ NGUYÊN`.
//
//  Số dòng tham chiếu trong chú thích là số dòng của BẢN REPO.

import Foundation
import CryptoKit

// MARK: - Tiện ích bám ngữ nghĩa Python

@inline(__always) func pmod(_ a: Double, _ n: Double) -> Double {
    // Python `%` luôn trả cùng dấu với số chia; Swift `%`/truncatingRemainder thì không.
    let r = a.truncatingRemainder(dividingBy: n)
    return (r != 0 && (r < 0) != (n < 0)) ? r + n : r
}

@inline(__always) func pmodInt(_ a: Int, _ n: Int) -> Int {
    let r = a % n
    return (r != 0 && (r < 0) != (n < 0)) ? r + n : r
}

/// `round()` của Python 3 = làm tròn về số CHẴN gần nhất khi hoà (banker's rounding).
/// Swift `.rounded()` mặc định là half-away-from-zero → PHẢI dùng `.toNearestOrEven`.
@inline(__always) func pyRound(_ x: Double) -> Double { x.rounded(.toNearestOrEven) }
@inline(__always) func pyRoundInt(_ x: Double) -> Int { Int(x.rounded(.toNearestOrEven)) }

/// Chỉ số kiểu Python (cho phép chỉ số âm đếm ngược từ cuối).
@inline(__always) func pyIndex<T>(_ arr: [T], _ i: Int) -> T {
    return i < 0 ? arr[arr.count + i] : arr[i]
}

/// Tương đương `f"{v:+g}"` của Python (giống `%+g` của C).
@inline(__always) func pyFormatGPlus(_ v: Double) -> String { String(format: "%+g", v) }

// MARK: - Kiểu dữ liệu kết quả

public struct PlanetPosition {
    public var lon: Double
    public var lat: Double
    public var speed: Double
    public init(lon: Double, lat: Double, speed: Double) {
        self.lon = lon; self.lat = lat; self.speed = speed
    }
}

public struct ChartTechnicalInfo {
    public var localTime: String
    public var utTime: String
    public var lst: String
    public var latLon: String
    public var houseSys: String
}

public struct ChartMeta {
    public var lat: Double
    public var lon: Double
    public var tz: String?
    public var offsetUsed: Double
}

public struct Chart {
    public var jd: Double
    /// 12 phần tử — ĐÚNG như `swe.houses()` của pyswisseph trả về (C `cusps[1...12]`).
    public var cusps: [Double]
    public var angles: [String: Double]
    public var planets: [String: PlanetPosition]
    /// Thứ tự chèn của dict `planets` trong Python (13 hành tinh + Vertex, Asc, MC)
    public var planetOrder: [String]
    public var info: ChartTechnicalInfo
    public var meta: ChartMeta
}

public struct AspectHit {
    public var aspect: String
    public var nameVN: String
    public var orb: Double
    public var orbRound: Int
    public var type: String
    public var symbol: String
}

public struct TimeStamp {
    public var d: String   // "dd/MM/yyyy"
    public var t: String   // "HH:mm:ss"
}

public struct AspectPeriod {
    public var start: TimeStamp
    public var end: TimeStamp
    public var exactHits: [TimeStamp]
}

public struct ReturnPeriod {
    public var house: Int
    public var start: TimeStamp
    public var end: TimeStamp
    public var exactHits: [TimeStamp]
}

public struct HouseTransitPeriod {
    public var house: Int
    public var start: TimeStamp
    public var end: TimeStamp
}

public struct HouseInterval {
    public var house: Int
    public var start: CivilDateTime
    public var end: CivilDateTime
    public var clampedStart: Bool
    public var clampedEnd: Bool
}

// MARK: - AstroCore

public enum AstroCore {

    // ─────────────────────────────────────────────────────────────────────
    // 1/25  get_zodiac  — core.py:26-31
    // ─────────────────────────────────────────────────────────────────────
    public static func getZodiac(_ lonIn: Double)
        -> (idx: Int, name: String, code: String, degInSign: Double) {
        let lon = pmod(lonIn, 360)
        let idx = Int(lon / 30)                 // int() của Python = cắt về 0; lon >= 0 nên an toàn
        let degInSign = pmod(lon, 30)
        return (idx, AstroConst.zodiacNames[idx], AstroConst.zodiacCodes[idx], degInSign)
    }

    // ─────────────────────────────────────────────────────────────────────
    // 2/25  get_house_of_planet  — core.py:34-47
    // ─────────────────────────────────────────────────────────────────────
    public static func getHouseOfPlanet(_ planetLon: Double, _ cusps: [Double]) -> Int {
        let pLon = pmod(planetLon, 360)
        var realCusps = cusps
        if realCusps.count == 13 { realCusps = Array(realCusps.dropFirst()) }
        for i in 0..<12 {
            let cCurr = realCusps[i]
            let cNext = realCusps[(i + 1) % 12]
            let distP = pmod(pLon - cCurr, 360)
            let sizeH = pmod(cNext - cCurr, 360)
            if distP < sizeH { return i + 1 }
        }
        return 1
    }

    // ─────────────────────────────────────────────────────────────────────
    // 3/25  round_orb  — core.py:50-52
    // ─────────────────────────────────────────────────────────────────────
    public static func roundOrb(_ orbVal: Double) -> Int { pyRoundInt(orbVal) }

    // ─────────────────────────────────────────────────────────────────────
    // 4/25  check_aspect  — core.py:55-76
    // ─────────────────────────────────────────────────────────────────────
    public static func checkAspect(_ p1Lon: Double, _ p2Lon: Double,
                                   customOrbs: [String: Double]? = nil) -> AspectHit? {
        var diff = abs(p1Lon - p2Lon)
        if diff > 180 { diff = 360 - diff }
        for aspData in AstroConst.aspectsDef {          // duyệt ĐÚNG thứ tự khai báo
            var limit = aspData.orb
            if let co = customOrbs, let v = co[aspData.name] { limit = v }
            if abs(diff - aspData.angle) <= limit {
                let rawOrb = abs(diff - aspData.angle)
                if rawOrb >= 10.0 { return nil }        // ⚠️ GIỮ NGUYÊN: return None, KHÔNG `continue`
                return AspectHit(aspect: aspData.name, nameVN: aspData.nameVN,
                                 orb: rawOrb, orbRound: roundOrb(rawOrb),
                                 type: aspData.type, symbol: aspData.symbol)
            }
        }
        return nil
    }

    // ─────────────────────────────────────────────────────────────────────
    // 5/25  get_timezone_str  — core.py:79-82
    // ⚠️ CHƯA PORT ĐƯỢC: Python dùng `timezonefinder` (bảng đa giác ~40 MB).
    //    iOS chưa có bảng đó → trả nil; app luôn truyền sẵn `tzStr`.
    // ─────────────────────────────────────────────────────────────────────
    public static func getTimezoneStr(lat: Double, lon: Double) -> String? { nil }

    // ─────────────────────────────────────────────────────────────────────
    // 6/25  get_true_lmt_offset  — core.py:85-87
    // ─────────────────────────────────────────────────────────────────────
    public static func getTrueLMTOffset(_ lon: Double) -> Double { lon / 15.0 }

    // ─────────────────────────────────────────────────────────────────────
    // 7/25  is_coord_in_vietnam  — core.py:90-94
    // ─────────────────────────────────────────────────────────────────────
    public static func isCoordInVietnam(lat: Double, lon: Double) -> Bool {
        return (8.0 <= lat && lat <= 24.0) && (102.0 <= lon && lon <= 110.0)
    }

    // ─────────────────────────────────────────────────────────────────────
    // 8/25  get_vietnam_historical_offset  — core.py:97-121
    // 7 MỐC LỊCH SỬ, TÁCH BẮC/NAM Ở VĨ TUYẾN 17. PORT NGUYÊN VĂN TỪNG DÒNG.
    // ─────────────────────────────────────────────────────────────────────
    public static func getVietnamHistoricalOffset(year: Int, month: Int, day: Int,
                                                  lat: Double, lon: Double) -> Double {
        let ymd = (year, month, day)
        if ymd < (1906, 7, 1) { return lon / 15.0 }                              // core.py:100-101
        if (1906, 7, 1) <= ymd && ymd <= (1911, 4, 30) { return 7.1083 }         // core.py:102-103 (7h06m30s)
        if (1911, 5, 1) <= ymd && ymd <= (1942, 12, 31) { return 7.0 }           // core.py:104-105
        if (1943, 1, 1) <= ymd && ymd <= (1945, 3, 13) { return 8.0 }            // core.py:106-107
        if (1945, 3, 14) <= ymd && ymd <= (1945, 9, 1) { return 9.0 }            // core.py:108-109
        if (1945, 9, 2) <= ymd && ymd < (1975, 6, 13) {                          // core.py:110
            let isSouth = lat < 17.0                                             // core.py:111
            if !isSouth {
                return 7.0                                                       // core.py:112-113
            } else {
                if ymd <= (1955, 6, 30) { return 8.0 }                           // core.py:115-116
                else if (1955, 7, 1) <= ymd && ymd <= (1959, 12, 31) { return 7.0 } // core.py:117-118
                else { return 8.0 }                                              // core.py:119-120
            }
        }
        return 7.0                                                               // core.py:121
    }

    // ─────────────────────────────────────────────────────────────────────
    // 9/25  to_dms  — core.py:124-138
    // ⚠️ GIỮ NGUYÊN: Python tính `s` nhưng KHÔNG in ra (chuỗi chỉ có độ + phút).
    // ─────────────────────────────────────────────────────────────────────
    public static func toDMS(_ deg: Double, isLat: Bool = true) -> String {
        let direction: String = isLat ? (deg >= 0 ? "N" : "S") : (deg >= 0 ? "E" : "W")
        let adeg = abs(deg)
        var d = Int(adeg)
        let mFloat = (adeg - Double(d)) * 60
        var m = Int(mFloat)
        var s = pyRoundInt((mFloat - Double(m)) * 60)
        if s == 60 { m += 1; s = 0 }
        if m == 60 { d += 1; m = 0 }
        return "\(d)°\(m)'\(direction)"
    }

    // ─────────────────────────────────────────────────────────────────────
    // Phụ trợ: giải múi giờ IANA cho GIỜ TƯỜNG (thay `ZoneInfo` + fold=0 của Python)
    // ─────────────────────────────────────────────────────────────────────
    public static func zoneOffsetHours(ianaTZ: String, wall: CivilDateTime) -> Double? {
        guard let tz = TimeZone(identifier: ianaTZ) else { return nil }
        let wallEpoch = Double(wall.epochMicroseconds) / 1_000_000.0
        let offBefore = tz.secondsFromGMT(for: Date(timeIntervalSince1970: wallEpoch - 172_800))
        let offAfter  = tz.secondsFromGMT(for: Date(timeIntervalSince1970: wallEpoch + 172_800))
        var valid: [Int] = []
        for cand in Array(Set([offBefore, offAfter])) {
            let inst = wallEpoch - Double(cand)
            if tz.secondsFromGMT(for: Date(timeIntervalSince1970: inst)) == cand { valid.append(cand) }
        }
        let chosen: Int
        if valid.isEmpty {
            chosen = offBefore                       // rơi vào KHE NHẢY: PEP 495 fold=0 -> offset TRƯỚC chuyển
        } else if valid.count == 1 {
            chosen = valid[0]
        } else {
            chosen = valid.max()!                    // GIỜ NHẬP NHẰNG: fold=0 -> lần xuất hiện SỚM hơn = offset lớn hơn
        }
        return Double(chosen) / 3600.0
    }

    // ─────────────────────────────────────────────────────────────────────
    // 10/25  calculate_chart  — core.py:141-218   ★ HÀM TRUNG TÂM
    // ─────────────────────────────────────────────────────────────────────
    public static func calculateChart(dobStr: String, tobStr: String,
                                      lat: Double, lon: Double,
                                      tzStr: String? = nil,
                                      manualOffset: String? = nil) -> Chart? {
        guard let dtLocal = CivilDateTime.parseDMYHM(dob: dobStr, tob: tobStr) else {
            return nil                                        // tương ứng `except` bao ngoài của Python
        }

        // 1. TÌM MÚI GIỜ (OFFSET)  — core.py:146-170
        var finalOffset = 0.0
        var isManualValid = false
        if let mo = manualOffset, !mo.trimmingCharacters(in: .whitespaces).isEmpty {
            if let v = Double(mo.trimmingCharacters(in: .whitespaces)) {
                finalOffset = v; isManualValid = true
            } else {
                isManualValid = false
            }
        }
        if !isManualValid {
            if isCoordInVietnam(lat: lat, lon: lon) {
                finalOffset = getVietnamHistoricalOffset(year: dtLocal.year, month: dtLocal.month,
                                                         day: dtLocal.day, lat: lat, lon: lon)
            } else {
                var ianaTZ = tzStr
                if ianaTZ == nil || ianaTZ!.isEmpty || ianaTZ! == "UTC" {
                    ianaTZ = getTimezoneStr(lat: lat, lon: lon) ?? "UTC"
                }
                finalOffset = zoneOffsetHours(ianaTZ: ianaTZ!, wall: dtLocal) ?? 0.0
            }
        }

        // 2. ĐỔI SANG UTC VÀ TÍNH JULIAN DAY — core.py:173-174
        let dtUTC = dtLocal.minusHours(finalOffset)
        // ⚠️ GIỮ NGUYÊN: Python CHỈ lấy hour + minute/60 → GIÂY BỊ BỎ.
        let jd = SwissEph.julday(dtUTC.year, dtUTC.month, dtUTC.day,
                                 Double(dtUTC.hour) + Double(dtUTC.minute) / 60.0)

        // ⚠️ GIỮ NGUYÊN: core.py:176 gọi set_topo với tham số HOÁN ĐỔI và
        //    calc_ut KHÔNG dùng cờ TOPOCTR → lệnh này KHÔNG ảnh hưởng kết quả.
        SwissEph.setTopoAsWeb(lat: lat, lon: lon, alt: 0)

        // 3. THÔNG TIN KỸ THUẬT — core.py:179-191
        let gst = SwissEph.sidtime(jd)
        let lstHours = pmod(gst * 15 + lon, 360) / 15.0
        let hLST = Int(lstHours)
        let mLST = Int((lstHours - Double(hLST)) * 60)
        let lstStr = String(format: "%02d:%02d", hLST, mLST)

        let info = ChartTechnicalInfo(
            localTime: "\(dtLocal.dmyhm) (GMT\(pyFormatGPlus(finalOffset)))",
            utTime: dtUTC.dmyhm,
            lst: lstStr,
            latLon: "\(toDMS(lat, isLat: true)), \(toDMS(lon, isLat: false))",
            houseSys: "Placidus system"
        )

        // 4. TÍNH NHÀ VÀ HÀNH TINH — core.py:194-206
        let hr = SwissEph.houses(jd, lat, lon, "P")
        // ⚠️ GIỮ NGUYÊN: pyswisseph ném lỗi khi ret < 0 → Python trả về None (in "Error calculating chart").
        if hr.ret < 0 { return nil }
        let cusps = hr.cusps, ascmc = hr.ascmc
        let angles: [String: Double] = ["Asc": ascmc[0], "MC": ascmc[1], "Vertex": ascmc[3]]

        var planets: [String: PlanetPosition] = [:]
        var order: [String] = []
        for p in AstroConst.planetIDs {
            let res = SwissEph.calcUT(jd, p.id, SweFlag.swieph | SweFlag.speed)
            planets[p.name] = PlanetPosition(lon: res.xx[0], lat: res.xx[1], speed: res.xx[3])
            order.append(p.name)
        }
        planets["Vertex"] = PlanetPosition(lon: ascmc[3], lat: 0, speed: 0)
        planets["Asc"]    = PlanetPosition(lon: ascmc[0], lat: 0, speed: 0)
        planets["MC"]     = PlanetPosition(lon: ascmc[1], lat: 0, speed: 0)
        order.append(contentsOf: ["Vertex", "Asc", "MC"])

        return Chart(jd: jd, cusps: cusps, angles: angles,
                     planets: planets, planetOrder: order, info: info,
                     meta: ChartMeta(lat: lat, lon: lon, tz: tzStr, offsetUsed: finalOffset))
    }

    // ─────────────────────────────────────────────────────────────────────
    // 11/25  get_natal_planet_near_cusp  — core.py:221-238
    // ─────────────────────────────────────────────────────────────────────
    public static func getNatalPlanetNearCusp(chart: Chart, houseNum: Int) -> String? {
        let cusps = normalizedCusps(chart.cusps)
        let houseIdx = houseNum - 1
        let cStart = cusps[houseIdx]
        let cEnd = cusps[(houseIdx + 1) % 12]
        var bestP: String? = nil
        var minDist = 999.0
        // Python lặp theo thứ tự chèn của dict `planets`
        for pName in chart.planetOrder {
            guard AstroConst.corePlanets.contains(pName) else { continue }  // core.py:232
            guard let info = chart.planets[pName] else { continue }
            if isInHouseZone(info.lon, cStart, cEnd) {
                let dist = pmod(info.lon - cStart, 360)
                if dist < minDist { minDist = dist; bestP = pName }
            }
        }
        return bestP
    }

    // ─────────────────────────────────────────────────────────────────────
    // 12/25  get_house_ruler_planet  — core.py:241-247
    // ─────────────────────────────────────────────────────────────────────
    public static func getHouseRulerPlanet(chart: Chart, houseNum: Int) -> String? {
        let cusps = normalizedCusps(chart.cusps)
        let cLon = cusps[houseNum - 1]
        let z = getZodiac(cLon)
        return AstroConst.rulerMap[z.name]
    }

    /// `list(cusps_raw)[1:] if len(cusps_raw)==13 else list(cusps_raw)` — lặp lại nhiều nơi trong core.py
    @inline(__always) static func normalizedCusps(_ raw: [Double]) -> [Double] {
        return raw.count == 13 ? Array(raw.dropFirst()) : raw
    }

    // ─────────────────────────────────────────────────────────────────────
    // 13/25  get_p_pos  — core.py:250-264
    // ─────────────────────────────────────────────────────────────────────
    public static func getPPos(jd: Double, pName: String, lat: Double, lon: Double) -> Double {
        if pName == "South Node" {
            let res = SwissEph.calcUT(jd, SwePlanet.trueNode, SweFlag.swieph)
            return pmod(res.xx[0] + 180, 360)
        } else if pName == "Vertex" {
            let hr = SwissEph.houses(jd, lat, lon, "P")
            // Python bọc toàn hàm trong try/except và trả 0.0 khi swe.houses ném lỗi (core.py:263-265)
            if hr.ret < 0 { return 0.0 }
            return hr.ascmc[3]
        } else if let pid = AstroConst.planetIDMap[pName] {
            let res = SwissEph.calcUT(jd, pid, SweFlag.swieph)
            return res.xx[0]
        }
        return 0.0
    }

    // ─────────────────────────────────────────────────────────────────────
    // 14/25  _get_current_orb_strict  — core.py:267-270
    // ─────────────────────────────────────────────────────────────────────
    static func getCurrentOrbStrict(_ jd: Double, _ pTrans: String, _ pNatPos: Double,
                                    _ targetAngle: Double, _ lat: Double, _ lon: Double) -> Double {
        let pos = getPPos(jd: jd, pName: pTrans, lat: lat, lon: lon)
        let dist = abs(SwissEph.difdeg2n(pos, pNatPos))
        return abs(dist - targetAngle)
    }

    // ─────────────────────────────────────────────────────────────────────
    // 15/25  _find_boundary_strict  — core.py:273-287
    // ─────────────────────────────────────────────────────────────────────
    static func findBoundaryStrict(_ jdStart: Double, _ jdEnd: Double, _ pTrans: String,
                                   _ pNatPos: Double, _ targetAngle: Double,
                                   _ lat: Double, _ lon: Double) -> Double {
        var l = jdStart, r = jdEnd
        for _ in 0..<30 {
            let m = (l + r) / 2
            if getCurrentOrbStrict(m, pTrans, pNatPos, targetAngle, lat, lon) < 3.0 {
                if getCurrentOrbStrict(l, pTrans, pNatPos, targetAngle, lat, lon) >= 3.0 { r = m } else { l = m }
            } else {
                if getCurrentOrbStrict(l, pTrans, pNatPos, targetAngle, lat, lon) < 3.0 { r = m } else { l = m }
            }
        }
        return (l + r) / 2
    }

    // ─────────────────────────────────────────────────────────────────────
    // 16/25  _find_hits_strict  — core.py:290-313
    // ─────────────────────────────────────────────────────────────────────
    static func findHitsStrict(_ jdS: Double, _ jdE: Double, _ pTrans: String,
                               _ pNatPos: Double, _ targetAngle: Double,
                               _ lat: Double, _ lon: Double) -> [Double] {
        var hits: [Double] = []
        let t1Deg = pmod(pNatPos + targetAngle, 360)
        let t2Deg = pmod(pNatPos - targetAngle, 360)
        let posStart = getPPos(jd: jdS, pName: pTrans, lat: lat, lon: lon)
        let activeTarget = abs(SwissEph.difdeg2n(posStart, t1Deg)) < abs(SwissEph.difdeg2n(posStart, t2Deg))
            ? t1Deg : t2Deg
        let steps = 200
        let stepSize = (jdE - jdS) / Double(steps)
        func getRel(_ t: Double) -> Double {
            return SwissEph.difdeg2n(getPPos(jd: t, pName: pTrans, lat: lat, lon: lon), activeTarget)
        }
        for i in 0..<steps {
            let t1 = jdS + Double(i) * stepSize
            let t2 = jdS + Double(i + 1) * stepSize
            let r1 = getRel(t1), r2 = getRel(t2)
            if r1 * r2 <= 0 {
                var ml = t1, mr = t2
                for _ in 0..<30 {
                    let mm = (ml + mr) / 2
                    if r1 * getRel(mm) <= 0 { mr = mm } else { ml = mm }
                }
                hits.append((ml + mr) / 2)
            }
        }
        return hits
    }

    /// `fmt(jd_val)` lồng trong 3 hàm dò thời điểm — core.py:350-354, 406-410, 464-468 (giống hệt nhau)
    static func fmtJD(_ jdVal: Double, lat: Double, lon: Double) -> TimeStamp {
        let r = SwissEph.revjul(jdVal)
        let off = isCoordInVietnam(lat: lat, lon: lon)
            ? getVietnamHistoricalOffset(year: r.year, month: r.month, day: r.day, lat: lat, lon: lon)
            : 0.0
        let base = CivilDateTime(year: r.year, month: r.month, day: r.day)
        let dt = base.plusSeconds(pyRoundInt((r.hour + off) * 3600))
        return TimeStamp(d: dt.dmy, t: dt.hms)
    }

    // ─────────────────────────────────────────────────────────────────────
    // 17/25  find_exact_aspect_times  — core.py:316-373
    // (BẢN REPO: có thêm tham số `end_date_str`; bản local KHÔNG có)
    // ─────────────────────────────────────────────────────────────────────
    public static func findExactAspectTimes(pTrans: String, pNatal: String, aspectName: String,
                                            startDateStr: String, natalChart: Chart,
                                            endDateStr: String? = nil) -> [AspectPeriod] {
        let lat = natalChart.meta.lat
        let lon = natalChart.meta.lon
        guard let aspDef = AstroConst.aspectByName[aspectName] else { return [] }
        let targetAngle = aspDef.angle
        let nLon: Double
        if pNatal == "South Node" {
            nLon = pmod((natalChart.planets["True Node"]?.lon ?? 0) + 180, 360)
        } else {
            nLon = natalChart.planets[pNatal]?.lon ?? 0
        }
        guard let dtS = CivilDateTime.parseDMY(startDateStr) else { return [] }
        var jdCurr = SwissEph.julday(dtS.year, dtS.month, dtS.day, 0)

        // Giới hạn quét — core.py:328-341
        var limitJD: Double
        if let eds = endDateStr, let dtE = CivilDateTime.parseDMY(eds) {
            limitJD = SwissEph.julday(dtE.year, dtE.month, dtE.day, 0) + 20.0
        } else if endDateStr != nil {
            limitJD = jdCurr + 365.0                       // nhánh `except` của Python
        } else {
            let limitDays: Double
            if ["Moon", "Vertex"].contains(pTrans) { limitDays = 365 }
            else if ["Sun", "Mercury", "Venus", "Mars"].contains(pTrans) { limitDays = 3650 }
            else { limitDays = 36525 }
            limitJD = jdCurr + limitDays
        }
        // Bước quét — core.py:344-346
        let step: Double
        if ["Moon", "Vertex"].contains(pTrans) { step = 0.02 }
        else if ["Sun", "Mercury", "Venus", "Mars"].contains(pTrans) { step = 0.1 }
        else { step = 1.0 }

        var results: [AspectPeriod] = []
        while jdCurr < limitJD && results.count < 5 {
            if getCurrentOrbStrict(jdCurr, pTrans, nLon, targetAngle, lat, lon) < 3.0 {
                var jdBack = jdCurr
                while getCurrentOrbStrict(jdBack, pTrans, nLon, targetAngle, lat, lon) < 3.0 {
                    jdBack -= step
                }
                let startJD = findBoundaryStrict(jdBack, jdBack + step, pTrans, nLon, targetAngle, lat, lon)

                var jdFwd = jdCurr
                while jdFwd < limitJD && getCurrentOrbStrict(jdFwd, pTrans, nLon, targetAngle, lat, lon) < 3.0 {
                    jdFwd += step
                }
                let endJD = findBoundaryStrict(jdFwd - step, jdFwd, pTrans, nLon, targetAngle, lat, lon)

                let hits = findHitsStrict(startJD, endJD, pTrans, nLon, targetAngle, lat, lon)
                    .map { fmtJD($0, lat: lat, lon: lon) }
                results.append(AspectPeriod(start: fmtJD(startJD, lat: lat, lon: lon),
                                            end: fmtJD(endJD, lat: lat, lon: lon),
                                            exactHits: hits))
                jdCurr = endJD + (step / 2)
            } else {
                jdCurr += step
            }
        }
        return results
    }

    // ─────────────────────────────────────────────────────────────────────
    // 18/25  is_in_house_zone  — core.py:376-381
    // ─────────────────────────────────────────────────────────────────────
    public static func isInHouseZone(_ lonIn: Double, _ cuspStart: Double, _ cuspEnd: Double) -> Bool {
        let lon = pmod(lonIn, 360)
        if cuspStart < cuspEnd {
            return cuspStart <= lon && lon < cuspEnd
        } else {
            return lon >= cuspStart || lon < cuspEnd
        }
    }

    // ─────────────────────────────────────────────────────────────────────
    // 19/25  find_return_times  — core.py:384-440
    // ─────────────────────────────────────────────────────────────────────
    public static func findReturnTimes(pName: String, startDateStr: String,
                                       natalChart: Chart) -> [ReturnPeriod] {
        let lat = natalChart.meta.lat, lon = natalChart.meta.lon
        let cusps = normalizedCusps(natalChart.cusps)
        let nLon = natalChart.planets[pName]?.lon ?? 0
        var targetHouseIdx = -1
        for i in 0..<12 {
            if isInHouseZone(nLon, cusps[i], cusps[(i + 1) % 12]) { targetHouseIdx = i; break }
        }
        // ⚠️ GIỮ NGUYÊN: nếu không tìm được nhà, Python dùng chỉ số ÂM (-1) = phần tử cuối.
        let cStart = pyIndex(cusps, targetHouseIdx)
        let cEnd = cusps[pmodInt(targetHouseIdx + 1, 12)]

        let step: Double, limitDays: Double
        if pName == "Moon" { step = 0.05; limitDays = 365 }
        else if ["Sun", "Mercury", "Venus", "Mars"].contains(pName) { step = 0.2; limitDays = 3650 }
        else if ["Jupiter", "Saturn", "Chiron"].contains(pName) { step = 1.0; limitDays = 36525 }
        else { step = 2.0; limitDays = 146100 }

        guard let dtS = CivilDateTime.parseDMY(startDateStr) else { return [] }
        var jdCurr = SwissEph.julday(dtS.year, dtS.month, dtS.day, 0)
        let limitJD = jdCurr + limitDays
        var results: [ReturnPeriod] = []

        while jdCurr < limitJD && results.count < 10 {
            if isInHouseZone(getPPos(jd: jdCurr, pName: pName, lat: lat, lon: lon), cStart, cEnd) {
                var jdBack = jdCurr
                let backLimit = jdCurr - limitDays
                while isInHouseZone(getPPos(jd: jdBack, pName: pName, lat: lat, lon: lon), cStart, cEnd)
                        && jdBack > backLimit {
                    jdBack -= step
                }
                var bl = jdBack, br = jdBack + step
                for _ in 0..<25 {
                    let bm = (bl + br) / 2
                    if isInHouseZone(getPPos(jd: bm, pName: pName, lat: lat, lon: lon), cStart, cEnd) { br = bm }
                    else { bl = bm }
                }
                let startJD = br

                var jdFwd = jdCurr
                while jdFwd < limitJD
                        && isInHouseZone(getPPos(jd: jdFwd, pName: pName, lat: lat, lon: lon), cStart, cEnd) {
                    jdFwd += step
                }
                var el = jdFwd - step, er = jdFwd
                for _ in 0..<25 {
                    let em = (el + er) / 2
                    if isInHouseZone(getPPos(jd: em, pName: pName, lat: lat, lon: lon), cStart, cEnd) { el = em }
                    else { er = em }
                }
                let endJD = el

                let hits = findHitsStrict(startJD, endJD, pName, nLon, 0, lat, lon)
                    .map { fmtJD($0, lat: lat, lon: lon) }
                results.append(ReturnPeriod(house: targetHouseIdx + 1,
                                            start: fmtJD(startJD, lat: lat, lon: lon),
                                            end: fmtJD(endJD, lat: lat, lon: lon),
                                            exactHits: hits))
                jdCurr = endJD + (step / 2)
            } else {
                jdCurr += step
            }
        }
        return results
    }

    // ─────────────────────────────────────────────────────────────────────
    // 20/25  find_current_house_transit_period  — core.py:443-490
    // ─────────────────────────────────────────────────────────────────────
    public static func findCurrentHouseTransitPeriod(pName: String, natalChart: Chart,
                                                     d: Int? = nil, m: Int? = nil, y: Int? = nil,
                                                     nowUTCOverride: CivilDateTime? = nil) -> HouseTransitPeriod? {
        let lat = natalChart.meta.lat, lon = natalChart.meta.lon
        let cusps = normalizedCusps(natalChart.cusps)
        let nowUTC = nowUTCOverride ?? currentUTC()
        let tD = d ?? nowUTC.day, tM = m ?? nowUTC.month, tY = y ?? nowUTC.year
        let jdNow = SwissEph.julday(tY, tM, tD, Double(nowUTC.hour) + Double(nowUTC.minute) / 60.0)
        let posNow = getPPos(jd: jdNow, pName: pName, lat: lat, lon: lon)
        var houseIdx = -1
        for i in 0..<12 {
            if isInHouseZone(posNow, cusps[i], cusps[(i + 1) % 12]) { houseIdx = i; break }
        }
        if houseIdx == -1 { return nil }
        let cStart = cusps[houseIdx], cEnd = cusps[(houseIdx + 1) % 12]

        let step: Double, scanLimit: Double
        if pName == "Moon" { step = 0.05; scanLimit = 365 }
        else if ["Sun", "Mercury", "Venus", "Mars"].contains(pName) { step = 0.2; scanLimit = 3650 }
        else if ["Jupiter", "Saturn", "Chiron"].contains(pName) { step = 1.0; scanLimit = 36525 }
        else { step = 2.0; scanLimit = 146100 }

        var jdBack = jdNow
        let backLimit = jdNow - scanLimit
        while isInHouseZone(getPPos(jd: jdBack, pName: pName, lat: lat, lon: lon), cStart, cEnd)
                && jdBack > backLimit {
            jdBack -= step
        }
        var bl = jdBack, br = jdBack + step
        for _ in 0..<25 {
            let bm = (bl + br) / 2
            if isInHouseZone(getPPos(jd: bm, pName: pName, lat: lat, lon: lon), cStart, cEnd) { br = bm } else { bl = bm }
        }
        let startJD = br

        var jdFwd = jdNow
        let fwdLimit = jdNow + scanLimit
        while isInHouseZone(getPPos(jd: jdFwd, pName: pName, lat: lat, lon: lon), cStart, cEnd)
                && jdFwd < fwdLimit {
            jdFwd += step
        }
        var el = jdFwd - step, er = jdFwd
        for _ in 0..<25 {
            let em = (el + er) / 2
            if isInHouseZone(getPPos(jd: em, pName: pName, lat: lat, lon: lon), cStart, cEnd) { el = em } else { er = em }
        }
        return HouseTransitPeriod(house: houseIdx + 1,
                                  start: fmtJD(startJD, lat: lat, lon: lon),
                                  end: fmtJD(el, lat: lat, lon: lon))
    }

    /// `datetime.now(pytz.utc)` — core.py:429
    public static func currentUTC() -> CivilDateTime {
        let us = Int((Date().timeIntervalSince1970 * 1_000_000).rounded())
        return CivilDateTime(epochMicroseconds: us)
    }

    // ─────────────────────────────────────────────────────────────────────
    // 21/25  scan_house_transits_in_range  — core.py:493-550
    // (CHỈ CÓ TRONG BẢN REPO — bản local thiếu hàm này)
    // ─────────────────────────────────────────────────────────────────────
    public static func scanHouseTransitsInRange(pName: String, natalChart: Chart,
                                                startDate: CivilDateTime,
                                                endDate: CivilDateTime) -> [HouseInterval] {
        var intervals: [HouseInterval] = []
        let lat = natalChart.meta.lat, lon = natalChart.meta.lon
        let cusps = normalizedCusps(natalChart.cusps)

        func getH(_ dObj: CivilDateTime) -> Int {
            let jd = SwissEph.julday(dObj.year, dObj.month, dObj.day, 12.0)   // giữa trưa
            let pos = getPPos(jd: jd, pName: pName, lat: lat, lon: lon)
            for i in 0..<12 {
                if isInHouseZone(pos, cusps[i], cusps[(i + 1) % 12]) { return i + 1 }
            }
            return -1
        }

        var curr = startDate
        var current: HouseInterval? = nil
        while curr.epochMicroseconds <= endDate.epochMicroseconds {
            let hToday = getH(curr)
            if current == nil {
                current = HouseInterval(house: hToday, start: curr, end: curr,
                                        clampedStart: true, clampedEnd: true)
            } else if hToday == current!.house {
                current!.end = curr
            } else {
                current!.clampedEnd = false          // đổi nhà = kết thúc thật
                intervals.append(current!)
                current = HouseInterval(house: hToday, start: curr, end: curr,
                                        clampedStart: false, clampedEnd: true)
            }
            curr = curr.plusDays(1)
        }
        if var c = current {
            c.clampedEnd = true                       // kết thúc do hết khoảng xem
            intervals.append(c)
        }
        return intervals
    }

    // ─────────────────────────────────────────────────────────────────────
    // 22/25  format_coord_astro  — core.py:553-558
    // ─────────────────────────────────────────────────────────────────────
    public static func formatCoordAstro(_ val: Double, isLat: Bool = true) -> String {
        let vAbs = abs(val)
        let d = Int(vAbs)
        let m = Int((vAbs - Double(d)) * 60)
        let suffix = isLat ? (val >= 0 ? "n" : "s") : (val >= 0 ? "e" : "w")
        return "\(d)\(suffix)\(String(format: "%02d", m))"
    }

    // ─────────────────────────────────────────────────────────────────────
    // 23/25  format_coord_astro_pair  — core.py:561-562
    // ─────────────────────────────────────────────────────────────────────
    public static func formatCoordAstroPair(lat: Double, lon: Double) -> String {
        return "\(formatCoordAstro(lat, isLat: true)), \(formatCoordAstro(lon, isLat: false))"
    }

    // ─────────────────────────────────────────────────────────────────────
    // 24/25  hash_password  — core.py:565-567  (SHA-256 hex)
    // ─────────────────────────────────────────────────────────────────────
    public static func hashPassword(_ password: String) -> String {
        let digest = SHA256.hash(data: Data(password.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    // ─────────────────────────────────────────────────────────────────────
    // 25/25  check_password_strength  — core.py:570-571
    // ─────────────────────────────────────────────────────────────────────
    public static func checkPasswordStrength(_ password: String) -> Bool {
        return password.count >= 6
    }
}
