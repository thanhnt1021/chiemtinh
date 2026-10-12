//  TransitGeneralScreen.swift
//  MÀN 2/4 — port `/vanhan/chung` (`app/routes/transits.py:29-53`,
//  `app/templates/transit_general.html`).
//
//  GIỮ NGUYÊN hành vi web:
//   • thời điểm LUÔN là "bây giờ" theo giờ Việt Nam (`transits.py:33,44`);
//   • đối tượng cứng "Chart of the moment" (dropdown bị disable — transit_general.html:29-31);
//   • địa điểm mặc định Hà Nội `21.0283334 / 105.854041 / Asia/Bangkok` (`transits.py:34`);
//   • có ô "Hiển thị Góc thật (Show Real Orb)";
//   • bảng VỊ TRÍ HÀNH TINH 3 cột, 13 đối tượng, KHÔNG có cột Nhà (`reports/transit.py:8-26`).

import SwiftUI

public struct TransitGeneralScreen: View {

    /// `transits.py:34` — nguyên văn giá trị mặc định của web.
    private static let webDefault = GeoPlace(
        id: "web-default-hanoi", name: "Hà Nội", admin: "Hà Nội",
        countryCode: "vn", countryName: "Vietnam",
        lat: 21.0283334, lon: 105.854041, tz: "Asia/Bangkok", aliases: ["Ha Noi"])

    @State private var place: GeoPlace = TransitGeneralScreen.webDefault
    @State private var showRealOrb = false
    @State private var chart: Chart? = nil
    @State private var rows: [CurrentSkyRow] = []
    @State private var stamp: String = ""
    @State private var running = false
    @State private var error: String? = nil
    @State private var task: Task<Void, Never>? = nil

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.lg) {

                TCard("Vận Hạn Chung (Current Sky)") {
                    VStack(alignment: .leading, spacing: Theme.Space.md) {
                        HStack {
                            Text("Đối tượng").font(Theme.Fonts.footnote)
                                .foregroundStyle(Theme.Colors.textSecondary)
                            Spacer()
                            Text("Chart of the moment")
                                .font(Theme.Fonts.footnote).bold()
                                .foregroundStyle(Theme.Colors.textMuted)
                        }
                        LocationPickerView(place: $place)
                        Toggle("Hiển thị “Góc thật” (Show Real Orb)", isOn: $showRealOrb)
                            .font(Theme.Fonts.footnote).tint(Theme.Colors.accent)
                        TPrimaryButton("Check Current Planets", busy: running) { run() }
                    }
                }

                if let error { TBanner(.danger, error) }

                if let ch = chart {
                    TCard("Chart of the Moment") {
                        VStack(alignment: .leading, spacing: Theme.Space.sm) {
                            Text(stamp).font(Theme.Fonts.title2)
                                .foregroundStyle(Theme.Colors.accent)
                            // ĐÚNG tham số web dùng: hide_houses=True, static_aries_asc=True (transits.py:47)
                            // W21: PHẢI có chiều cao tường minh — `NatalWheelView` bọc
                            // `ZoomPanChart` trong `GeometryReader` nên chiều cao nội tại = 0,
                            // trước đây bánh xe bị bóp thành dải ~10pt (đã chụp ảnh).
                            NatalWheelView(model: NatalWheelModel(chart: ch, title: stamp,
                                                                 hideHouses: true, staticAriesAsc: true))
                                .frame(height: 400)
                        }
                    }

                    TCard("Bảng góc hợp (Current Sky)") {
                        // W21: cờ "Góc thật" nay đi thẳng vào model (grid.py:116 show_real_orb),
                        // không chỉ đổi tiêu đề như trước.
                        NatalAspectGridView(model: NatalAspectGridModel(chart: ch,
                                                                        showRealOrb: showRealOrb),
                                       title: showRealOrb ? "Bảng góc hợp — góc thật" : "Bảng góc hợp")
                    }

                    TCard("Vị trí hành tinh") {
                        VStack(spacing: 0) {
                            HStack {
                                Text("HÀNH TINH").frame(maxWidth: .infinity, alignment: .leading)
                                Text("CUNG").frame(width: 70)
                                Text("ĐỘ").frame(width: 78)
                            }
                            .font(Theme.Fonts.caps)
                            .foregroundStyle(Theme.Colors.textSecondary)
                            .padding(.vertical, Theme.Space.sm)
                            Divider().overlay(Theme.Colors.separator)

                            ForEach(rows) { r in
                                HStack {
                                    TPlanetCell(symbol: r.planetSymbol, name: r.planet,
                                                tint: TransitPalette.planet(r.planet))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    Text(r.zodiacSymbol)
                                        .font(.system(size: 17, weight: .bold))
                                        .foregroundStyle(Theme.Colors.textSecondary)
                                        .frame(width: 70)
                                    Text(r.degreeText)
                                        .font(Theme.Fonts.numericSmall)
                                        .foregroundStyle(Theme.Colors.textPrimary)
                                        .frame(width: 78)
                                }
                                .frame(minHeight: Theme.Layout.rowMinHeight)
                                Divider().overlay(Theme.Colors.separator)
                            }
                        }
                    }

                    if let ch = chart {
                        TCard("Thông tin kỹ thuật") {
                            VStack(alignment: .leading, spacing: Theme.Space.xs) {
                                info("Giờ địa phương", ch.info.localTime)
                                info("Universal Time", ch.info.utTime)
                                info("Local Sidereal Time", ch.info.lst)
                                info("Hệ nhà", ch.info.houseSys)
                                info("Toạ độ", ch.info.latLon)
                                info("Bảng góc hợp", showRealOrb ? "Góc thật (real orb)" : "Góc làm tròn")
                            }
                        }
                    }
                }
            }
            .padding(Theme.Space.screenH)
        }
        .background(Theme.Colors.bgBase)
        .navigationTitle("Vận Hạn Chung")
        .navigationBarTitleDisplayMode(.inline)
        .task { W20Services.install() }
        .onAppear { if chart == nil { run() } }
        .onDisappear { task?.cancel() }
    }

    private func info(_ k: String, _ v: String) -> some View {
        HStack(alignment: .top) {
            Text(k).font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.textSecondary)
            Spacer(minLength: Theme.Space.md)
            Text(v).font(Theme.Fonts.numericSmall).foregroundStyle(Theme.Colors.textPrimary)
                .multilineTextAlignment(.trailing)
        }
    }

    private func run() {
        task?.cancel()
        running = true; error = nil
        let p = place
        task = Task {
            // "bây giờ" theo giờ Việt Nam — `pytz.timezone('Asia/Ho_Chi_Minh')` (transits.py:32-33)
            let nowVN = TransitGeneralScreen.nowInVietnam()
            let c = await TransitEngine.shared.currentSkyChart(now: nowVN, lat: p.lat, lon: p.lon, tz: p.tz)
            if Task.isCancelled { return }
            await MainActor.run {
                running = false
                guard let c else { error = "Không dựng được bản đồ sao hiện tại."; return }
                chart = c
                rows = TransitReports.currentSky(c)
                stamp = String(format: "Current Sky (%02d:%02d — %@)", nowVN.hour, nowVN.minute, nowVN.dmy)
            }
        }
    }

    /// Giờ tường Việt Nam ngay lúc này (UTC+7, không có DST kể từ 1975).
    static func nowInVietnam() -> CivilDateTime {
        let utc = AstroCore.currentUTC()
        return utc.minusHours(-7)
    }
}
