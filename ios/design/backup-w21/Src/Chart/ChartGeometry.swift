//  ChartGeometry.swift
//  HÌNH HỌC THUẦN của bánh xe chiêm tinh — port 1-1 từ matplotlib phía web.
//  KHÔNG import SwiftUI: file này phải biên dịch được trong harness CLI macOS
//  để đối chiếu từng con số với Python.
//
//  NGUỒN (repo `git@github.com:hentaiikidd/chiemtinh.git`, HEAD 73e2e63):
//    · app/utils/drawing/natal.py:96-99      -> set_theta_zero_location('E'), set_theta_direction(1)
//    · app/utils/drawing/natal.py:110-118    -> set_theta_offset(deg2rad(180 - asc))
//    · app/utils/drawing/natal.py:120-121    -> R0/R_CENTER_DOT/R_INNER_RING/R_ASPECT_TIP/R_MID/R_PLANET
//    · app/utils/drawing/natal.py:83-84      -> R_ZODIAC_OUTER = 9.5, R_OUTER = 11.5
//    · app/utils/drawing/natal.py:132        -> vành zodiac 8.15 .. 9.35
//    · app/utils/drawing/natal.py:173        -> lanes_natal = [7.3, 6.2]
//    · app/utils/drawing/synastry.py:29-30   -> R_CENTER 4.0 / R_A_OUT 6.0 / R_B_OUT 8.0
//    · app/utils/drawing/synastry.py:90,108  -> lanes_A = [5.4, 4.6], lanes_B = [7.4, 6.6]
//    · app/utils/drawing/helpers.py:13-107   -> optimize_planet_positions_by_house
//    · app/utils/drawing/helpers.py:110-142  -> draw_spindle
//    · app/utils/drawing/natal.py:15-33      -> check_arc_collision

import Foundation
import CoreGraphics

// MARK: - Hằng số bán kính (đơn vị "chart unit", y hệt matplotlib)

/// Bánh xe natal (dùng chung cho composite — web cũng gọi lại `create_natal_chart_image`,
/// xem `app/routes/charts.py:170`).
public enum NatalRing {
    public static let center: Double        = 0.0    // natal.py:120
    public static let centerDot: Double     = 0.05   // natal.py:120
    public static let innerRing: Double     = 1.4    // natal.py:120
    public static let aspectTip: Double     = 5.25   // natal.py:121
    public static let mid: Double           = 5.5    // natal.py:121
    public static let planet: Double        = 8.0    // natal.py:121
    public static let zodiacInner: Double   = 8.0    // natal.py:122
    public static let zodiacBandIn: Double  = 8.15   // natal.py:132
    public static let zodiacBandOut: Double = 9.35   // natal.py:132
    public static let zodiacOuter: Double   = 9.5    // natal.py:83
    public static let outer: Double         = 11.5   // natal.py:84
    /// natal.py:173 — lane ngoài trước, lane trong sau.
    public static let lanes: [Double]       = [7.3, 6.2]
    /// natal.py:190-191 — vạch tick tại vị trí THẬT, dài 0.2 vào phía trong.
    public static let tickLen: Double       = 0.2
}

/// Bánh xe synastry 2 vòng.
public enum SynastryRing {
    public static let center: Double        = 4.0    // synastry.py:29
    public static let aOut: Double          = 6.0    // synastry.py:29
    public static let bOut: Double          = 8.0    // synastry.py:29
    public static let zodiacBandIn: Double  = 8.15   // synastry.py:47
    public static let zodiacBandOut: Double = 9.35   // synastry.py:47
    public static let zodiacOuter: Double   = 9.5    // synastry.py:30
    public static let outer: Double         = 11.5   // synastry.py:30
    public static let lanesA: [Double]      = [5.4, 4.6]   // synastry.py:90
    public static let lanesB: [Double]      = [7.4, 6.6]   // synastry.py:108
    public static let tickLen: Double       = 0.1    // synastry.py:96-97, 115-116
}

/// Tham số chống chồng lấn — `helpers.py:38-39`.
public enum LayoutConst {
    public static let buffer: Double   = 2.0
    public static let minDist: Double  = 5.0
}

// MARK: - Phép biến đổi toạ độ

/// Ánh xạ (kinh độ hoàng đạo, bán kính chart-unit) -> điểm màn hình.
///
/// matplotlib: `theta_zero_location('E')` + `theta_direction(1)` (ngược chiều kim đồng hồ)
/// + `theta_offset = deg2rad(180 - asc)`  →  góc vẽ α = lon + 180 − asc (độ), đo NGƯỢC
/// chiều kim đồng hồ từ hướng 3 giờ. Toạ độ màn hình có trục y hướng xuống nên y bị lật dấu.
public struct WheelTransform {
    public let center: CGPoint
    /// Số điểm (pt) trên 1 đơn vị bán kính chart.
    public let unit: CGFloat
    /// Kinh độ Ascendant (độ). Với chế độ "Aries tĩnh" truyền 0 — `natal.py:110-116`.
    public let ascDeg: Double

    public init(center: CGPoint, unit: CGFloat, ascDeg: Double) {
        self.center = center
        self.unit = unit
        self.ascDeg = ascDeg
    }

    /// Góc vẽ (radian) của một kinh độ hoàng đạo.
    @inline(__always)
    public func angle(_ lonDeg: Double) -> Double {
        (lonDeg + 180.0 - ascDeg) * .pi / 180.0
    }

    /// Góc vẽ chuẩn hoá về [0, 360) độ — dùng khi đối chiếu số với Python.
    @inline(__always)
    public static func thetaDeg(lon: Double, asc: Double) -> Double {
        var v = (lon + 180.0 - asc).truncatingRemainder(dividingBy: 360.0)
        if v < 0 { v += 360.0 }
        return v
    }

    @inline(__always)
    public func point(lon: Double, r: Double) -> CGPoint { point(angle: angle(lon), r: r) }

    @inline(__always)
    public func point(angle a: Double, r: Double) -> CGPoint {
        CGPoint(x: center.x + CGFloat(cos(a) * r) * unit,
                y: center.y - CGFloat(sin(a) * r) * unit)
    }

    /// Điểm trong "chart-space" (Descartes, y hướng lên, gốc ở tâm) -> màn hình.
    @inline(__always)
    public func point(chart p: CGPoint) -> CGPoint {
        CGPoint(x: center.x + p.x * unit, y: center.y - p.y * unit)
    }

    /// Nghịch đảo — phục vụ bắt chạm: điểm màn hình -> (kinh độ, bán kính chart-unit).
    public func inverse(_ p: CGPoint) -> (lon: Double, r: Double) {
        let dx = Double(p.x - center.x) / Double(unit)
        let dy = Double(center.y - p.y) / Double(unit)
        let r = (dx * dx + dy * dy).squareRoot()
        var a = atan2(dy, dx) * 180.0 / .pi          // = lon + 180 - asc
        a = (a - 180.0 + ascDeg).truncatingRemainder(dividingBy: 360.0)
        if a < 0 { a += 360.0 }
        return (a, r)
    }
}

// MARK: - Tiện ích góc

@inline(__always)
public func normDeg(_ v: Double) -> Double {
    var x = v.truncatingRemainder(dividingBy: 360.0)
    if x < 0 { x += 360.0 }
    return x
}

/// Khoảng cách góc tuyệt đối nhỏ nhất giữa 2 kinh độ (0…180).
@inline(__always)
public func angularGap(_ a: Double, _ b: Double) -> Double {
    var d = abs(normDeg(a) - normDeg(b))
    if d > 180 { d = 360 - d }
    return d
}

// MARK: - Chống chồng lấn ký hiệu hành tinh

public struct PlanetGlyphInput {
    public let name: String
    public let lon: Double
    public let symbol: String
    public init(name: String, lon: Double, symbol: String) {
        self.name = name; self.lon = lon; self.symbol = symbol
    }
}

public struct PlacedPlanet {
    public let name: String
    public let symbol: String
    /// Kinh độ THẬT (vẽ vạch tick).
    public let lon: Double
    /// Kinh độ HIỂN THỊ sau khi giãn cách (vẽ ký hiệu).
    public let dispLon: Double
    /// Bán kính lane hiển thị.
    public let dispR: Double
    /// Nhà chứa hành tinh, 0-based theo mảng cusps truyền vào.
    public let houseIndex: Int
}

/// Port 1-1 `helpers.py:13` `optimize_planet_positions_by_house`.
/// Giữ nguyên: gom theo nhà → sắp theo vị trí tương đối (sort ỔN ĐỊNH như Python)
/// → chia 2 lane xen kẽ chẵn/lẻ → forward pass (đẩy ra) → backward pass (kéo lại).
/// Thứ tự phần tử trả về cũng khớp Python: theo nhà 0…11, trong nhà theo lane 0 rồi lane 1.
public func optimizePlanetPositionsByHouse(_ planets: [PlanetGlyphInput],
                                           cusps: [Double],
                                           lanes: [Double]) -> [PlacedPlanet] {
    if planets.isEmpty { return [] }
    var realCusps = cusps
    if realCusps.count == 13 { realCusps = Array(realCusps.dropFirst()) }   // helpers.py:19
    guard realCusps.count == 12, !lanes.isEmpty else { return [] }

    // helpers.py:21-32 — gom hành tinh theo nhà
    var houseGroups: [[PlanetGlyphInput]] = Array(repeating: [], count: 12)
    for p in planets {
        var hIdx = -1
        for i in 0..<12 {
            let cCurr = realCusps[i]
            let cNext = realCusps[(i + 1) % 12]
            let distP = normDeg(p.lon - cCurr)
            let sizeH = normDeg(cNext - cCurr)
            if distP < sizeH { hIdx = i; break }
        }
        if hIdx != -1 { houseGroups[hIdx].append(p) }
    }

    var result: [PlacedPlanet] = []

    for hIdx in 0..<12 {
        let rawGroup = houseGroups[hIdx]
        if rawGroup.isEmpty { continue }                       // helpers.py:43

        let cStart = realCusps[hIdx]
        func relPos(_ lon: Double) -> Double { normDeg(lon - cStart) }

        // helpers.py:50 — Python `list.sort` ỔN ĐỊNH; Swift `sorted` KHÔNG,
        // nên kèm chỉ số gốc làm khoá phụ để kết quả trùng khít.
        let group = rawGroup.enumerated()
            .sorted { a, b in
                let ra = relPos(a.element.lon), rb = relPos(b.element.lon)
                return ra == rb ? a.offset < b.offset : ra < rb
            }
            .map { $0.element }

        let cEnd = realCusps[(hIdx + 1) % 12]
        let houseWidth = normDeg(cEnd - cStart)                 // helpers.py:53

        // helpers.py:55-63 — chia lane xen kẽ
        var laneSub: [[Int]] = [[], []]                          // chỉ số trong `group`
        var dispR = [Double](repeating: lanes[0], count: group.count)
        for idx in 0..<group.count {
            var targetLane = (idx % 2 == 0) ? 0 : 1
            if targetLane >= lanes.count { targetLane = 0 }
            laneSub[targetLane].append(idx)
            dispR[idx] = lanes[targetLane]
        }

        for lIdx in 0..<2 {                                      // helpers.py:65 (dict {0:…,1:…})
            let sub = laneSub[lIdx]
            if sub.isEmpty { continue }

            var vals = sub.map { relPos(group[$0].lon) }          // helpers.py:69-73

            // Forward pass — helpers.py:75-82
            for i in 0..<vals.count {
                if i == 0 {
                    if vals[i] < LayoutConst.buffer { vals[i] = LayoutConst.buffer }
                } else if vals[i] < vals[i - 1] + LayoutConst.minDist {
                    vals[i] = vals[i - 1] + LayoutConst.minDist
                }
            }

            // Backward pass — helpers.py:84-92
            var i = vals.count - 1
            while i >= 0 {
                let limit = houseWidth - LayoutConst.buffer
                if vals[i] > limit { vals[i] = limit }
                if i < vals.count - 1, vals[i] > vals[i + 1] - LayoutConst.minDist {
                    vals[i] = vals[i + 1] - LayoutConst.minDist
                }
                i -= 1
            }

            // helpers.py:94-98
            for (k, gIdx) in sub.enumerated() {
                let p = group[gIdx]
                result.append(PlacedPlanet(name: p.name, symbol: p.symbol, lon: p.lon,
                                           dispLon: normDeg(cStart + vals[k]),
                                           dispR: dispR[gIdx], houseIndex: hIdx))
            }
        }
    }
    return result
}

// MARK: - Hình thoi "thanh kiếm" cho đường góc chiếu

/// Port `helpers.py:110` `draw_spindle` — trả về 6 đỉnh trong chart-space (Descartes).
/// matplotlib dựng đỉnh bằng toạ độ Descartes rồi mới đổi sang cực; vì phép chiếu ra
/// màn hình là tuyến tính nên dựng thẳng trong Descartes cho hình dạng y hệt.
public func spindleVertices(angle1: Double, angle2: Double, radius: Double,
                            maxWidth: Double, orbRatio: Double) -> [CGPoint] {
    let x1 = radius * cos(angle1), y1 = radius * sin(angle1)
    let x2 = radius * cos(angle2), y2 = radius * sin(angle2)
    let dx = x2 - x1, dy = y2 - y1
    let length = (dx * dx + dy * dy).squareRoot()
    if length == 0 { return [] }                                  // helpers.py:120
    let nx = -dy / length, ny = dx / length
    let width = maxWidth * (0.3 + 0.7 * orbRatio)                 // helpers.py:125
    let halfW = width / 2.0
    let taper = 0.05                                              // helpers.py:127

    let xt1 = x1 + dx * taper, yt1 = y1 + dy * taper
    let xt2 = x2 - dx * taper, yt2 = y2 - dy * taper

    return [
        CGPoint(x: x1, y: y1),
        CGPoint(x: xt1 + nx * halfW, y: yt1 + ny * halfW),
        CGPoint(x: xt2 + nx * halfW, y: yt2 + ny * halfW),
        CGPoint(x: x2, y: y2),
        CGPoint(x: xt2 - nx * halfW, y: yt2 - ny * halfW),
        CGPoint(x: xt1 - nx * halfW, y: yt1 - ny * halfW)
    ]
}

// MARK: - Va chạm cung (dùng cho vòng transit đại hạn)

/// Port `natal.py:15-33` `check_arc_collision`.
public func checkArcCollision(_ a: (start: Double, end: Double),
                              _ b: (start: Double, end: Double),
                              buffer: Double = 2.0) -> Bool {
    func isInArc(_ p: Double, _ s: Double, _ e: Double) -> Bool {
        let pp = normDeg(p)
        if s <= e { return s <= pp && pp <= e }
        return pp >= s || pp <= e
    }
    let s1buf = normDeg(a.start - buffer)
    let e1buf = normDeg(a.end + buffer)
    if isInArc(b.start, s1buf, e1buf) || isInArc(b.end, s1buf, e1buf) { return true }
    if isInArc(s1buf, b.start, b.end) || isInArc(e1buf, b.start, b.end) { return true }
    return false
}
