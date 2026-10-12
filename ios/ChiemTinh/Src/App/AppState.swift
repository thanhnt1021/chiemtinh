//  AppState.swift
//  Trạng thái dùng chung của app: danh sách hồ sơ sinh + hồ sơ đang chọn.
//  Tương ứng bảng `profiles` của web (`astro00_lib/db_models.py:29-36`), nhưng lưu HOÀN TOÀN TRÊN MÁY
//  (app offline 100%, không có tài khoản/máy chủ).
//
//  Cấu trúc JSON giữ đúng ngữ nghĩa web (`db_models.py:171-178`): dob / tob / loc / tz_offset.
//
//  ► W21 — GỘP KHO HỒ SƠ (trước đây app có HAI kho song song):
//      · cũ: `AppState` tự lưu JSON vào `UserDefaults` khoá "chiemtinh.profiles.v1";
//      · nay: kho DUY NHẤT là SwiftData qua `Src/Data/ProfileStore.swift`
//        (iOS 17 — `ios/project.yml:3` đặt deploymentTarget 17.0).
//    `SavedProfile` GIỮ NGUYÊN làm kiểu hiển thị của tầng App; chuyển đổi hai chiều
//    sang `BirthProfile` bằng cầu nối `Src/Data/ProfileBridge.swift:43-64`.
//    Dữ liệu cũ trong UserDefaults được di trú MỘT LẦN qua
//    `ProfileStore.syncFromAppStorage()` rồi xoá khoá cũ.

import Foundation
import SwiftUI

// MARK: - Mô hình hồ sơ -------------------------------------------------------

public enum ProfileGender: String, Codable, CaseIterable, Identifiable {
    case female = "Female"
    case male   = "Male"
    case other  = "Other"

    public var id: String { rawValue }
    /// Nhãn tiếng Việt hiển thị (web dùng Nữ/Nam/Khác — `input.html`).
    public var labelVN: String {
        switch self {
        case .female: return "Nữ"
        case .male:   return "Nam"
        case .other:  return "Khác"
        }
    }
}

public struct SavedProfile: Identifiable, Hashable, Codable {
    public var id: UUID
    public var name: String
    public var gender: ProfileGender
    public var day: Int
    public var month: Int
    public var year: Int
    public var hour: Int
    public var minute: Int
    /// Web có cờ `tob.unknown` (`db_models.py:171-178`).
    public var timeUnknown: Bool
    public var place: AstroPlace
    /// Múi giờ nhập tay (GMT offset, bước 0.5). `nil` = để hệ thống tự tính.
    public var manualTZOffset: Double?
    public var createdAt: Date

    public init(id: UUID = UUID(),
                name: String,
                gender: ProfileGender = .female,
                day: Int, month: Int, year: Int,
                hour: Int, minute: Int,
                timeUnknown: Bool = false,
                place: AstroPlace,
                manualTZOffset: Double? = nil,
                createdAt: Date = Date()) {
        self.id = id; self.name = name; self.gender = gender
        self.day = day; self.month = month; self.year = year
        self.hour = hour; self.minute = minute
        self.timeUnknown = timeUnknown
        self.place = place
        self.manualTZOffset = manualTZOffset
        self.createdAt = createdAt
    }

    /// Chuỗi `dd/mm/yyyy` — đúng định dạng `AstroCore.calculateChart(dobStr:)` cần.
    public var dobString: String { String(format: "%02d/%02d/%04d", day, month, year) }
    /// Chuỗi `HH:MM` — đúng định dạng `AstroCore.calculateChart(tobStr:)` cần.
    public var tobString: String { String(format: "%02d:%02d", hour, minute) }

    public var summaryLine: String {
        let t = timeUnknown ? "giờ không rõ" : tobString
        return "\(dobString) · \(t) · \(place.displayName)"
    }
}

// MARK: - Kho hồ sơ -----------------------------------------------------------

/// Kho hồ sơ + lựa chọn hiện tại. Bơm vào cây view bằng `.environmentObject(...)`.
///
/// KHÔNG còn tự lưu trữ: mọi thao tác đọc/ghi đều đi qua `ProfileStore` (SwiftData).
/// `profiles` chỉ là bản chụp trong bộ nhớ để SwiftUI vẽ lại khi có thay đổi.
@MainActor
public final class AppState: ObservableObject {

    @Published public private(set) var profiles: [SavedProfile] = []
    /// Đặt lại là ghi nhớ ngay (gán trong `init` KHÔNG kích hoạt `didSet`).
    @Published public var selectedProfileID: UUID? { didSet { persistSelection() } }
    /// Tab đang mở — cho phép tile ở Dashboard nhảy sang tab khác.
    @Published public var selectedTab: RootTab = .natal
    /// Lỗi mở kho SwiftData (nếu có) — hiện lên UI thay vì im lặng.
    @Published public private(set) var storeError: String?
    /// Số hồ sơ đã di trú từ UserDefaults sang SwiftData ở lần chạy này.
    @Published public private(set) var migratedCount: Int = 0

    /// Khoá CŨ của bản UserDefaults — chỉ còn dùng để di trú rồi xoá.
    public static let legacyProfilesKey = "chiemtinh.profiles.v1"
    private let selectionKey = "chiemtinh.selectedProfile.v1"

    private let store: ProfileStore
    private let defaults: UserDefaults

    /// `store == nil` -> dùng `ProfileStore.shared`. Không đặt `.shared` làm giá trị
    /// mặc định của tham số vì giá trị mặc định được tính ở ngữ cảnh KHÔNG phải main actor
    /// (Swift 6 sẽ báo lỗi).
    public init(store: ProfileStore? = nil, defaults: UserDefaults = .standard) {
        self.store = store ?? ProfileStore.shared
        self.defaults = defaults
        self.storeError = self.store.setupError
        migrateLegacyIfNeeded()
        reload()
        if let s = defaults.string(forKey: selectionKey), let id = UUID(uuidString: s),
           profiles.contains(where: { $0.id == id }) {
            selectedProfileID = id
        } else {
            selectedProfileID = profiles.first?.id
        }
    }

    public var selectedProfile: SavedProfile? {
        guard let id = selectedProfileID else { return profiles.first }
        return profiles.first { $0.id == id } ?? profiles.first
    }

    // MARK: Ghi

    public func upsert(_ p: SavedProfile) {
        let bp = BirthProfile(saved: p)
        if store.all().contains(where: { $0.id == p.id }) {
            do { try store.update(id: p.id, with: bp) }
            catch { storeError = String(describing: error) }
        } else {
            do { _ = try store.save(bp) }
            catch { storeError = String(describing: error) }
        }
        reload()
        selectedProfileID = p.id
        persistSelection()
    }

    public func delete(id: UUID) {
        do { try store.delete(id: id) } catch { storeError = String(describing: error) }
        reload()
        if selectedProfileID == id { selectedProfileID = profiles.first?.id }
        persistSelection()
    }

    /// Trùng tên hồ sơ — web chặn trùng tên (`input.html:98-120`), app cảnh báo tương tự.
    /// Hỏi thẳng kho SwiftData để không lệch với ràng buộc `ProfileStore.save`.
    public func nameExists(_ name: String, excluding id: UUID?) -> Bool {
        store.nameExists(name, excluding: id)
    }

    // MARK: Đọc lại từ kho

    /// Nạp lại bản chụp từ SwiftData. Gọi sau mọi thao tác ghi, và khi màn khác
    /// (4 màn Vận Hạn, màn Quan hệ) đã tự lưu hồ sơ qua `ProfileStore`.
    public func reload() {
        profiles = store.all().map { $0.savedProfile }
        if let id = selectedProfileID, !profiles.contains(where: { $0.id == id }) {
            selectedProfileID = profiles.first?.id
        }
    }

    private func persistSelection() {
        defaults.set(selectedProfileID?.uuidString, forKey: selectionKey)
    }

    // MARK: Di trú một lần từ UserDefaults

    /// Đường di trú giữ nguyên hàm `ProfileStore.syncFromAppStorage()`
    /// (`Src/Data/ProfileBridge.swift:77`), chạy đúng MỘT lần rồi xoá khoá cũ.
    private func migrateLegacyIfNeeded() {
        guard defaults.data(forKey: Self.legacyProfilesKey) != nil else { return }
        migratedCount = store.syncFromAppStorage(defaults: defaults)
        defaults.removeObject(forKey: Self.legacyProfilesKey)
    }
}
