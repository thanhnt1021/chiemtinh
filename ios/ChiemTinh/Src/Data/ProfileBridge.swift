//  ProfileBridge.swift
//  CẦU NỐI GIỮA HAI KHO HỒ SƠ ĐANG CÙNG TỒN TẠI TRONG APP.
//
//  BỐI CẢNH (đọc file thật, không suy đoán):
//    • W17 đã làm `Src/App/AppState.swift` — kiểu `SavedProfile`, lưu JSON trong
//      `UserDefaults` khoá `"chiemtinh.profiles.v1"` (`AppState.swift:84, 117-133`).
//    • W20 được giao làm kho SwiftData (`Src/Data/ProfileStore.swift`).
//    • W20 BỊ CẤM ghi vào `Src/App/` nên không thể gộp hai kho làm một.
//
//  GIẢI PHÁP TẠM (không phá gì của ai):
//    `ProfileStore.syncFromAppStorage()` đọc thẳng khoá UserDefaults của W17 rồi nạp
//    những hồ sơ chưa có vào SwiftData. Nhờ vậy hồ sơ tạo ở tab "Hồ sơ" của W17
//    hiện được ngay trong 4 màn Vận Hạn. Hàm này chạy lại được nhiều lần (idempotent).
//
//  👉 VIỆC CẦN CHỐT (báo cho W17 / QA): chọn MỘT kho duy nhất.
//     Khuyến nghị: `AppState` chuyển sang dùng `ProfileStore` (SwiftData) làm nơi lưu,
//     vì SwiftData chịu được số lượng lớn, có truy vấn, và không giới hạn kích thước
//     như một khoá UserDefaults.

import Foundation

// MARK: - Chuyển đổi địa điểm ------------------------------------------------

public extension GeoPlace {
    /// Sang kiểu `AstroPlace` mà `Src/App/LocationProviding.swift` dùng.
    var astroPlace: AstroPlace {
        AstroPlace(id: id, displayName: displayName, lat: lat, lon: lon,
                   tz: tz, countryCode: countryCode)
    }
}

public extension AstroPlace {
    /// Sang kiểu `GeoPlace` của bảng nhúng (thiếu `admin` thì để nil).
    var geoPlace: GeoPlace {
        GeoPlace(id: id, name: displayName, admin: nil,
                 countryCode: countryCode ?? "vn", countryName: "",
                 lat: lat, lon: lon, tz: tz, aliases: [])
    }
}

// MARK: - Chuyển đổi hồ sơ ---------------------------------------------------

public extension BirthProfile {
    /// Từ hồ sơ của W17 (`SavedProfile`) sang kiểu giá trị của kho SwiftData.
    init(saved s: SavedProfile) {
        self.init(id: s.id, name: s.name, gender: s.gender.rawValue,
                  day: s.day, month: s.month, year: s.year,
                  hour: s.hour, minute: s.minute, timeUnknown: s.timeUnknown,
                  address: s.place.displayName, lat: s.place.lat, lon: s.place.lon,
                  tz: s.place.tz, countryCode: s.place.countryCode ?? "vn",
                  manualTZOffset: s.manualTZOffset, createdAt: s.createdAt)
    }

    /// Ngược lại — để trả hồ sơ về cho màn hình của W17.
    var savedProfile: SavedProfile {
        SavedProfile(id: id, name: name,
                     gender: ProfileGender(rawValue: gender) ?? .female,
                     day: day, month: month, year: year,
                     hour: hour, minute: minute, timeUnknown: timeUnknown,
                     place: AstroPlace(id: "w20-\(id.uuidString)", displayName: address,
                                       lat: lat, lon: lon, tz: tz, countryCode: countryCode),
                     manualTZOffset: manualTZOffset, createdAt: createdAt)
    }
}

// MARK: - Đồng bộ một chiều UserDefaults → SwiftData -------------------------

@MainActor
public extension ProfileStore {

    /// Khoá lưu của `AppState` — `Src/App/AppState.swift:84`.
    static let appStorageKey = "chiemtinh.profiles.v1"

    /// Nạp hồ sơ do W17 lưu trong `UserDefaults` vào SwiftData (bỏ qua tên đã có).
    /// - Returns: số hồ sơ mới nạp được.
    @discardableResult
    func syncFromAppStorage(defaults: UserDefaults = .standard) -> Int {
        guard let data = defaults.data(forKey: ProfileStore.appStorageKey),
              let list = try? JSONDecoder().decode([SavedProfile].self, from: data)
        else { return 0 }
        var n = 0
        for s in list where !nameExists(s.name) {
            if saveIfNew(BirthProfile(saved: s)) { n += 1 }
        }
        return n
    }
}

// MARK: - Cắm bảng địa điểm offline vào điểm cắm của W17 ----------------------

/// `LocationDirectory` (177 địa điểm nhúng) cài đúng protocol W17 khai ở
/// `Src/App/LocationProviding.swift:33` để thay `BuiltInLocationSearch` (chỉ 12 mục).
extension LocationDirectory: LocationSearchProviding {

    /// `const.py:82-98` — danh sách quốc gia nhanh của web.
    public var countries: [(name: String, code: String)] {
        [("Vietnam", "vn"), ("United States", "us"), ("United Kingdom", "gb"),
         ("Australia", "au"), ("Canada", "ca"), ("France", "fr"), ("Germany", "de"),
         ("Japan", "jp"), ("South Korea", "kr"), ("Russia", "ru"), ("India", "in"),
         ("Thailand", "th"), ("Singapore", "sg")]
    }

    public func search(query: String, countryCode: String?) async throws -> [AstroPlace] {
        search(query, countryCode: countryCode, limit: 20).map { $0.astroPlace }
    }
}

/// Gọi 1 lần lúc app khởi động. 4 màn Vận Hạn tự gọi ở `.task` nên vẫn chạy đúng
/// kể cả khi `ChiemTinhApp.init()` chưa gọi.
public enum W20Services {
    private static var installed = false

    @MainActor
    public static func install() {
        guard !installed else { return }
        installed = true
        // Thay bản dự phòng 12 mục của W17 bằng bảng 177 mục có tìm mờ + múi giờ.
        LocationSearch.provider = LocationDirectory.shared
        // Kéo hồ sơ đã lưu ở tab "Hồ sơ" (UserDefaults) sang kho SwiftData.
        ProfileStore.shared.syncFromAppStorage()
    }
}
