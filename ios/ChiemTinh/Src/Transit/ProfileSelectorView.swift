//  ProfileSelectorView.swift
//  Khối "Có sẵn / Nhập mới" + ô tìm địa điểm — dùng chung cho `/vanhan/rieng`
//  và `/vanhan/chitiet` (web: `transit_personal.html:31-70`, `transit_chitiet.html:59-90`
//  + macro `macros/location_picker.html`).
//
//  Khác web: tìm địa điểm chạy NGOẠI TUYẾN qua `LocationSearching`
//  (`Src/Data/LocationDirectory.swift`), không gọi `/api/search-location`.

import SwiftUI

// MARK: - Chọn địa điểm ------------------------------------------------------

public struct LocationPickerView: View {
    @Binding public var place: GeoPlace
    public var directory: LocationSearching = LocationDirectory.shared

    @State private var query: String = ""
    @State private var results: [GeoPlace] = []
    @State private var countryCode: String? = "vn"
    @FocusState private var focused: Bool

    /// `const.py:82-98` — danh sách quốc gia nhanh của web.
    private static let countries: [(String, String?)] = [
        ("Việt Nam", "vn"), ("Hoa Kỳ", "us"), ("Anh", "gb"), ("Úc", "au"), ("Canada", "ca"),
        ("Pháp", "fr"), ("Đức", "de"), ("Nhật Bản", "jp"), ("Hàn Quốc", "kr"), ("Nga", "ru"),
        ("Ấn Độ", "in"), ("Thái Lan", "th"), ("Singapore", "sg"), ("Toàn thế giới", nil)
    ]

    public init(place: Binding<GeoPlace>, directory: LocationSearching = LocationDirectory.shared) {
        self._place = place
        self.directory = directory
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            Picker("Quốc gia", selection: $countryCode) {
                ForEach(Self.countries, id: \.0) { c in
                    Text(c.0).tag(c.1)
                }
            }
            .pickerStyle(.menu)
            .tint(Theme.Colors.accent)

            HStack(spacing: Theme.Space.sm) {
                Image(systemName: "magnifyingglass").foregroundStyle(Theme.Colors.textMuted)
                TextField("Nhập tên tỉnh/thành…", text: $query)
                    .focused($focused)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .font(Theme.Fonts.body)
                if !query.isEmpty {
                    Button { query = ""; results = [] } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.Colors.textMuted)
                    }.buttonStyle(.plain)
                }
            }
            .padding(Theme.Space.md)
            .background(Theme.Colors.bgChip)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
            .onChange(of: query) { _, _ in refresh() }
            .onChange(of: countryCode) { _, _ in refresh() }

            if !results.isEmpty {
                VStack(spacing: 0) {
                    ForEach(results.prefix(8)) { p in
                        Button {
                            place = p; query = ""; results = []; focused = false
                        } label: {
                            HStack {
                                Text(p.displayName)
                                    .font(Theme.Fonts.footnote)
                                    .foregroundStyle(Theme.Colors.textPrimary)
                                    .multilineTextAlignment(.leading)
                                Spacer(minLength: 0)
                            }
                            .padding(.vertical, 10).padding(.horizontal, Theme.Space.md)
                        }
                        .buttonStyle(.plain)
                        Divider().overlay(Theme.Colors.separator)
                    }
                }
                .background(Theme.Colors.bgSurfaceRaised)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                            .stroke(Theme.Colors.border, lineWidth: 1))
            }

            HStack(spacing: Theme.Space.xs) {
                Image(systemName: "checkmark.seal.fill").foregroundStyle(Theme.Colors.success)
                Text("\(place.shortName) · \(place.tz) · \(place.astroCoords)")
                    .font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.textSecondary)
            }
        }
    }

    private func refresh() {
        let q = query.trimmingCharacters(in: .whitespaces)
        results = q.isEmpty ? [] : directory.search(q, countryCode: countryCode, limit: 8)
    }
}

// MARK: - Chọn / nhập hồ sơ --------------------------------------------------

public struct ProfileSelectorView: View {

    public enum Mode: String, CaseIterable { case existing, new
        var label: String { self == .existing ? "Có sẵn" : "Nhập mới" }
    }

    @ObservedObject public var store: ProfileStore
    @Binding public var mode: Mode
    @Binding public var selectedName: String
    @Binding public var draft: BirthProfile
    @Binding public var saveToStore: Bool

    public init(store: ProfileStore, mode: Binding<Mode>, selectedName: Binding<String>,
                draft: Binding<BirthProfile>, saveToStore: Binding<Bool>) {
        self.store = store
        self._mode = mode; self._selectedName = selectedName
        self._draft = draft; self._saveToStore = saveToStore
    }

    @State private var place: GeoPlace = GeoPlaceTable.vietnam[0]

    private var profiles: [BirthProfile] { store.all() }

    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.md) {
            Picker("", selection: $mode) {
                ForEach(Mode.allCases, id: \.self) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)

            if mode == .existing {
                if profiles.isEmpty {
                    TBanner(.warning, "Chưa có hồ sơ nào trên máy. Chuyển sang “Nhập mới” để tạo.")
                } else {
                    Picker("Hồ sơ gốc (Natal)", selection: $selectedName) {
                        ForEach(profiles) { p in Text(p.name).tag(p.name) }
                    }
                    .pickerStyle(.menu)
                    .tint(Theme.Colors.accent)
                    .onAppear {
                        if !profiles.contains(where: { $0.name == selectedName }) {
                            selectedName = profiles[0].name
                        }
                    }
                }
            } else {
                TextField("Họ tên", text: $draft.name)
                    .font(Theme.Fonts.body)
                    .padding(Theme.Space.md)
                    .background(Theme.Colors.bgChip)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))

                TDMYField(title: "Ngày sinh", day: $draft.day, month: $draft.month, year: $draft.year)

                HStack(spacing: Theme.Space.sm) {
                    hmBox("Giờ", $draft.hour, 0...23)
                    hmBox("Phút", $draft.minute, 0...59)
                }

                LocationPickerView(place: $place)
                    .onChange(of: place) { _, p in
                        draft.address = p.shortName
                        draft.lat = p.lat; draft.lon = p.lon
                        draft.tz = p.tz; draft.countryCode = p.countryCode
                    }

                Picker("Giới tính", selection: $draft.gender) {
                    Text("Nữ").tag("Female")
                    Text("Nam").tag("Male")
                    Text("Khác").tag("Other")
                }
                .pickerStyle(.segmented)

                Toggle("Lưu vào danh sách hồ sơ", isOn: $saveToStore)
                    .font(Theme.Fonts.footnote)
                    .tint(Theme.Colors.accent)

                if saveToStore && store.nameExists(draft.name) {
                    TBanner(.danger, "Đã có hồ sơ tên “\(draft.name)” — đổi tên hoặc bỏ tick lưu.")
                }
            }
        }
    }

    private func hmBox(_ label: String, _ v: Binding<Int>, _ range: ClosedRange<Int>) -> some View {
        VStack(spacing: 2) {
            TextField(label, value: v, format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(Theme.Fonts.numeric)
                .padding(.vertical, 10)
                .background(Theme.Colors.bgChip)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))
                .onChange(of: v.wrappedValue) { _, nv in
                    if nv < range.lowerBound { v.wrappedValue = range.lowerBound }
                    if nv > range.upperBound { v.wrappedValue = range.upperBound }
                }
            Text(label).font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.textMuted)
        }
    }
}

// MARK: - Hồ sơ mặc định cho ô nhập mới --------------------------------------

public extension BirthProfile {
    /// Bản nháp trống, mặc định Hà Nội — giống `default_loc` của web (`transits.py:34`).
    static func draftDefault() -> BirthProfile {
        let hn = GeoPlaceTable.vietnam[0]
        return BirthProfile(name: "", gender: "Female",
                            day: 1, month: 1, year: 1990, hour: 12, minute: 0,
                            address: hn.shortName, lat: hn.lat, lon: hn.lon,
                            tz: hn.tz, countryCode: hn.countryCode)
    }
}
