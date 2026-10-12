//  LocationProviding.swift
//  CHỈ LÀ GIAO DIỆN (protocol) để màn hồ sơ gọi tìm địa danh.
//  Bảng địa điểm / gọi Nominatim / bảng múi giờ offline là việc của `Src/Data/` (worker khác).
//  Worker đó chỉ cần:
//      LocationSearch.provider = <đối tượng của mình tuân thủ LocationSearchProviding>
//  gọi một lần lúc app khởi động, KHÔNG cần sửa file này.
//
//  Tương ứng API web: `GET /api/search-location?q=&cc=&cn=` (`app/routes/api.py:29`).

import Foundation

/// Một địa điểm đã giải xong toạ độ + múi giờ — đủ để `AstroCore.calculateChart` chạy.
public struct AstroPlace: Identifiable, Hashable, Codable {
    /// Khoá ổn định (worker Data tự đặt: osm id, slug…).
    public let id: String
    /// Chuỗi hiển thị, ví dụ `"Hà Nội, Vietnam"` hoặc format Astro.com `"City, ST (US) = State, 40n43, 74w00"`.
    public let displayName: String
    public let lat: Double
    public let lon: Double
    /// Tên múi giờ IANA, ví dụ `"Asia/Ho_Chi_Minh"`.
    public let tz: String
    /// Mã ISO quốc gia (chữ thường), ví dụ `"vn"`. `nil` nếu không xác định.
    public let countryCode: String?

    public init(id: String, displayName: String, lat: Double, lon: Double,
                tz: String, countryCode: String? = nil) {
        self.id = id; self.displayName = displayName
        self.lat = lat; self.lon = lon; self.tz = tz; self.countryCode = countryCode
    }
}

/// Nguồn tìm địa danh. `Src/Data/` cài đặt protocol này.
public protocol LocationSearchProviding: AnyObject {
    /// - Parameters:
    ///   - query: từ khoá người dùng gõ (tương ứng tham số `q` của web).
    ///   - countryCode: mã ISO quốc gia lọc kết quả (tương ứng `cc`); `nil` = toàn thế giới.
    /// - Returns: danh sách gợi ý, đã có `lat/lon/tz`.
    func search(query: String, countryCode: String?) async throws -> [AstroPlace]

    /// Danh sách quốc gia cho dropdown (tương ứng `const.py:COUNTRIES`).
    var countries: [(name: String, code: String)] { get }
}

/// Điểm cắm toàn cục. Mặc định là bản dựng sẵn offline (12 tỉnh/thành VN) để form chạy được ngay.
public enum LocationSearch {
    public static var provider: LocationSearchProviding = BuiltInLocationSearch()
}

/// Bản dự phòng tối thiểu, dựa trên `VNLocations` đã có sẵn trong app.
/// Worker `Src/Data/` sẽ thay bằng bản đầy đủ — KHÔNG mở rộng file này.
public final class BuiltInLocationSearch: LocationSearchProviding {
    public init() {}

    public var countries: [(name: String, code: String)] {
        [("Vietnam", "vn")]
    }

    public func search(query: String, countryCode: String?) async throws -> [AstroPlace] {
        let q = query.folding(options: .diacriticInsensitive, locale: .current).lowercased()
        return VNLocations.all
            .filter { q.isEmpty || $0.name.folding(options: .diacriticInsensitive, locale: .current).lowercased().contains(q) }
            .map { AstroPlace(id: $0.id, displayName: $0.name, lat: $0.lat, lon: $0.lon,
                              tz: $0.tz, countryCode: "vn") }
    }
}

public extension AstroPlace {
    /// Địa điểm mặc định khi chưa chọn gì — Hà Nội, khớp mặc định của web (`transits.py:34`).
    static let defaultHanoi = AstroPlace(id: "hanoi", displayName: "Hà Nội",
                                         lat: 21.0285, lon: 105.8542,
                                         tz: "Asia/Ho_Chi_Minh", countryCode: "vn")
}
