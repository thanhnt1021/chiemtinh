//  LocationDirectory.swift
//  TÌM ĐỊA ĐIỂM NGOẠI TUYẾN — thay cho `GET /api/search-location` của web
//  (`app/routes/api.py:29-127`, gọi Nominatim qua mạng) và bù cho
//  `AstroCore.getTimezoneStr(lat:lon:)` hiện trả `nil` (`Src/Core/AstroCore.swift:181`).
//
//  ► GIAO DIỆN CHO WORKER KHÁC (W17) GỌI:  `LocationSearching`
//    Dùng `LocationDirectory.shared` làm bản cài mặc định.
//
//  Chuỗi hiển thị `displayName` bám ĐÚNG định dạng kiểu Astro.com mà web đang trả
//  (`api.py:105-113`): "<Tên>, <BANG> (<CC>) = <Bang/Nước>, <toạ độ astro>".

import Foundation

// MARK: - Bản ghi địa điểm ---------------------------------------------------

public struct GeoPlace: Identifiable, Hashable, Codable, Sendable {
    public let id: String
    /// Tên chính (có dấu với địa danh Việt Nam).
    public let name: String
    /// Tỉnh / bang / đơn vị hành chính cấp 1. `nil` với nước không chia bang.
    public let admin: String?
    /// Mã ISO-3166 alpha-2, chữ thường — giống `country_code` của web.
    public let countryCode: String
    public let countryName: String
    public let lat: Double
    public let lon: Double
    /// Định danh IANA (tzdata sẵn trong iOS).
    public let tz: String
    /// Tên gọi khác / không dấu / viết tắt — phục vụ tìm mờ.
    public let aliases: [String]

    public init(id: String, name: String, admin: String?, countryCode: String,
                countryName: String, lat: Double, lon: Double, tz: String, aliases: [String]) {
        self.id = id; self.name = name; self.admin = admin
        self.countryCode = countryCode; self.countryName = countryName
        self.lat = lat; self.lon = lon; self.tz = tz; self.aliases = aliases
    }

    /// `const.py:79` — COUNTRIES_WITH_STATES.
    public static let countriesWithStates: Set<String> = ["us", "ca", "au", "br", "in", "mx"]

    /// Toạ độ kiểu Astro.com ("21n01, 105e51") — dùng chính hàm đã port ở Core.
    public var astroCoords: String {
        AstroCore.formatCoordAstroPair(lat: lat, lon: lon)
    }

    /// Chuỗi dài, đúng khuôn web trả về (`api.py:113`).
    public var displayName: String {
        let cc = countryCode.uppercased()
        let prefix: String
        let suffix: String
        if GeoPlace.countriesWithStates.contains(countryCode), let st = admin {
            prefix = "\(name), \(st) (\(cc))"
            suffix = st
        } else {
            prefix = "\(name) (\(cc))"
            suffix = countryName
        }
        return "\(prefix) = \(suffix), \(astroCoords)"
    }

    /// Chuỗi ngắn (`api.py:118`) — dùng lưu vào `loc.address` của hồ sơ.
    public var shortName: String {
        let cc = countryCode.uppercased()
        let tail = admin ?? countryName
        return "\(name), \(tail) (\(cc))"
    }
}

// MARK: - Giao diện cho worker khác ------------------------------------------

/// **TÊN PROTOCOL ĐỂ W17 KHỚP: `LocationSearching`.**
/// Toàn bộ tìm kiếm chạy trong máy, không gọi mạng — nên các hàm là đồng bộ.
public protocol LocationSearching: Sendable {

    /// Tìm mờ theo tên (chấp nhận có dấu, không dấu, sai chính tả nhẹ).
    /// - Parameters:
    ///   - query: chuỗi người dùng gõ.
    ///   - countryCode: lọc theo mã nước ISO (chữ thường); `nil` = toàn thế giới.
    ///   - limit: số kết quả tối đa.
    /// - Returns: danh sách đã xếp theo độ khớp giảm dần.
    func search(_ query: String, countryCode: String?, limit: Int) -> [GeoPlace]

    /// Lấy 1 địa điểm theo `id`.
    func place(id: String) -> GeoPlace?

    /// Địa điểm gần một toạ độ nhất, trong bán kính `maxKm`.
    func nearest(lat: Double, lon: Double, maxKm: Double) -> GeoPlace?

    /// Múi giờ IANA suy từ toạ độ — bù cho `AstroCore.getTimezoneStr` (đang trả nil).
    /// Trả `nil` khi toạ độ nằm ngoài vùng bảng phủ được.
    func timezoneIdentifier(lat: Double, lon: Double) -> String?

    /// Toàn bộ bảng (để hiện danh sách mặc định khi ô tìm kiếm còn trống).
    var allPlaces: [GeoPlace] { get }
}

public extension LocationSearching {
    func search(_ query: String) -> [GeoPlace] { search(query, countryCode: nil, limit: 20) }
}

// MARK: - Bản cài đặt dùng bảng nhúng ---------------------------------------

public final class LocationDirectory: LocationSearching, @unchecked Sendable {

    public static let shared = LocationDirectory()

    public let allPlaces: [GeoPlace]
    /// Khoá tìm kiếm đã chuẩn hoá của từng địa điểm (tên chính + admin + nước + alias).
    private let keys: [[String]]
    private let byID: [String: GeoPlace]

    public init(places: [GeoPlace] = GeoPlaceTable.all) {
        self.allPlaces = places
        self.keys = places.map { p in
            var k = [LocationDirectory.normalize(p.name)]
            if let a = p.admin { k.append(LocationDirectory.normalize(a)) }
            k.append(LocationDirectory.normalize(p.countryName))
            k.append(contentsOf: p.aliases.map(LocationDirectory.normalize))
            return k.filter { !$0.isEmpty }
        }
        var m = [String: GeoPlace](minimumCapacity: places.count)
        for p in places { m[p.id] = p }
        self.byID = m
    }

    // MARK: Chuẩn hoá chuỗi

    /// Bỏ dấu, hạ chữ thường, `đ`→`d`, gộp khoảng trắng.
    /// `folding(.diacriticInsensitive)` KHÔNG đổi `đ` nên phải thay tay.
    public static func normalize(_ s: String) -> String {
        let noD = s.replacingOccurrences(of: "đ", with: "d")
                   .replacingOccurrences(of: "Đ", with: "D")
        let folded = noD.folding(options: [.diacriticInsensitive, .caseInsensitive],
                                 locale: Locale(identifier: "vi_VN"))
        let cleaned = folded.map { ch -> Character in
            (ch.isLetter || ch.isNumber) ? ch : " "
        }
        return String(cleaned).split(separator: " ").joined(separator: " ")
    }

    /// Khoảng cách Levenshtein (giới hạn sớm để khỏi tốn công).
    static func levenshtein(_ a: [Character], _ b: [Character], cutoff: Int) -> Int {
        if abs(a.count - b.count) > cutoff { return cutoff + 1 }
        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }
        var prev = Array(0...b.count)
        var curr = [Int](repeating: 0, count: b.count + 1)
        for i in 1...a.count {
            curr[0] = i
            var rowMin = curr[0]
            for j in 1...b.count {
                let cost = a[i - 1] == b[j - 1] ? 0 : 1
                curr[j] = min(prev[j] + 1, curr[j - 1] + 1, prev[j - 1] + cost)
                rowMin = min(rowMin, curr[j])
            }
            if rowMin > cutoff { return cutoff + 1 }
            swap(&prev, &curr)
        }
        return prev[b.count]
    }

    // MARK: Tìm kiếm

    public func search(_ query: String, countryCode: String? = nil, limit: Int = 20) -> [GeoPlace] {
        let q = LocationDirectory.normalize(query)
        guard !q.isEmpty else {
            var base = allPlaces
            if let cc = countryCode?.lowercased(), !cc.isEmpty {
                base = base.filter { $0.countryCode == cc }
            }
            return Array(base.prefix(limit))
        }
        let qChars = Array(q)
        let qTokens = q.split(separator: " ").map(String.init)
        // Sai chính tả nhẹ: chuỗi càng ngắn thì càng ít khoan dung.
        let cutoff = qChars.count <= 3 ? 0 : (qChars.count <= 6 ? 1 : 2)

        var scored: [(Int, Int, GeoPlace)] = []   // (điểm, thứ tự gốc, place)
        for (idx, p) in allPlaces.enumerated() {
            if let cc = countryCode?.lowercased(), !cc.isEmpty, p.countryCode != cc { continue }
            var best = 0
            for (ki, key) in keys[idx].enumerated() {
                // Khoá đầu tiên (tên chính) được cộng thưởng để đứng trên alias.
                let bonus = (ki == 0) ? 40 : 0
                var s = 0
                if key == q {
                    s = 1000
                } else if key.hasPrefix(q) {
                    s = 850 - min(80, key.count - q.count)
                } else if key.split(separator: " ").contains(where: { $0.hasPrefix(q) }) {
                    s = 720
                } else if key.contains(q) {
                    s = 640
                } else if key.count >= 4 && q.contains(key) {
                    // Người dùng gõ DÀI hơn tên trong bảng: "vinh nghe an" ⊃ "vinh".
                    s = 620
                } else if qTokens.count >= 2 {
                    // Khớp theo từ: "tp ho chi minh" vs "thanh pho ho chi minh".
                    let keyToks = Set(key.split(separator: " ").map(String.init))
                    let matched = qTokens.filter { keyToks.contains($0) }.count
                    let ratio = Double(matched) / Double(qTokens.count)
                    if ratio >= 0.6 { s = 500 + Int(ratio * 60) }
                }
                if s == 0, cutoff > 0 {
                    let d = LocationDirectory.levenshtein(Array(key), qChars, cutoff: cutoff)
                    if d <= cutoff {
                        s = 520 - d * 60
                    } else {
                        // gõ sai 1 từ trong cụm nhiều từ (vd "Da Nag" -> "Da Nang")
                        for tok in key.split(separator: " ") {
                            let dt = LocationDirectory.levenshtein(Array(tok), qChars, cutoff: cutoff)
                            if dt <= cutoff { s = max(s, 460 - dt * 60) }
                        }
                    }
                }
                if s > 0 { best = max(best, s + bonus) }
            }
            if best > 0 { scored.append((best, idx, p)) }
        }
        scored.sort { $0.0 != $1.0 ? $0.0 > $1.0 : $0.1 < $1.1 }
        return scored.prefix(limit).map { $0.2 }
    }

    public func place(id: String) -> GeoPlace? { byID[id] }

    // MARK: Toạ độ → địa điểm / múi giờ

    /// Khoảng cách vòng lớn (haversine), km.
    static func distanceKm(_ lat1: Double, _ lon1: Double, _ lat2: Double, _ lon2: Double) -> Double {
        let r = 6371.0088
        let dLat = (lat2 - lat1) * .pi / 180
        let dLon = (lon2 - lon1) * .pi / 180
        let a = sin(dLat / 2) * sin(dLat / 2)
              + cos(lat1 * .pi / 180) * cos(lat2 * .pi / 180) * sin(dLon / 2) * sin(dLon / 2)
        return 2 * r * atan2(sqrt(a), sqrt(max(0, 1 - a)))
    }

    public func nearest(lat: Double, lon: Double, maxKm: Double = 200) -> GeoPlace? {
        var best: (Double, GeoPlace)? = nil
        for p in allPlaces {
            let d = LocationDirectory.distanceKm(lat, lon, p.lat, p.lon)
            if best == nil || d < best!.0 { best = (d, p) }
        }
        guard let b = best, b.0 <= maxKm else { return nil }
        return b.1
    }

    /// Bù cho `timezonefinder` của Python.
    /// 1) Trong hộp Việt Nam (`AstroCore.isCoordInVietnam`) → luôn `Asia/Ho_Chi_Minh`.
    ///    (Dù sao `calculate_chart` cũng dùng bảng lịch sử VN chứ không dùng tz này —
    ///     `Src/Core/AstroCore.swift:281`.)
    /// 2) Ngoài VN → lấy múi giờ của địa điểm gần nhất trong bán kính 300 km.
    /// 3) Không có gì gần → `nil` (HẠN CHẾ ĐÃ BIẾT: bảng nhúng không phủ hết địa cầu).
    public func timezoneIdentifier(lat: Double, lon: Double) -> String? {
        if AstroCore.isCoordInVietnam(lat: lat, lon: lon) { return "Asia/Ho_Chi_Minh" }
        return nearest(lat: lat, lon: lon, maxKm: 300)?.tz
    }
}
