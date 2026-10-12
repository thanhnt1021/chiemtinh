//  PersonInputCard.swift
//  Ô nhập 1 người của màn Hợp đôi / Hợp nhất.
//  Bám 1-1 các trường của `app/templates/synastry.html:19-85` và `composite.html`
//  (giống hệt nhau): tab "Có sẵn" / "Nhập mới", Tên, D/M/Y, Giờ/Phút,
//  Location Picker (`macros/location_picker.html`), Giới tính, "Lưu hồ sơ".
//
//  Dùng token của `Src/Design/Theme.swift` + `Components.swift` (W17).

import SwiftUI

/// Trạng thái nhập của 1 người — tương ứng cặp tham số `A_*` / `B_*` của web.
public struct PersonInput: Equatable {
    public enum Mode: String, CaseIterable { case existing, new }

    public var mode: Mode = .existing
    /// id hồ sơ đã lưu (tab "Có sẵn").
    public var profileID: UUID? = nil

    // Tab "Nhập mới" — synastry.html:32-49
    public var name: String = ""
    public var day: Int = 15
    public var month: Int = 5
    public var year: Int = 1990
    public var hour: Int = 7
    public var minute: Int = 30
    public var placeID: String = "vn-hanoi"
    public var gender: String = "Female"
    public var saveProfile: Bool = false

    public init() {}

    public var place: GeoPlace {
        LocationDirectory.shared.place(id: placeID) ?? GeoPlaceTable.all[0]
    }

    /// Dựng `BirthProfile` từ trạng thái hiện tại — tương đương `resolve_profile_logic`
    /// (`app/utils/helpers.py`) mà route synastry/composite gọi (`charts.py:99-100`).
    public func resolve(store: [BirthProfile]) -> BirthProfile? {
        switch mode {
        case .existing:
            if let id = profileID { return store.first { $0.id == id } }
            return store.first
        case .new:
            let p = place
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            return BirthProfile(name: trimmed, gender: gender,
                                day: day, month: month, year: year,
                                hour: hour, minute: minute, timeUnknown: false,
                                address: p.displayName, lat: p.lat, lon: p.lon,
                                tz: p.tz, countryCode: p.countryCode, manualTZOffset: nil)
        }
    }
}

// MARK: - View

public struct PersonInputCard: View {
    @Binding var input: PersonInput
    let title: String
    let tint: Color
    let profiles: [BirthProfile]

    public init(input: Binding<PersonInput>, title: String, tint: Color, profiles: [BirthProfile]) {
        self._input = input; self.title = title; self.tint = tint; self.profiles = profiles
    }

    private var duplicateName: Bool {
        // synastry.html:127-140 — chỉ báo trùng khi tab "Nhập mới" VÀ có tick "Lưu hồ sơ".
        guard input.mode == .new, input.saveProfile else { return false }
        let key = input.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !key.isEmpty else { return false }
        return profiles.contains { $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == key }
    }

    public var body: some View {
        AstroCard(level: .raised) {
            VStack(alignment: .leading, spacing: Theme.Space.md) {
                header
                modePicker
                if input.mode == .existing { existingTab } else { newTab }
            }
        }
    }

    private var header: some View {
        HStack {
            Text(title)
                .font(Theme.Fonts.sectionTitle)
                .foregroundStyle(tint)
            Spacer()
        }
    }

    private var modePicker: some View {
        Picker("", selection: $input.mode) {
            Text("Có sẵn").tag(PersonInput.Mode.existing)
            Text("Nhập mới").tag(PersonInput.Mode.new)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }

    @ViewBuilder private var existingTab: some View {
        if profiles.isEmpty {
            Text("Chưa có hồ sơ nào được lưu. Chuyển sang “Nhập mới”.")
                .font(Theme.Fonts.footnote)
                .foregroundStyle(Theme.Colors.textMuted)
        } else {
            Picker("Hồ sơ", selection: Binding(
                get: { input.profileID ?? profiles[0].id },
                set: { input.profileID = $0 })) {
                    ForEach(profiles) { p in Text(p.name).tag(p.id) }
                }
                .pickerStyle(.menu)
                .tint(Theme.Colors.accent)
        }
    }

    private var newTab: some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            TextField("Tên", text: $input.name)
                .textFieldStyle(.roundedBorder)
                .font(Theme.Fonts.body)
            if duplicateName {
                Label("Tên này đã tồn tại.", systemImage: "exclamationmark.triangle.fill")
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(Theme.Colors.danger)
            }

            HStack(spacing: Theme.Space.sm) {
                numberField("Ngày", value: $input.day, range: 1...31)
                numberField("Tháng", value: $input.month, range: 1...12)
                numberField("Năm", value: $input.year, range: 1800...2099)
            }
            HStack(spacing: Theme.Space.sm) {
                numberField("Giờ", value: $input.hour, range: 0...23)
                numberField("Phút", value: $input.minute, range: 0...59)
            }

            // Thay cho macro Location Picker của web — dùng bảng offline của Src/Data.
            Picker("Nơi sinh", selection: $input.placeID) {
                ForEach(GeoPlaceTable.all) { p in Text(p.shortName).tag(p.id) }
            }
            .pickerStyle(.navigationLink)
            .tint(Theme.Colors.accent)

            Picker("Giới tính", selection: $input.gender) {
                Text("Nữ").tag("Female")
                Text("Nam").tag("Male")
                Text("Khác").tag("Other")
            }
            .pickerStyle(.segmented)

            Toggle("Lưu hồ sơ", isOn: $input.saveProfile)
                .font(Theme.Fonts.footnote)
                .tint(Theme.Colors.accent)
        }
    }

    private func numberField(_ label: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(Theme.Fonts.caps)
                .foregroundStyle(Theme.Colors.textMuted)
            TextField(label, value: value, format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .textFieldStyle(.roundedBorder)
                .font(Theme.Fonts.numeric)
                .onChange(of: value.wrappedValue) { _, v in
                    if v < range.lowerBound { value.wrappedValue = range.lowerBound }
                    if v > range.upperBound { value.wrappedValue = range.upperBound }
                }
        }
    }
}
