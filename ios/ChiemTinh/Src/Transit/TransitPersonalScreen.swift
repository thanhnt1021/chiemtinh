//  TransitPersonalScreen.swift
//  MÀN 3/4 — port `/vanhan/rieng` (`app/routes/transits.py:78-158`,
//  `app/templates/transit_personal.html`, 195 dòng).
//
//  ĐỦ MỌI THỨ WEB CÓ:
//   • tab "Có sẵn / Nhập mới" + lưu hồ sơ (transit_personal.html:31-70)
//   • chế độ "Xem Transit Thường" (single) và "Xem Đại Hạn Tương Lai" (outer_cycle)
//   • single: 3 ô D/M/Y; outer_cycle: 2 ô ngày + kiểm tra "tối đa 5 năm" (dòng 176-179)
//   • nút đổi màu/đổi chữ theo chế độ (dòng 100-102)
//   • bảng NHÀ TRANSIT (single có link "Xem" → modal Nhà; outer_cycle có cột nhà kết thúc)
//   • bảng GÓC TRANSIT 2 khối + bộ lọc độ lệch < 3º/2º/1º/0.5º (reports/transit.py:98)
//   • khối "TRA CỨU GIAI ĐOẠN HỒI VỊ" (chỉ chế độ single, dòng 126-134)

import SwiftUI

public struct TransitPersonalScreen: View {

    @ObservedObject public var store: ProfileStore

    // Nhập liệu
    @State private var mode: ProfileSelectorView.Mode = .existing
    @State private var selectedName: String = ""
    @State private var draft: BirthProfile = .draftDefault()
    @State private var saveToStore = false
    @State private var transitMode: TransitReports.TransitMode = .single

    @State private var tDay: Int
    @State private var tMonth: Int
    @State private var tYear: Int
    @State private var rangeStart: Date
    @State private var rangeEnd: Date

    // Kết quả
    @State private var result: TransitEngine.PersonalResult? = nil
    @State private var activeProfile: BirthProfile? = nil
    @State private var running = false
    @State private var error: String? = nil
    @State private var task: Task<Void, Never>? = nil

    // Bộ lọc + modal
    @State private var orbFilter: Double = 3.0
    @State private var returnPlanet: String = AstroConst.returnPlanetOrder[0]
    @State private var sheetAspect: TransitReports.TransitAspectRow? = nil
    @State private var sheetHousePlanet: String? = nil
    @State private var showReturnSheet = false

    public init(store: ProfileStore = .shared, initialProfileName: String? = nil,
                initialDate: CivilDateTime? = nil) {
        self.store = store
        let today = TransitGeneralScreen.nowInVietnam()
        let d = initialDate ?? today
        _tDay = State(initialValue: d.day)
        _tMonth = State(initialValue: d.month)
        _tYear = State(initialValue: d.year)
        _rangeStart = State(initialValue: TransitDateBridge.date(from: today))
        _rangeEnd = State(initialValue: TransitDateBridge.date(from: today.plusDays(365)))
        _selectedName = State(initialValue: initialProfileName ?? "")
    }

    // MARK: - Thân

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.lg) {
                inputCard
                if let error { TBanner(.danger, error) }
                if let r = result { resultBlocks(r) }
            }
            .padding(Theme.Space.screenH)
        }
        .background(Theme.Colors.bgBase)
        .navigationTitle("Vận Hạn Riêng")
        .navigationBarTitleDisplayMode(.inline)
        .task { W20Services.install() }
        .onDisappear { task?.cancel() }
        .sheet(item: $sheetAspect) { row in
            if let p = activeProfile {
                AspectLookupSheet(profile: p, pTrans: row.transitPlanet,
                                  aspect: row.aspectName, pNatal: row.natalPoint,
                                  date: CivilDateTime(year: tYear, month: tMonth, day: tDay),
                                  onOpenTransit: { d in jump(to: d) })
            }
        }
        .sheet(isPresented: Binding(get: { sheetHousePlanet != nil },
                                    set: { if !$0 { sheetHousePlanet = nil } })) {
            if let p = activeProfile, let pl = sheetHousePlanet {
                HouseTransitLookupSheet(profile: p, planet: pl,
                                        date: CivilDateTime(year: tYear, month: tMonth, day: tDay),
                                        onOpenTransit: { d in jump(to: d) })
            }
        }
        .sheet(isPresented: $showReturnSheet) {
            if let p = activeProfile {
                ReturnLookupSheet(profile: p, planet: returnPlanet,
                                  date: CivilDateTime(year: tYear, month: tMonth, day: tDay),
                                  onOpenTransit: { d in jump(to: d) })
            }
        }
    }

    private func jump(to d: CivilDateTime) {
        transitMode = .single
        tDay = d.day; tMonth = d.month; tYear = d.year
        run()
    }

    // MARK: - Ô nhập

    private var cycleError: String? {
        guard transitMode == .outerCycle else { return nil }
        if rangeEnd < rangeStart { return "⚠️ Ngày không hợp lệ (Bắt đầu phải trước Kết thúc)." }
        let years = rangeEnd.timeIntervalSince(rangeStart) / (86_400 * 365.25)
        if years > 5 { return "⚠️ Thời gian quét tối đa là 5 năm." }
        let s = TransitDateBridge.civil(from: rangeStart), e = TransitDateBridge.civil(from: rangeEnd)
        if !EphemerisWindow.contains(s) || !EphemerisWindow.contains(e) {
            return "⚠️ Khoảng ngày phải nằm trong \(EphemerisWindow.rangeLabel)."
        }
        return nil
    }

    private var inputCard: some View {
        TCard("Vận Hạn Riêng (Transits)") {
            VStack(alignment: .leading, spacing: Theme.Space.md) {
                ProfileSelectorView(store: store, mode: $mode, selectedName: $selectedName,
                                    draft: $draft, saveToStore: $saveToStore)

                Divider().overlay(Theme.Colors.separator)

                Picker("Chế độ xem Transit", selection: $transitMode) {
                    Text("Xem Transit Thường").tag(TransitReports.TransitMode.single)
                    Text("Xem Đại Hạn Tương Lai").tag(TransitReports.TransitMode.outerCycle)
                }
                .pickerStyle(.segmented)

                if transitMode == .single {
                    TDMYField(title: "Ngày/Tháng/Năm muốn xem",
                              day: $tDay, month: $tMonth, year: $tYear)
                } else {
                    VStack(alignment: .leading, spacing: Theme.Space.sm) {
                        DatePicker("Ngày bắt đầu", selection: $rangeStart, displayedComponents: .date)
                            .environment(\.timeZone, TimeZone(secondsFromGMT: 0)!)
                        DatePicker("Ngày kết thúc", selection: $rangeEnd, displayedComponents: .date)
                            .environment(\.timeZone, TimeZone(secondsFromGMT: 0)!)
                        if let m = cycleError { TBanner(.danger, m) }
                    }
                    .font(Theme.Fonts.footnote)
                }

                TPrimaryButton(transitMode == .single ? "XEM TRANSIT RIÊNG" : "XEM ĐẠI HẠN TƯƠNG LAI",
                               tint: transitMode == .single ? Theme.Colors.elementWater : Theme.Colors.danger,
                               busy: running,
                               disabled: cycleError != nil) { run() }
            }
        }
    }

    // MARK: - Kết quả

    @ViewBuilder
    private func resultBlocks(_ r: TransitEngine.PersonalResult) -> some View {
        TCard {
            VStack(alignment: .leading, spacing: Theme.Space.sm) {
                Text(r.title).font(Theme.Fonts.title2).foregroundStyle(Theme.Colors.elementWater)
                if let cycle = r.cycle, !cycle.isEmpty {
                    ForEach(cycle) { s in
                        HStack {
                            TPlanetCell(symbol: AstroConst.planetSymbols[s.planet] ?? s.planet,
                                        name: s.planet, tint: TransitPalette.planet(s.planet))
                            Spacer()
                            Text("\(TransitReports.degreeText(s.spanStart)) → \(TransitReports.degreeText(s.spanEnd))")
                                .font(Theme.Fonts.numericSmall)
                                .foregroundStyle(Theme.Colors.textSecondary)
                            Text(String(format: "%.1f°", s.spanLength))
                                .font(Theme.Fonts.numericSmall)
                                .foregroundStyle(Theme.Colors.accent)
                                .frame(width: 56, alignment: .trailing)
                        }
                        .frame(minHeight: Theme.Layout.rowMinHeight)
                    }
                }
                // W21: đã cắm VÒNG NGOÀI transit — `natal.py:36` transit_data/transit_mode.
                NatalWheelView(model: NatalWheelModel(chart: r.natal, title: r.title,
                                                      transit: wheelTransit(r)))
                    .frame(height: 420)
                TBanner(.info, r.mode == .single
                        ? "Vòng ngoài là vị trí hành tinh transit ngày đã chọn (natal.py:223-239)."
                        : "Vòng ngoài là DẢI QUÉT đại hạn của 5 hành tinh ngoài, mỗi dải một lane không đè nhau (natal.py:45-77, 255-270).")
            }
        }

        houseCard(r)

        if r.mode == .single {
            aspectCard("Góc với các hành tinh", r.aspectPlanets, isPoint: false)
            aspectCard("Góc với các điểm khác", r.aspectPoints, isPoint: true)
            returnLookupCard
        }
    }

    /// Đổi kết quả engine sang gói dữ liệu vòng ngoài của `NatalWheelModel`.
    /// · `.single`     -> `natal.py:226` `transit_data["planets"]`
    /// · `.outerCycle` -> `natal.py:49-55` (start/end/len/A/B) từ `outerCycleData`.
    private func wheelTransit(_ r: TransitEngine.PersonalResult) -> WheelTransitData? {
        switch r.mode {
        case .single:
            return WheelTransitData.single(from: r.transit)
        case .outerCycle:
            guard let cycle = r.cycle, !cycle.isEmpty else { return nil }
            return WheelTransitData(mode: .outerCycle, arcs: cycle.map {
                TransitArcInput(name: $0.planet, start: $0.spanStart, end: $0.spanEnd,
                                length: $0.spanLength, lonA: $0.lonA, lonB: $0.lonB)
            })
        }
    }

    private func houseCard(_ r: TransitEngine.PersonalResult) -> some View {
        TCard("Nhà transit") {
            VStack(spacing: 0) {
                HStack {
                    Text("HÀNH TINH").frame(maxWidth: .infinity, alignment: .leading)
                    Text(r.mode == .outerCycle ? "NHÀ BẮT ĐẦU" : "NHÀ").frame(width: 96)
                    Text(r.mode == .outerCycle ? "NHÀ KẾT THÚC" : "THỜI GIAN").frame(width: 96)
                }
                .font(Theme.Fonts.caps).foregroundStyle(TransitPalette.transitTint)
                .padding(.vertical, Theme.Space.sm)
                Divider().overlay(Theme.Colors.separator)

                ForEach(r.houseRows) { row in
                    HStack {
                        TPlanetCell(symbol: row.planetSymbol, name: row.planet,
                                    tint: TransitPalette.transitTint)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("\(row.houseStart)")
                            .font(Theme.Fonts.numeric).bold()
                            .foregroundStyle(TransitPalette.transitTint)
                            .frame(width: 96)
                        Group {
                            if r.mode == .outerCycle {
                                Text(row.houseEnd.map(String.init) ?? "?")
                                    .font(Theme.Fonts.numeric).bold()
                                    .foregroundStyle(TransitPalette.transitTint)
                            } else {
                                Button("XEM") { sheetHousePlanet = row.planet }
                                    .font(Theme.Fonts.caps).tint(Theme.Colors.aspectSoft)
                            }
                        }
                        .frame(width: 96)
                    }
                    .frame(minHeight: Theme.Layout.rowMinHeight)
                    Divider().overlay(Theme.Colors.separator)
                }
            }
        }
    }

    @ViewBuilder
    private func aspectCard(_ title: String, _ rows: [TransitReports.TransitAspectRow],
                            isPoint: Bool) -> some View {
        let shown = rows.filter { $0.orb <= orbFilter }
        if !rows.isEmpty {
            TCard("Góc transit") {
                VStack(alignment: .leading, spacing: Theme.Space.sm) {
                    Text(title).font(Theme.Fonts.caps)
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .center)

                    HStack {
                        Text("ĐỘ LỆCH").font(Theme.Fonts.caption)
                            .foregroundStyle(Theme.Colors.textSecondary)
                        Spacer()
                        Picker("", selection: $orbFilter) {
                            Text("< 3º").tag(3.0); Text("< 2º").tag(2.0)
                            Text("< 1º").tag(1.0); Text("< 0.5º").tag(0.5)
                        }
                        .pickerStyle(.segmented).frame(width: 220)
                    }

                    HStack {
                        Text("TRANSIT").frame(maxWidth: .infinity, alignment: .leading)
                        Text("GÓC").frame(width: 40)
                        Text(isPoint ? "ĐIỂM" : "CÁ NHÂN").frame(maxWidth: .infinity, alignment: .leading)
                        Text("LỆCH").frame(width: 52)
                        Text("").frame(width: 46)
                    }
                    .font(Theme.Fonts.caps).foregroundStyle(Theme.Colors.textSecondary)
                    Divider().overlay(Theme.Colors.separator)

                    if shown.isEmpty {
                        Text("Không còn góc nào dưới \(orbFilter, specifier: "%.1f")º.")
                            .font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.textMuted)
                    }
                    ForEach(shown) { a in
                        HStack {
                            TPlanetCell(symbol: a.transitSymbol, name: a.transitPlanet,
                                        tint: TransitPalette.planet(a.transitPlanet))
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(a.aspectSymbol)
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(Theme.Colors.aspect(type: a.aspectType))
                                .frame(width: 40)
                            TPlanetCell(symbol: a.natalSymbol, name: a.natalDisplayName,
                                        tint: TransitPalette.planet(a.natalPoint),
                                        small: ["MC", "Vertex", "Asc"].contains(a.natalPoint))
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(a.orbText)
                                .font(Theme.Fonts.numericSmall)
                                .fontWeight(a.orb < 1.0 ? .black : .regular)
                                .frame(width: 52)
                            Button("XEM") { sheetAspect = a }
                                .font(Theme.Fonts.caps).tint(Theme.Colors.aspectSoft)
                                .frame(width: 46)
                        }
                        .frame(minHeight: Theme.Layout.rowMinHeight)
                        Divider().overlay(Theme.Colors.separator)
                    }
                }
            }
        }
    }

    private var returnLookupCard: some View {
        TCard("Tra cứu giai đoạn hồi vị") {
            HStack(spacing: Theme.Space.md) {
                Picker("Hành tinh", selection: $returnPlanet) {
                    ForEach(AstroConst.returnPlanetOrder, id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.menu).tint(Theme.Colors.accent)
                Spacer()
                Button("XEM") { showReturnSheet = true }
                    .font(Theme.Fonts.headline)
                    .padding(.horizontal, Theme.Space.xl).padding(.vertical, Theme.Space.sm)
                    .background(Theme.Colors.accent)
                    .foregroundStyle(Theme.Colors.textOnAccent)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
            }
        }
    }

    // MARK: - Chạy

    private func resolveProfile() -> BirthProfile? {
        if mode == .existing { return store.profile(named: selectedName) }
        var p = draft
        if p.name.trimmingCharacters(in: .whitespaces).isEmpty { p.name = "Không tên" }
        // `transits.py:106-109` — chỉ lưu khi tick và chưa trùng tên.
        if saveToStore { _ = store.saveIfNew(p) }
        return p
    }

    private func run() {
        task?.cancel()
        guard let p = resolveProfile() else {
            error = "Chưa chọn được hồ sơ nào."; return
        }
        activeProfile = p
        running = true; error = nil
        let m = transitMode
        let d = CivilDateTime(year: tYear, month: tMonth, day: tDay)
        let s = TransitDateBridge.civil(from: rangeStart)
        let e = TransitDateBridge.civil(from: rangeEnd)
        task = Task {
            do {
                let r = try await TransitEngine.shared.personal(profile: p, mode: m, date: d,
                                                                rangeStart: s, rangeEnd: e)
                if Task.isCancelled { return }
                await MainActor.run { result = r; running = false }
            } catch is CancellationError {
                await MainActor.run { running = false }
            } catch {
                await MainActor.run { self.error = String(describing: error); running = false }
            }
        }
    }
}

// MARK: - Cầu nối Date <-> CivilDateTime -------------------------------------

public enum TransitDateBridge {
    static let utcCalendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(secondsFromGMT: 0)!
        return c
    }()

    public static func civil(from d: Date) -> CivilDateTime {
        let c = utcCalendar.dateComponents([.year, .month, .day], from: d)
        return CivilDateTime(year: c.year ?? 2026, month: c.month ?? 1, day: c.day ?? 1)
    }

    public static func date(from c: CivilDateTime) -> Date {
        utcCalendar.date(from: DateComponents(year: c.year, month: c.month, day: c.day))
            ?? Date(timeIntervalSince1970: 0)
    }
}
