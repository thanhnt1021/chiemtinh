//  ProfileFormView.swift
//  Nhập / sửa hồ sơ sinh. Đối chiếu web: `/input` và `/edit_profile/<name>`
//  (`app/templates/input.html:38-87`, `app/routes/main.py:56-100`).
//  Trường giữ đủ như web: Họ tên · D/M/Y · Giờ/Phút · Nơi sinh · Giới tính · Múi giờ nhập tay.
//
//  Nơi sinh KHÔNG tự làm bảng địa điểm — gọi qua `LocationSearch.provider`
//  (protocol ở `LocationProviding.swift`, bản đầy đủ do `Src/Data/` cắm vào).

import SwiftUI

public struct ProfileFormView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss

    private let editingID: UUID?

    @State private var name: String = ""
    @State private var gender: ProfileGender = .female
    @State private var day: Int = 1
    @State private var month: Int = 1
    @State private var year: Int = 1990
    @State private var hour: Int = 12
    @State private var minute: Int = 0
    @State private var timeUnknown: Bool = false
    @State private var place: AstroPlace = .defaultHanoi
    @State private var useManualTZ: Bool = false
    @State private var manualTZ: Double = 7.0

    @State private var showPlacePicker = false
    @State private var loaded = false

    public init(editingID: UUID? = nil) { self.editingID = editingID }

    private var isEditing: Bool { editingID != nil }
    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var nameClashes: Bool { app.nameExists(trimmedName, excluding: editingID) }
    private var canSave: Bool { !trimmedName.isEmpty && !nameClashes && dayIsValid }
    private var dayIsValid: Bool { day >= 1 && day <= Self.daysIn(month: month, year: year) }

    public var body: some View {
        ZStack {
            ScreenBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.xl) {
                    identityCard
                    birthDateCard
                    placeCard
                    advancedCard
                    saveBar
                }
                .screenPadding()
                .padding(.vertical, Theme.Space.lg)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle(isEditing ? "Chỉnh sửa hồ sơ" : "Thêm hồ sơ mới")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPlacePicker) {
            PlacePickerView(selected: $place)
        }
        .onAppear(perform: loadIfNeeded)
    }

    // MARK: - Khối 1: danh tính

    private var identityCard: some View {
        AstroCard {
            VStack(alignment: .leading, spacing: Theme.Space.md) {
                SectionHeader("Danh tính", style: .caps)

                VStack(alignment: .leading, spacing: Theme.Space.xs) {
                    Text("Họ tên")
                        .font(Theme.Fonts.subheadline)
                        .foregroundStyle(Theme.Colors.textSecondary)
                    TextField("Ví dụ: Nguyễn Văn A", text: $name)
                        .font(Theme.Fonts.body)
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .textInputAutocapitalization(.words)
                        .padding(.horizontal, Theme.Space.md)
                        .frame(height: Theme.Layout.touchTarget)
                        .background(Theme.Colors.bgSunken)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                                .stroke(nameClashes ? Theme.Colors.danger : Theme.Colors.borderStrong,
                                        lineWidth: 1)
                        )
                    if nameClashes {
                        Text("Đã có hồ sơ trùng tên này.")
                            .font(Theme.Fonts.caption)
                            .foregroundStyle(Theme.Colors.danger)
                    }
                }

                VStack(alignment: .leading, spacing: Theme.Space.xs) {
                    Text("Giới tính")
                        .font(Theme.Fonts.subheadline)
                        .foregroundStyle(Theme.Colors.textSecondary)
                    Picker("Giới tính", selection: $gender) {
                        ForEach(ProfileGender.allCases) { g in
                            Text(g.labelVN).tag(g)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
        }
    }

    // MARK: - Khối 2: ngày giờ sinh

    private var birthDateCard: some View {
        AstroCard {
            VStack(alignment: .leading, spacing: Theme.Space.md) {
                SectionHeader("Ngày & giờ sinh", style: .caps)

                HStack(spacing: Theme.Space.md) {
                    NumberField(title: "Ngày", value: $day, range: 1...Self.daysIn(month: month, year: year))
                    NumberField(title: "Tháng", value: $month, range: 1...12)
                    NumberField(title: "Năm", value: $year, range: 1800...2099, width: 88)
                }

                Toggle(isOn: $timeUnknown) {
                    Text("Không biết giờ sinh")
                        .font(Theme.Fonts.subheadline)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
                .tint(Theme.Colors.accent)

                if timeUnknown {
                    Chip("Sẽ dùng 12:00 — nhà, AC và MC chỉ mang tính tham khảo",
                         systemImage: "exclamationmark.triangle", tone: .warning)
                } else {
                    HStack(spacing: Theme.Space.md) {
                        NumberField(title: "Giờ", value: $hour, range: 0...23)
                        NumberField(title: "Phút", value: $minute, range: 0...59)
                        Spacer(minLength: 0)
                    }
                }
            }
        }
    }

    // MARK: - Khối 3: nơi sinh

    private var placeCard: some View {
        AstroCard {
            VStack(alignment: .leading, spacing: Theme.Space.md) {
                SectionHeader("Nơi sinh", style: .caps)

                Button {
                    showPlacePicker = true
                } label: {
                    HStack(spacing: Theme.Space.md) {
                        GlyphBadge(tint: Theme.Colors.accent, size: 36) {
                            Image(systemName: "mappin.and.ellipse").font(.system(size: 15, weight: .semibold))
                        }
                        VStack(alignment: .leading, spacing: Theme.Space.xxs) {
                            Text(place.displayName)
                                .font(Theme.Fonts.headline)
                                .foregroundStyle(Theme.Colors.textPrimary)
                                .multilineTextAlignment(.leading)
                            Text(coordLine)
                                .font(Theme.Fonts.caption)
                                .foregroundStyle(Theme.Colors.textMuted)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.Colors.textMuted)
                    }
                    .frame(minHeight: Theme.Layout.touchTarget)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var coordLine: String {
        String(format: "%.4f, %.4f · %@", place.lat, place.lon, place.tz)
    }

    // MARK: - Khối 4: nâng cao

    private var advancedCard: some View {
        AstroCard {
            VStack(alignment: .leading, spacing: Theme.Space.md) {
                SectionHeader("Tuỳ chọn nâng cao", subtitle: "Chỉ dùng khi bạn biết chắc múi giờ.",
                              style: .caps)

                Toggle(isOn: $useManualTZ) {
                    Text("Nhập múi giờ thủ công")
                        .font(Theme.Fonts.subheadline)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
                .tint(Theme.Colors.accent)

                if useManualTZ {
                    HStack {
                        Text("GMT")
                            .font(Theme.Fonts.subheadline)
                            .foregroundStyle(Theme.Colors.textSecondary)
                        Spacer()
                        Stepper(value: $manualTZ, in: -12...14, step: 0.5) {
                            Text(String(format: "%+.1f", manualTZ))
                                .numericStyle()
                                .foregroundStyle(Theme.Colors.accent)
                        }
                        .frame(maxWidth: 160)
                    }
                    .frame(minHeight: Theme.Layout.touchTarget)
                } else {
                    Text("Để trống, app tự tính múi giờ theo nơi sinh — kể cả bảng múi giờ lịch sử Việt Nam.")
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(Theme.Colors.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    // MARK: - Lưu

    private var saveBar: some View {
        VStack(spacing: Theme.Space.md) {
            Button(isEditing ? "Cập nhật hồ sơ" : "Lưu hồ sơ", action: save)
                .buttonStyle(.astroPrimary)
                .disabled(!canSave)

            if isEditing, let id = editingID {
                Button("Xoá hồ sơ này", role: .destructive) {
                    app.delete(id: id)
                    dismiss()
                }
                .buttonStyle(.astroGhost)
                .tint(Theme.Colors.danger)
            }
        }
    }

    private func save() {
        let p = SavedProfile(
            id: editingID ?? UUID(),
            name: trimmedName,
            gender: gender,
            day: day, month: month, year: year,
            hour: timeUnknown ? 12 : hour,
            minute: timeUnknown ? 0 : minute,
            timeUnknown: timeUnknown,
            place: place,
            manualTZOffset: useManualTZ ? manualTZ : nil
        )
        app.upsert(p)
        dismiss()
    }

    private func loadIfNeeded() {
        guard !loaded else { return }
        loaded = true
        guard let id = editingID, let p = app.profiles.first(where: { $0.id == id }) else { return }
        name = p.name; gender = p.gender
        day = p.day; month = p.month; year = p.year
        hour = p.hour; minute = p.minute
        timeUnknown = p.timeUnknown
        place = p.place
        if let tz = p.manualTZOffset { useManualTZ = true; manualTZ = tz }
    }

    /// Số ngày của tháng — chặn 31/2 ngay ở form (web làm việc này bằng JS `base.html:196-306`).
    static func daysIn(month: Int, year: Int) -> Int {
        var c = DateComponents(); c.year = year; c.month = month
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        guard let d = cal.date(from: c),
              let r = cal.range(of: .day, in: .month, for: d) else { return 31 }
        return r.count
    }
}

// MARK: - Ô số có nút ▲▼ (bản native của "Smart Spinner" web, base.html:196-306) ----

struct NumberField: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    var width: CGFloat = 72

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.xs) {
            Text(title)
                .font(Theme.Fonts.caption)
                .foregroundStyle(Theme.Colors.textMuted)
            HStack(spacing: 0) {
                Text("\(value)")
                    .numericStyle()
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .frame(maxWidth: .infinity)
                VStack(spacing: 0) {
                    stepButton(systemImage: "chevron.up", delta: 1)
                    stepButton(systemImage: "chevron.down", delta: -1)
                }
                .frame(width: 26)
            }
            .padding(.leading, Theme.Space.sm)
            .frame(width: width, height: Theme.Layout.touchTarget)
            .background(Theme.Colors.bgSunken)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                    .stroke(Theme.Colors.borderStrong, lineWidth: 1)
            )
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(title))
        .accessibilityValue(Text("\(value)"))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: bump(1)
            case .decrement: bump(-1)
            default: break
            }
        }
    }

    private func stepButton(systemImage: String, delta: Int) -> some View {
        Button {
            bump(delta)
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Theme.Colors.accent)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// Cuộn vòng như spinner của web: quá trần thì về đáy và ngược lại.
    private func bump(_ delta: Int) {
        var v = value + delta
        if v > range.upperBound { v = range.lowerBound }
        if v < range.lowerBound { v = range.upperBound }
        value = v
    }
}

// MARK: - Chọn nơi sinh -------------------------------------------------------

/// Sheet tìm địa danh. Toàn bộ dữ liệu đến từ `LocationSearch.provider`
/// — màn này KHÔNG chứa bảng địa điểm nào của riêng nó.
struct PlacePickerView: View {
    @Binding var selected: AstroPlace
    @Environment(\.dismiss) private var dismiss

    @State private var query: String = ""
    @State private var countryCode: String? = "vn"
    @State private var results: [AstroPlace] = []
    @State private var isSearching = false
    @State private var errorText: String?
    @State private var searchTask: Task<Void, Never>?

    private var countries: [(name: String, code: String)] { LocationSearch.provider.countries }

    var body: some View {
        NavigationStack {
            ZStack {
                ScreenBackground()
                VStack(spacing: Theme.Space.md) {
                    if countries.count > 1 {
                        Picker("Quốc gia", selection: $countryCode) {
                            Text("Toàn thế giới").tag(String?.none)
                            ForEach(countries, id: \.code) { c in
                                Text(c.name).tag(String?.some(c.code))
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(Theme.Colors.accent)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if isSearching {
                        LoadingBlock("Đang tìm địa danh…")
                    } else if let errorText {
                        AstroCard {
                            Text(errorText)
                                .font(Theme.Fonts.footnote)
                                .foregroundStyle(Theme.Colors.danger)
                        }
                    }

                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(results) { p in
                                Button {
                                    selected = p
                                    dismiss()
                                } label: {
                                    DataRow(p.displayName,
                                            value: String(format: "%.2f, %.2f", p.lat, p.lon),
                                            detail: p.tz,
                                            showsSeparator: p.id != results.last?.id)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, Theme.Space.lg)
                        .background(Theme.Colors.bgSurface)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                                .stroke(Theme.Colors.border, lineWidth: 1)
                        )
                    }
                    .scrollIndicators(.hidden)

                    Spacer(minLength: 0)
                }
                .screenPadding()
                .padding(.top, Theme.Space.md)
            }
            .navigationTitle("Nơi sinh")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Xong") { dismiss() }.tint(Theme.Colors.accent)
                }
            }
            .searchable(text: $query, prompt: "Tìm thành phố, tỉnh…")
            .onChange(of: query) { _, _ in scheduleSearch() }
            .onChange(of: countryCode) { _, _ in scheduleSearch() }
            .task { await runSearch() }
        }
    }

    /// Gõ tới đâu tìm tới đó, hoãn 400ms (web dùng debounce 600ms — `macros/location_picker.html:81-84`).
    private func scheduleSearch() {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 400_000_000)
            if Task.isCancelled { return }
            await runSearch()
        }
    }

    @MainActor
    private func runSearch() async {
        isSearching = true
        errorText = nil
        do {
            results = try await LocationSearch.provider.search(query: query, countryCode: countryCode)
        } catch {
            results = []
            errorText = "Không tìm được địa danh: \(error.localizedDescription)"
        }
        isSearching = false
    }
}

#Preview {
    NavigationStack { ProfileFormView() }.environmentObject(AppState())
}
