//  NatalScreen.swift
//  MÀN LÁ SỐ — port `/natal` (`app/routes/charts.py:18-90`, `app/templates/natal.html`).
//
//  W21 (gộp app) đã nối 3 thứ còn treo ở đây:
//   1. BÁNH XE SAO: trước chỉ có bảng số. Nay có bánh xe vẽ ngay trong màn
//      (`NatalWheelView` của Src/Chart) + nút mở TOÀN MÀN HÌNH sang `ChartHubView`
//      (bánh xe · bảng góc, có zoom/pan bằng `ZoomPanChart`).
//   2. NƠI SINH: bỏ bảng tạm 12 tỉnh (`VNLocations` — đã xoá), dùng chung
//      `PlacePickerView` + `LocationSearch.provider` (bảng 177 địa điểm của Src/Data).
//   3. HỒ SƠ: mồi sẵn ngày/giờ/nơi sinh từ hồ sơ đang chọn trong `AppState`
//      (kho SwiftData duy nhất), thay vì luôn mở ra ngày mẫu 15/05/1990.

import SwiftUI

struct NatalScreen: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.colorScheme) private var scheme

    /// Lịch cố định UTC: DatePicker chỉ dùng để CHỌN giờ tường (wall clock).
    /// Ép múi giờ 0 để lấy ra đúng y/m/d/H/M người dùng thấy, không bị máy đổi giờ.
    private static let wallCalendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(secondsFromGMT: 0)!
        return c
    }()

    private static func wallDate(y: Int, m: Int, d: Int, h: Int, mi: Int) -> Date {
        wallCalendar.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: mi))
            ?? Date(timeIntervalSince1970: 0)
    }

    @State private var birth: Date = NatalScreen.wallDate(y: 1990, m: 5, d: 15, h: 7, mi: 30)
    @State private var place: AstroPlace = .defaultHanoi
    @State private var showPlacePicker = false
    @State private var chart: Chart? = nil
    @State private var errorText: String? = nil
    @State private var chartName: String = "Lá số"
    @State private var seeded = false

    private var birthRange: ClosedRange<Date> {
        let c = Self.wallCalendar
        let lo = c.date(from: DateComponents(year: 1800, month: 1, day: 1))!
        let hi = c.date(from: DateComponents(year: 2099, month: 12, day: 31, hour: 23, minute: 59))!
        return lo...hi
    }

    // Màn này được ĐẨY VÀO một NavigationStack có sẵn (DashboardView / ProfileListView),
    // nên KHÔNG tự dựng NavigationStack nữa — tránh lồng 2 thanh điều hướng.
    var body: some View {
        List {
            inputSection
            if let e = errorText {
                Section { Label(e, systemImage: "exclamationmark.triangle").foregroundStyle(.red) }
            }
            if let ch = chart {
                wheelSection(ch)
                technicalSection(ch)
                planetsSection(ch)
                housesSection(ch)
            }
            footerSection
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(ScreenBackground())
        .onAppear { seedFromProfileIfNeeded(); recalc() }
        .sheet(isPresented: $showPlacePicker) {
            PlacePickerView(selected: $place)
        }
    }

    // MARK: - Nhập liệu

    private var inputSection: some View {
        Section("Dữ liệu sinh") {
            if !app.profiles.isEmpty {
                Picker("Hồ sơ", selection: Binding(
                    get: { app.selectedProfileID ?? app.profiles.first?.id },
                    set: { id in
                        app.selectedProfileID = id
                        seeded = false
                        seedFromProfileIfNeeded()
                        recalc()
                    })) {
                    ForEach(app.profiles) { p in Text(p.name).tag(Optional(p.id)) }
                }
            }
            DatePicker("Ngày sinh", selection: $birth, in: birthRange, displayedComponents: .date)
                .environment(\.timeZone, TimeZone(secondsFromGMT: 0)!)
            DatePicker("Giờ sinh", selection: $birth, in: birthRange, displayedComponents: .hourAndMinute)
                .environment(\.timeZone, TimeZone(secondsFromGMT: 0)!)

            // Nơi sinh: dùng CHUNG bộ tìm địa danh của `LocationSearch.provider`.
            Button { showPlacePicker = true } label: {
                HStack(alignment: .firstTextBaseline) {
                    Text("Nơi sinh").foregroundStyle(.secondary)
                    Spacer(minLength: 12)
                    Text(place.displayName)
                        .multilineTextAlignment(.trailing)
                        .lineLimit(2)
                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)

            Button {
                recalc()
            } label: {
                Label("Tính bản đồ sao", systemImage: "sparkles")
                    .frame(maxWidth: .infinity, alignment: .center)
                    .fontWeight(.semibold)
            }
            .buttonStyle(.borderedProminent)
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        }
        .onChange(of: birth) { _, _ in recalc() }
        .onChange(of: place) { _, _ in recalc() }
    }

    // MARK: - BÁNH XE SAO (thứ founder hỏi thẳng)

    private func wheelSection(_ ch: Chart) -> some View {
        Section("Bản đồ sao") {
            // XEM TRƯỚC TĨNH: vẽ thẳng bằng `NatalWheelCanvas`, KHÔNG bọc `ZoomPanChart`.
            // Lý do: `ZoomPanChart` có `DragGesture` nuốt luôn cử chỉ cuộn dọc của `List`,
            // đặt trong danh sách thì không vuốt qua được (đã chụp ảnh thấy kẹt).
            // Muốn zoom/pan thì bấm "Mở toàn màn hình" ngay dưới.
            GeometryReader { geo in
                NatalWheelCanvas(model: NatalWheelModel(chart: ch, title: chartName),
                                 palette: ChartPalette(scheme), selected: nil,
                                 viewport: ChartViewport(), size: geo.size)
            }
            .frame(height: 340)
            .listRowInsets(EdgeInsets())
            .allowsHitTesting(false)

            NavigationLink {
                ChartHubView(chartA: ch, nameA: chartName)
            } label: {
                Label("Mở toàn màn hình · bánh xe & bảng góc", systemImage: "arrow.up.left.and.arrow.down.right")
            }

            NavigationLink {
                NatalAspectGridView(model: NatalAspectGridModel(chart: ch),
                                    title: "Góc chiếu — \(chartName)")
            } label: {
                Label("Bảng góc chiếu (aspect grid)", systemImage: "square.grid.3x3")
            }
        }
    }

    // MARK: - Kết quả

    private func technicalSection(_ ch: Chart) -> some View {
        Section("Thông tin kỹ thuật") {
            infoRow("Giờ địa phương", ch.info.localTime)
            infoRow("Giờ UT", ch.info.utTime)
            infoRow("Giờ sao (LST)", ch.info.lst)
            infoRow("Toạ độ", ch.info.latLon)
            infoRow("Hệ nhà", ch.info.houseSys)
            infoRow("Julian Day", String(format: "%.6f", ch.jd))
        }
    }

    private func infoRow(_ k: String, _ v: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(k).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(v).monospacedDigit().multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
    }

    private func planetsSection(_ ch: Chart) -> some View {
        Section("Vị trí hành tinh") {
            ForEach(AstroConst.fullObjectsOrder, id: \.self) { name in
                if let p = ch.planets[name] {
                    planetRow(name: name, p: p, cusps: ch.cusps)
                }
            }
        }
    }

    private func planetRow(name: String, p: PlanetPosition, cusps: [Double]) -> some View {
        let z = AstroCore.getZodiac(p.lon)
        let house = AstroCore.getHouseOfPlanet(p.lon, cusps)
        let retro = p.speed < 0
        return HStack(spacing: 10) {
            // Dùng view glyph CHUNG (Src/Design/Glyphs.swift): 5 ký hiệu font hệ thống
            // KHÔNG có (⚷ ⚸ ⚹ ⚺ ⚻) ra nét vector, thiếu glyph khác thì rơi về mã chữ.
            AstroGlyph(planet: name, size: 20)
                .frame(width: 36, alignment: .center)
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.subheadline).fontWeight(.medium)
                Text("\(z.name) · nhà \(house)")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .trailing, spacing: 2) {
                Text(degMinString(z.degInSign)).monospacedDigit().font(.subheadline)
                if retro {
                    Text("nghịch hành ℞").font(.caption2).foregroundStyle(.orange)
                } else {
                    Text(String(format: "%+.4f°/ng", p.speed))
                        .font(.caption2).foregroundStyle(.secondary).monospacedDigit()
                }
            }
        }
    }

    private func housesSection(_ ch: Chart) -> some View {
        Section("12 đỉnh nhà (Placidus)") {
            ForEach(0..<ch.cusps.count, id: \.self) { i in
                let z = AstroCore.getZodiac(ch.cusps[i])
                HStack {
                    Text("Nhà \(i + 1)")
                        .font(.subheadline).fontWeight(.medium)
                        .frame(width: 62, alignment: .leading)
                    Text(z.name).font(.subheadline).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(degMinString(z.degInSign)).monospacedDigit().font(.subheadline)
                }
            }
        }
    }

    private var footerSection: some View {
        Section {
            Text("Tính bằng Swiss Ephemeris \(SwissEph.version()) biên dịch thẳng vào app — không gọi máy chủ.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private func degMinString(_ deg: Double) -> String {
        let d = Int(deg)
        var m = Int((deg - Double(d)) * 60)
        var dd = d
        if m == 60 { m = 0; dd += 1 }
        return String(format: "%02d°%02d'", dd, m)
    }

    // MARK: - Mồi từ hồ sơ đang chọn

    private func seedFromProfileIfNeeded() {
        guard !seeded else { return }
        seeded = true
        guard let p = app.selectedProfile else { return }
        birth = Self.wallDate(y: p.year, m: p.month, d: p.day,
                              h: p.timeUnknown ? 12 : p.hour,
                              mi: p.timeUnknown ? 0 : p.minute)
        place = p.place
        chartName = p.name
    }

    // MARK: - Tính

    private func recalc() {
        let c = Self.wallCalendar.dateComponents([.year, .month, .day, .hour, .minute], from: birth)
        let dob = String(format: "%02d/%02d/%04d", c.day ?? 1, c.month ?? 1, c.year ?? 1990)
        let tob = String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0)
        if let ch = AstroCore.calculateChart(dobStr: dob, tobStr: tob,
                                             lat: place.lat, lon: place.lon,
                                             tzStr: place.tz, manualOffset: nil) {
            chart = ch
            errorText = nil
        } else {
            chart = nil
            errorText = "Không tính được bản đồ sao cho \(dob) \(tob) tại \(place.displayName). Kiểm tra lại ngày/giờ."
        }
    }
}

#Preview { NavigationStack { NatalScreen() }.environmentObject(AppState()) }
