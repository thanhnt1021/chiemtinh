//  ProfileStore.swift
//  LƯU HỒ SƠ TRÊN MÁY — thay 2 bảng PostgreSQL `users` + `profiles` của web
//  (`app/astro00_lib/db_models.py:21-36`).
//
//  VÌ SAO SwiftData (không phải CoreData):
//    `ios/project.yml:3` đặt `deploymentTarget iOS 17.0`, mà SwiftData có từ iOS 17.
//    Đã kiểm: target hợp lệ → chọn SwiftData (ít mã bản mẫu, có `@Model` + `@Query`).
//
//  VÌ SAO KHÔNG CÓ BẢNG `users`:
//    Founder chốt app cá nhân một người dùng, không đăng nhập. Cột `user_uid` của web
//    chỉ để cô lập dữ liệu giữa nhiều tài khoản (`db_models.py:140`) → bỏ.
//    Giữ lại `userUID` như một trường ghi chú để nhập dữ liệu cũ từ web nếu cần.
//
//  KHOÁ TRA CỨU: theo `name`, GIỐNG HỆT web (`api.py:159`, `main.py:42`,
//  `db_models.py:191` đều lọc theo tên hồ sơ). Giữ nguyên để khỏi lệch hành vi.

import Foundation
import SwiftData

// MARK: - Kiểu giá trị (truyền qua actor được) --------------------------------

/// Bản sao thuần giá trị của một hồ sơ — khớp 1-1 JSONB `profiles.data`
/// (`db_models.py:171-178`).
public struct BirthProfile: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    /// "Female" / "Male" / "Other" — đúng bộ giá trị của web (`db_models.py:32`).
    public var gender: String

    public var day: Int
    public var month: Int
    public var year: Int
    public var hour: Int
    public var minute: Int
    /// `tob.unknown` của web — chưa dùng để tính, chỉ giữ cho đủ trường.
    public var timeUnknown: Bool

    public var address: String
    public var lat: Double
    public var lon: Double
    /// Định danh IANA.
    public var tz: String
    public var countryCode: String
    /// `tz_offset` — chỉ có khi người dùng nhập múi giờ thủ công.
    public var manualTZOffset: Double?

    public var createdAt: Date

    public init(id: UUID = UUID(), name: String, gender: String = "Female",
                day: Int, month: Int, year: Int, hour: Int, minute: Int,
                timeUnknown: Bool = false,
                address: String, lat: Double, lon: Double,
                tz: String = "Asia/Ho_Chi_Minh", countryCode: String = "vn",
                manualTZOffset: Double? = nil, createdAt: Date = Date()) {
        self.id = id; self.name = name; self.gender = gender
        self.day = day; self.month = month; self.year = year
        self.hour = hour; self.minute = minute; self.timeUnknown = timeUnknown
        self.address = address; self.lat = lat; self.lon = lon
        self.tz = tz; self.countryCode = countryCode
        self.manualTZOffset = manualTZOffset; self.createdAt = createdAt
    }

    /// `"d/m/Y"` — dạng `calculate_chart` nhận (`core.py:141`).
    public var dobString: String { "\(day)/\(month)/\(year)" }
    /// `"H:M"` — web truyền thẳng `f"{hour}:{minute}"` (`transits.py:117`), KHÔNG đệm 0.
    public var tobString: String { "\(hour):\(minute)" }
    /// Web truyền `manual_offset=p.get('tz_offset')` — chuỗi rỗng/nil thì bỏ qua.
    public var manualOffsetString: String? {
        guard let v = manualTZOffset else { return nil }
        return String(v)
    }

    /// Dựng bản đồ sao natal đúng như route web làm (`transits.py:117-120`).
    public func natalChart() -> Chart? {
        AstroCore.calculateChart(dobStr: dobString, tobStr: tobString,
                                 lat: lat, lon: lon, tzStr: tz,
                                 manualOffset: manualOffsetString)
    }
}

// MARK: - Bản ghi SwiftData ---------------------------------------------------

@Model
public final class StoredProfile {
    @Attribute(.unique) public var uuid: UUID
    public var name: String
    public var gender: String
    public var day: Int
    public var month: Int
    public var year: Int
    public var hour: Int
    public var minute: Int
    public var timeUnknown: Bool
    public var address: String
    public var lat: Double
    public var lon: Double
    public var tz: String
    public var countryCode: String
    public var manualTZOffset: Double?
    public var createdAt: Date
    /// Chỗ giữ `user_uid` khi nhập dữ liệu cũ từ PostgreSQL của web. Không dùng để lọc.
    public var legacyUserUID: String?

    public init(from p: BirthProfile, legacyUserUID: String? = nil) {
        self.uuid = p.id
        self.name = p.name
        self.gender = p.gender
        self.day = p.day; self.month = p.month; self.year = p.year
        self.hour = p.hour; self.minute = p.minute; self.timeUnknown = p.timeUnknown
        self.address = p.address; self.lat = p.lat; self.lon = p.lon
        self.tz = p.tz; self.countryCode = p.countryCode
        self.manualTZOffset = p.manualTZOffset
        self.createdAt = p.createdAt
        self.legacyUserUID = legacyUserUID
    }

    public var value: BirthProfile {
        BirthProfile(id: uuid, name: name, gender: gender,
                     day: day, month: month, year: year,
                     hour: hour, minute: minute, timeUnknown: timeUnknown,
                     address: address, lat: lat, lon: lon,
                     tz: tz, countryCode: countryCode,
                     manualTZOffset: manualTZOffset, createdAt: createdAt)
    }

    public func apply(_ p: BirthProfile) {
        name = p.name; gender = p.gender
        day = p.day; month = p.month; year = p.year
        hour = p.hour; minute = p.minute; timeUnknown = p.timeUnknown
        address = p.address; lat = p.lat; lon = p.lon
        tz = p.tz; countryCode = p.countryCode
        manualTZOffset = p.manualTZOffset
    }
}

// MARK: - Kho hồ sơ -----------------------------------------------------------

public enum ProfileStoreError: Error, CustomStringConvertible {
    case duplicateName(String)
    case notFound(String)
    case containerUnavailable(String)

    public var description: String {
        switch self {
        case .duplicateName(let n):     return "Đã có hồ sơ tên “\(n)”"
        case .notFound(let n):          return "Không thấy hồ sơ “\(n)”"
        case .containerUnavailable(let m): return "Không mở được kho dữ liệu: \(m)"
        }
    }
}

/// Bọc `ModelContainer` + CRUD. Dùng `ProfileStore.shared` trong app;
/// dùng `ProfileStore(inMemory: true)` trong test.
@MainActor
public final class ProfileStore: ObservableObject {

    public static let shared = ProfileStore()

    public let container: ModelContainer?
    /// Lỗi mở kho (nếu có) — hiện lên UI thay vì làm sập app.
    public private(set) var setupError: String?

    private var context: ModelContext? { container.map { ModelContext($0) } }

    public init(inMemory: Bool = false) {
        let schema = Schema([StoredProfile.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        do {
            container = try ModelContainer(for: schema, configurations: [config])
            setupError = nil
        } catch {
            container = nil
            setupError = String(describing: error)
        }
    }

    // MARK: Đọc

    /// Tương đương `load_profiles()` (`db_models.py:133`) — đã bỏ lọc theo `user_uid`.
    public func all() -> [BirthProfile] {
        guard let ctx = context else { return [] }
        let d = FetchDescriptor<StoredProfile>(sortBy: [SortDescriptor(\.createdAt, order: .forward)])
        return ((try? ctx.fetch(d)) ?? []).map { $0.value }
    }

    /// Tra theo tên, so sánh sau khi `trim` — giống `api.py:159`.
    public func profile(named name: String) -> BirthProfile? {
        let key = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return all().first { $0.name.trimmingCharacters(in: .whitespacesAndNewlines) == key }
    }

    /// Web chặn trùng tên không phân biệt hoa thường (`transits.py:107`).
    public func nameExists(_ name: String, excluding id: UUID? = nil) -> Bool {
        let key = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return all().contains {
            $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == key && $0.id != id
        }
    }

    // MARK: Ghi

    @discardableResult
    public func save(_ p: BirthProfile) throws -> BirthProfile {
        guard let ctx = context else { throw ProfileStoreError.containerUnavailable(setupError ?? "?") }
        if nameExists(p.name) { throw ProfileStoreError.duplicateName(p.name) }
        ctx.insert(StoredProfile(from: p))
        try ctx.save()
        return p
    }

    /// Chỉ lưu khi chưa có tên đó — đúng hành vi `transits.py:106-109`.
    @discardableResult
    public func saveIfNew(_ p: BirthProfile) -> Bool {
        guard !nameExists(p.name) else { return false }
        return (try? save(p)) != nil
    }

    public func update(id: UUID, with p: BirthProfile) throws {
        guard let ctx = context else { throw ProfileStoreError.containerUnavailable(setupError ?? "?") }
        if nameExists(p.name, excluding: id) { throw ProfileStoreError.duplicateName(p.name) }
        let d = FetchDescriptor<StoredProfile>(predicate: #Predicate { $0.uuid == id })
        guard let row = try ctx.fetch(d).first else { throw ProfileStoreError.notFound(p.name) }
        row.apply(p)
        try ctx.save()
    }

    public func delete(id: UUID) throws {
        guard let ctx = context else { throw ProfileStoreError.containerUnavailable(setupError ?? "?") }
        let d = FetchDescriptor<StoredProfile>(predicate: #Predicate { $0.uuid == id })
        guard let row = try ctx.fetch(d).first else { return }
        ctx.delete(row)
        try ctx.save()
    }

    public func deleteAll() throws {
        guard let ctx = context else { throw ProfileStoreError.containerUnavailable(setupError ?? "?") }
        for row in (try? ctx.fetch(FetchDescriptor<StoredProfile>())) ?? [] { ctx.delete(row) }
        try ctx.save()
    }

    // MARK: Nhập / xuất (di trú dữ liệu từ web)

    /// Cấu trúc JSON hệt `profiles.data` của web, kèm `name`/`gender` ở ngoài.
    public struct WebProfileJSON: Codable {
        public struct DOB: Codable { public let day: Int; public let month: Int; public let year: Int }
        public struct TOB: Codable { public let hour: Int; public let minute: Int; public let unknown: Bool? }
        public struct LOC: Codable {
            public let address: String?; public let lat: Double?; public let lon: Double?
            public let tz: String?; public let country_code: String?
        }
        public let name: String
        public let gender: String?
        public let dob: DOB
        public let tob: TOB
        public let loc: LOC
        public let tz_offset: Double?
        public let user_id: String?
    }

    /// Nhập danh sách hồ sơ xuất từ web. Có "auto-healing" y như `db_models.py:150-156`.
    /// Trả về số bản ghi nhập được.
    @discardableResult
    public func importFromWeb(jsonData: Data) throws -> Int {
        let rows = try JSONDecoder().decode([WebProfileJSON].self, from: jsonData)
        var n = 0
        for r in rows {
            let p = BirthProfile(
                name: r.name,
                gender: r.gender ?? "Female",
                day: r.dob.day, month: r.dob.month, year: r.dob.year,
                hour: r.tob.hour, minute: r.tob.minute, timeUnknown: r.tob.unknown ?? false,
                address: r.loc.address ?? "Hanoi, Vietnam",
                lat: r.loc.lat ?? 21.02, lon: r.loc.lon ?? 105.85,
                tz: r.loc.tz ?? "Asia/Ho_Chi_Minh",
                countryCode: r.loc.country_code ?? "vn",
                manualTZOffset: r.tz_offset)
            if saveIfNew(p) { n += 1 }
        }
        return n
    }
}
