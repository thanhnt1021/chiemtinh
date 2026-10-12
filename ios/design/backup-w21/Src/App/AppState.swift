//  AppState.swift
//  Trạng thái dùng chung của app: danh sách hồ sơ sinh + hồ sơ đang chọn.
//  Tương ứng bảng `profiles` của web (`astro00_lib/db_models.py:29-36`), nhưng lưu HOÀN TOÀN TRÊN MÁY
//  (app offline 100%, không có tài khoản/máy chủ).
//
//  Cấu trúc JSON giữ đúng ngữ nghĩa web (`db_models.py:171-178`): dob / tob / loc / tz_offset.

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
public final class AppState: ObservableObject {

    @Published public private(set) var profiles: [SavedProfile] = []
    @Published public var selectedProfileID: UUID?
    /// Tab đang mở — cho phép tile ở Dashboard nhảy sang tab khác.
    @Published public var selectedTab: RootTab = .natal

    private let storageKey = "chiemtinh.profiles.v1"
    private let selectionKey = "chiemtinh.selectedProfile.v1"

    public init() { load() }

    public var selectedProfile: SavedProfile? {
        guard let id = selectedProfileID else { return profiles.first }
        return profiles.first { $0.id == id } ?? profiles.first
    }

    public func upsert(_ p: SavedProfile) {
        if let i = profiles.firstIndex(where: { $0.id == p.id }) {
            profiles[i] = p
        } else {
            profiles.append(p)
        }
        selectedProfileID = p.id
        persist()
    }

    public func delete(id: UUID) {
        profiles.removeAll { $0.id == id }
        if selectedProfileID == id { selectedProfileID = profiles.first?.id }
        persist()
    }

    /// Trùng tên hồ sơ — web chặn trùng tên (`input.html:98-120`), app cảnh báo tương tự.
    public func nameExists(_ name: String, excluding id: UUID?) -> Bool {
        let key = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return profiles.contains { $0.id != id && $0.name.lowercased() == key }
    }

    // --- lưu / đọc ---
    private func persist() {
        let d = UserDefaults.standard
        if let data = try? JSONEncoder().encode(profiles) { d.set(data, forKey: storageKey) }
        d.set(selectedProfileID?.uuidString, forKey: selectionKey)
    }

    private func load() {
        let d = UserDefaults.standard
        if let data = d.data(forKey: storageKey),
           let list = try? JSONDecoder().decode([SavedProfile].self, from: data) {
            profiles = list
        }
        if let s = d.string(forKey: selectionKey), let id = UUID(uuidString: s) {
            selectedProfileID = id
        } else {
            selectedProfileID = profiles.first?.id
        }
    }
}
