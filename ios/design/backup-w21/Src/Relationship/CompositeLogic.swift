//  CompositeLogic.swift
//  PORT 1-1 từ `app/astro00_lib/composite_logic.py` (81 dòng) — repo HEAD 73e2e63.
//
//  NGUYÊN TẮC: GIỮ NGUYÊN HÀNH VI, KỂ CẢ CHỖ TRÔNG NHƯ SAI.
//  KHÔNG tự tính chart — chỉ lấy trung điểm từ 2 `Chart` do `AstroCore.calculateChart` sinh.

import Foundation

/// Kết quả composite.
///
/// Python trả về một dict "y hệt cấu trúc Natal Chart để tái sử dụng hàm vẽ"
/// (composite_logic.py:14-17), trong đó `cusps` có **13 phần tử** — phần tử [0]
/// là số 0.0 giả để hỗ trợ chỉ số 1-based (composite_logic.py:71).
///
/// Bản Swift trả về đồng thời:
/// - `chart`: kiểu `Chart` chuẩn của `Src/Core` (cusps **12 phần tử**, giống
///   `calculateChart`) → dùng lại được mọi hàm sẵn có (`getHouseOfPlanet`, view của W18…).
/// - `cuspsPython`: mảng **13 phần tử** y hệt Python → dùng để đối chiếu parity.
///
/// `AstroCore.getHouseOfPlanet` chấp nhận cả 12 lẫn 13 phần tử (AstroCore.swift:136-138)
/// nên hai đường đều cho cùng số nhà.
public struct CompositeChart {
    public var chart: Chart
    public var cuspsPython: [Double]
}

public enum CompositeLogic {

    // ═══════════════════════════════════════════════════════════════════
    // get_midpoint — composite_logic.py:1-11
    // "Tính trung điểm của cung ngắn nhất giữa 2 góc."
    // ═══════════════════════════════════════════════════════════════════
    public static func getMidpoint(_ lon1: Double, _ lon2: Double) -> Double {
        let diff = abs(lon1 - lon2)          // py:3
        var mid = (lon1 + lon2) / 2.0        // py:4

        // py:6-9 — ⚠️ GIỮ NGUYÊN: dùng `abs(lon1-lon2)` THÔ, không gập về [0,180].
        // Với lon trong [0,360) thì diff ∈ [0,360) nên nhánh này đúng ý đồ;
        // nhưng nếu ai truyền lon ngoài [0,360) thì kết quả sẽ khác — web đang vậy.
        if diff > 180 { mid += 180.0 }

        return pmod(mid, 360.0)              // py:11 — `%` của Python luôn ra dấu dương
    }

    // ═══════════════════════════════════════════════════════════════════
    // calculate_composite_chart — composite_logic.py:13-81
    // ═══════════════════════════════════════════════════════════════════
    public static func calculateCompositeChart(_ cA: Chart, _ cB: Chart) -> CompositeChart? {
        // py:18 — `if not cA or not cB: return None`. Chart là struct non-optional ở Swift
        // nên điều kiện này đã được đảm bảo bởi kiểu; tầng gọi tự kiểm nil trước.

        // py:20-33 — khung dữ liệu composite
        var planets: [String: PlanetPosition] = [:]
        var order: [String] = []

        // ═══ 1. Midpoint Planets — py:35-51 ═══
        // ⚠️ KHÁC BIỆT CÓ CHỦ Ý (chỉ về THỨ TỰ, không về GIÁ TRỊ):
        // Python dùng `set(cA) | set(cB)` (py:36) → thứ tự duyệt của set là KHÔNG
        // XÁC ĐỊNH giữa các lần chạy. Swift dùng thứ tự chèn của `cA.planetOrder`
        // rồi bổ sung phần chỉ có ở B, cho kết quả TẤT ĐỊNH.
        // Thứ tự này KHÔNG ảnh hưởng bất kỳ con số nào: mọi hàm tiêu thụ đều duyệt
        // theo danh sách tên tường minh, hoặc chỉ cộng dồn (giao hoán).
        var allPlanets: [String] = cA.planetOrder
        for p in cB.planetOrder where !allPlanets.contains(p) { allPlanets.append(p) }

        for p in allPlanets {
            // py:38
            guard let a = cA.planets[p], let b = cB.planets[p] else { continue }
            let midLon = getMidpoint(a.lon, b.lon)               // py:39-41

            // py:43-45 — tốc độ lấy trung bình. `.get("speed", 0)` luôn có ở bản Swift.
            let speed1 = a.speed
            let speed2 = b.speed

            // py:47-51 — LƯU Ý: `lat` bị ép về 0, KHÔNG lấy trung bình.
            planets[p] = PlanetPosition(lon: midLon, lat: 0, speed: (speed1 + speed2) / 2)
            order.append(p)
        }

        // ═══ 2. Midpoint Angles (Asc, MC, Vertex) — py:53-61 ═══
        var angles: [String: Double] = [:]
        for angle in ["Asc", "MC", "Vertex"] {                   // py:54
            guard let a1 = cA.angles[angle], let a2 = cB.angles[angle] else { continue }  // py:55
            let midA = getMidpoint(a1, a2)                       // py:58
            angles[angle] = midA                                 // py:59

            // py:60-61 — ⚠️ GIỮ NGUYÊN: GHI ĐÈ lên mục đã tạo ở bước 1.
            // Asc/MC/Vertex đã có trong `planets` (bước 1 đã tính trung điểm + speed trung bình),
            // ở đây bị ghi đè lại với **speed = 0**. Giá trị `lon` giống hệt.
            // Bản gốc làm vậy để "hàm vẽ hiển thị được AC/MC" → giữ nguyên.
            if planets[angle] == nil { order.append(angle) }
            planets[angle] = PlanetPosition(lon: midA, lat: 0, speed: 0)
        }

        // ═══ 3. Midpoint Cusps (1-12) — py:63-79 ═══
        let cuspsA = cA.cusps                                    // py:64
        let cuspsB = cB.cusps                                    // py:65

        // py:67-68 — bỏ phần tử giả nếu mảng có 13 phần tử.
        let realCuspsA = cuspsA.count == 13 ? Array(cuspsA.dropFirst()) : cuspsA
        let realCuspsB = cuspsB.count == 13 ? Array(cuspsB.dropFirst()) : cuspsB

        // py:70-77 — mảng bắt đầu bằng 0.0 giả để hỗ trợ chỉ số 1-based
        var compCuspsPython: [Double] = [0.0]
        var compCusps12: [Double] = []
        // ⚠️ GIỮ NGUYÊN (hành vi lỗi): py:73-75 truy cập cứng `real_cusps[i]` với i ∈ 0..11.
        // Nếu chart thiếu cusp thì Python ném IndexError → route bắt exception → trang trắng.
        // Swift: trả nil thay vì crash.
        guard realCuspsA.count >= 12, realCuspsB.count >= 12 else { return nil }
        for i in 0..<12 {
            let midC = getMidpoint(realCuspsA[i], realCuspsB[i])
            compCuspsPython.append(midC)
            compCusps12.append(midC)
        }

        // py:20-33 — info/meta cố định của composite
        let info = ChartTechnicalInfo(
            localTime: "Composite Chart",     // py:28
            utTime: "N/A",                    // py:29
            lst: "N/A",                       // py:30
            latLon: "Midpoint Method",        // py:31
            houseSys: "Composite Cusps"       // py:32
        )

        // py:21 `"jd": 0` (dummy) · py:24 `"meta": {"type": "Composite"}`.
        // `ChartMeta` của Src/Core không có trường `type` (cấm sửa Src/Core) → dùng
        // lat/lon = 0, tz = nil, offsetUsed = 0 và ghi rõ đây là chart composite qua
        // `info.latLon == "Midpoint Method"`.
        let meta = ChartMeta(lat: 0, lon: 0, tz: nil, offsetUsed: 0)

        let chart = Chart(jd: 0, cusps: compCusps12, angles: angles,
                          planets: planets, planetOrder: order,
                          info: info, meta: meta)

        return CompositeChart(chart: chart, cuspsPython: compCuspsPython)
    }
}
