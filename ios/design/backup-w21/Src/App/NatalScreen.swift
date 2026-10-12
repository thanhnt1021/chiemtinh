//  NatalScreen.swift
//  Màn hình TỐI THIỂU của lượt này: nhập ngày/giờ/nơi sinh -> bảng vị trí hành tinh + 12 nhà.
//  Chưa vẽ bánh xe, chưa synastry/transit/composite (các mảng đó ở lượt sau).

import SwiftUI

struct NatalScreen: View {
    /// Lịch cố định UTC: DatePicker chỉ dùng để CHỌN giờ tường (wall clock).
    /// Ép múi giờ 0 để lấy ra đúng y/m/d/H/M người dùng thấy, không bị máy đổi giờ.
    private static let wallCalendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(secondsFromGMT: 0)!
        return c
    }()

    @State private var birth: Date = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(secondsFromGMT: 0)!
        return c.date(from: DateComponents(year: 1990, month: 5, day: 15, hour: 7, minute: 30))!
    }()
    @State private var place: PlaceOption = VNLocations.all[0]
    @State private var chart: Chart? = nil
    @State private var errorText: String? = nil

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
                technicalSection(ch)
                planetsSection(ch)
                housesSection(ch)
            }
            footerSection
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(ScreenBackground())
        .onAppear(perform: recalc)
    }

    // MARK: - Nhập liệu

    private var inputSection: some View {
        Section("Dữ liệu sinh") {
            DatePicker("Ngày sinh", selection: $birth, in: birthRange, displayedComponents: .date)
                .environment(\.timeZone, TimeZone(secondsFromGMT: 0)!)
            DatePicker("Giờ sinh", selection: $birth, in: birthRange, displayedComponents: .hourAndMinute)
                .environment(\.timeZone, TimeZone(secondsFromGMT: 0)!)
            Picker("Nơi sinh", selection: $place) {
                ForEach(VNLocations.all) { p in Text(p.name).tag(p) }
            }
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
            Text(AstroConst.planetSymbols[name] ?? "?")
                .font(.system(size: 20))
                .lineLimit(1)                 // "MC"/"AC"/"Vx" là 2 ký tự — cấm xuống dòng
                .minimumScaleFactor(0.6)
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

    // MARK: - Tính

    private func recalc() {
        let c = Self.wallCalendar.dateComponents([.year, .month, .day, .hour, .minute], from: birth)
        let dob = String(format: "%02d/%02d/%04d", c.day ?? 1, c.month ?? 1, c.year ?? 1990)
        let tob = String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0)
        if let c = AstroCore.calculateChart(dobStr: dob, tobStr: tob,
                                            lat: place.lat, lon: place.lon,
                                            tzStr: place.tz, manualOffset: nil) {
            chart = c
            errorText = nil
        } else {
            chart = nil
            errorText = "Không tính được bản đồ sao cho \(dob) \(tob) tại \(place.name). Kiểm tra lại ngày/giờ."
        }
    }
}

#Preview { NavigationStack { NatalScreen() } }
