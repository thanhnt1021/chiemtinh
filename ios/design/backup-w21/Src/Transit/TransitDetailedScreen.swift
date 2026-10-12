//  TransitDetailedScreen.swift
//  MÀN 4/4 — port `/vanhan/chitiet` (`app/routes/transits.py:160-236`,
//  `app/templates/transit_chitiet.html`, 194 dòng).
//
//  ĐÂY LÀ MÀN NẶNG NHẤT. Cách xử hiệu năng (web chỉ có warm-up + try/except):
//    1. Mồi engine ngay khi mở màn — `TransitEngine.warmUp()` (đúng `transits.py:165`).
//    2. Toàn bộ tính toán chạy trong `actor TransitEngine` ⇒ ngoài luồng giao diện.
//    3. Có THANH TIẾN TRÌNH thật (đếm theo đơn vị công việc, không phải spinner giả).
//    4. HUỶ ĐƯỢC: nút "Huỷ" + tự huỷ khi rời màn (`onDisappear`).
//    5. ĐỆM KẾT QUẢ theo khoá (hồ sơ + khoảng ngày + danh sách nhà).
//    6. CẢNH BÁO TRƯỚC khi chọn quá nhiều nhà (mỗi nhà thêm ~50 lượt quét góc).

import SwiftUI

public struct TransitDetailedScreen: View {

    @ObservedObject public var store: ProfileStore

    @State private var mode: ProfileSelectorView.Mode = .existing
    @State private var selectedName: String = ""
    @State private var draft: BirthProfile = .draftDefault()
    @State private var saveToStore = false

    @State private var startDate: Date
    @State private var endDate: Date
    @State private var houses: Set<Int> = [1]

    @State private var timeline: TimelineData? = nil
    @State private var houseRows: [TransitReports.TransitHouseRow] = []
    @State private var cycle: [TransitReports.OuterCycleSpan] = []
    @State private var progress: Double = 0
    @State private var running = false
    @State private var error: String? = nil
    @State private var task: Task<Void, Never>? = nil
    @State private var elapsed: String = ""

    public init(store: ProfileStore = .shared) {
        self.store = store
        let today = TransitGeneralScreen.nowInVietnam()
        _startDate = State(initialValue: TransitDateBridge.date(from: today))
        _endDate = State(initialValue: TransitDateBridge.date(from: today.plusDays(365)))
    }

    // MARK: - Kiểm tra đầu vào (transit_chitiet.html:158-166)

    private var dateError: String? {
        if endDate < startDate { return "⚠️ Ngày kết thúc phải sau ngày bắt đầu." }
        if endDate.timeIntervalSince(startDate) / 86_400 > 366 {
            return "⚠️ Khoảng thời gian tối đa là 1 năm (366 ngày)."
        }
        let s = TransitDateBridge.civil(from: startDate), e = TransitDateBridge.civil(from: endDate)
        if !EphemerisWindow.contains(s) || !EphemerisWindow.contains(e) {
            return "⚠️ Khoảng ngày phải nằm trong \(EphemerisWindow.rangeLabel)."
        }
        return nil
    }
    private var houseError: String? {
        houses.isEmpty ? "⚠️ Vui lòng chọn ít nhất một Nhà." : nil
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.lg) {
                inputCard
                if let error { TBanner(.danger, error) }
                if running { progressCard }
                if let t = timeline, !running { resultBlocks(t) }
            }
            .padding(Theme.Space.screenH)
        }
        .background(Theme.Colors.bgBase)
        .navigationTitle("Vận Hạn Chi Tiết")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            W20Services.install()
            await TransitEngine.shared.warmUp()
        }
        .onDisappear { task?.cancel(); running = false }
    }

    // MARK: - Nhập

    private var inputCard: some View {
        TCard("Vận Hạn Chi Tiết (Timeline)") {
            VStack(alignment: .leading, spacing: Theme.Space.md) {
                ProfileSelectorView(store: store, mode: $mode, selectedName: $selectedName,
                                    draft: $draft, saveToStore: $saveToStore)
                Divider().overlay(Theme.Colors.separator)

                DatePicker("Từ ngày", selection: $startDate, displayedComponents: .date)
                    .environment(\.timeZone, TimeZone(secondsFromGMT: 0)!)
                DatePicker("Đến ngày", selection: $endDate, displayedComponents: .date)
                    .environment(\.timeZone, TimeZone(secondsFromGMT: 0)!)
                if let m = dateError { TBanner(.danger, m) }

                Text("LĨNH VỰC XEM VẬN HẠN (CHỌN NHÀ)")
                    .font(Theme.Fonts.caps).foregroundStyle(Theme.Colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Theme.Space.sm),
                                         count: 4), spacing: Theme.Space.sm) {
                    ForEach(1...12, id: \.self) { i in
                        let on = houses.contains(i)
                        Button {
                            if on { houses.remove(i) } else { houses.insert(i) }
                        } label: {
                            Text("H\(i)")
                                .font(Theme.Fonts.headline)
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .foregroundStyle(on ? Theme.Colors.success : Theme.Colors.textSecondary)
                                .background(on ? Theme.Colors.success.opacity(0.15) : Theme.Colors.bgChip)
                                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                                            .stroke(on ? Theme.Colors.success : Theme.Colors.border,
                                                    lineWidth: on ? 2 : 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
                if let m = houseError { TBanner(.danger, m) }
                if houses.count >= 4 {
                    TBanner(.warning, "Chọn \(houses.count) nhà: mỗi nhà thêm tối đa 50 lượt quét góc. Trên iPhone việc này có thể mất vài phút — vẫn chạy nền và huỷ được.")
                }

                TPrimaryButton("XEM VẬN HẠN CHI TIẾT", tint: Theme.Colors.aspectSoft,
                               busy: running,
                               disabled: dateError != nil || houseError != nil) { run() }
            }
        }
    }

    // MARK: - Tiến trình

    private var progressCard: some View {
        TCard {
            VStack(alignment: .leading, spacing: Theme.Space.md) {
                Text("Đang quét chu kỳ vận hạn…")
                    .font(Theme.Fonts.headline).foregroundStyle(Theme.Colors.textPrimary)
                ProgressView(value: progress).tint(Theme.Colors.accent)
                HStack {
                    Text("\(Int(progress * 100))%")
                        .font(Theme.Fonts.numericSmall).foregroundStyle(Theme.Colors.textSecondary)
                    Spacer()
                    Text(elapsed).font(Theme.Fonts.numericSmall)
                        .foregroundStyle(Theme.Colors.textMuted)
                }
                Button(role: .destructive) {
                    task?.cancel(); running = false
                } label: {
                    Text("HUỶ").font(Theme.Fonts.caps)
                        .frame(maxWidth: .infinity, minHeight: 40)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    // MARK: - Kết quả

    @ViewBuilder
    private func resultBlocks(_ t: TimelineData) -> some View {
        if let m = t.notice.message { TBanner(.warning, m) }

        if !cycle.isEmpty {
            TCard("Bản đồ sao & Đại hạn") {
                VStack(alignment: .leading, spacing: Theme.Space.xs) {
                    ForEach(cycle) { s in
                        HStack {
                            TPlanetCell(symbol: AstroConst.planetSymbols[s.planet] ?? s.planet,
                                        name: s.planet, tint: TransitPalette.planet(s.planet))
                            Spacer()
                            Text("\(TransitReports.degreeText(s.spanStart)) → \(TransitReports.degreeText(s.spanEnd))")
                                .font(Theme.Fonts.numericSmall)
                                .foregroundStyle(Theme.Colors.textSecondary)
                        }
                        .frame(minHeight: Theme.Layout.rowMinHeight)
                    }
                    TBanner(.info, "Dải quét đại hạn (“outer_cycle”) trên bánh xe cần mô-đun Chart bổ sung; số liệu dải đã hiện đầy đủ ở trên.")
                }
            }
        }

        if !houseRows.isEmpty {
            TCard("Nhà transit") {
                VStack(spacing: 0) {
                    HStack {
                        Text("HÀNH TINH").frame(maxWidth: .infinity, alignment: .leading)
                        Text("NHÀ BẮT ĐẦU").frame(width: 96)
                        Text("NHÀ KẾT THÚC").frame(width: 96)
                    }
                    .font(Theme.Fonts.caps).foregroundStyle(TransitPalette.transitTint)
                    .padding(.vertical, Theme.Space.sm)
                    Divider().overlay(Theme.Colors.separator)
                    ForEach(houseRows) { row in
                        HStack {
                            TPlanetCell(symbol: row.planetSymbol, name: row.planet,
                                        tint: TransitPalette.transitTint)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text("\(row.houseStart)").font(Theme.Fonts.numeric).bold()
                                .foregroundStyle(TransitPalette.transitTint).frame(width: 96)
                            Text(row.houseEnd.map(String.init) ?? "?").font(Theme.Fonts.numeric).bold()
                                .foregroundStyle(TransitPalette.transitTint).frame(width: 96)
                        }
                        .frame(minHeight: Theme.Layout.rowMinHeight)
                        Divider().overlay(Theme.Colors.separator)
                    }
                }
            }
        }

        TCard("Biểu đồ chu kỳ vận hạn chi tiết") {
            if t.isEmpty {
                Text("Không có chu kỳ nào rơi vào khoảng ngày và nhóm Nhà đã chọn.")
                    .font(Theme.Fonts.footnote).foregroundStyle(Theme.Colors.textMuted)
            } else {
                VStack(alignment: .leading, spacing: Theme.Space.sm) {
                    Text("\(t.start.dmy) – \(t.end.dmy)")
                        .font(Theme.Fonts.numeric).foregroundStyle(Theme.Colors.accent)
                    TimelineChartView(data: t)
                    Text("Vạch xanh lá = hành tinh vào Nhà · vạch xám = kỳ tạo góc · “E” đỏ = góc chính xác.")
                        .font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.textMuted)
                }
            }
        }
    }

    // MARK: - Chạy

    private func resolveProfile() -> BirthProfile? {
        if mode == .existing { return store.profile(named: selectedName) }
        var p = draft
        if p.name.trimmingCharacters(in: .whitespaces).isEmpty { p.name = "Không tên" }
        if saveToStore { _ = store.saveIfNew(p) }
        return p
    }

    private func run() {
        task?.cancel()
        guard let p = resolveProfile() else { error = "Chưa chọn được hồ sơ nào."; return }
        running = true; error = nil; progress = 0; timeline = nil
        let s = TransitDateBridge.civil(from: startDate)
        let e = TransitDateBridge.civil(from: endDate)
        let hs = houses.sorted()
        let t0 = Date()

        task = Task {
            do {
                // Bảng NHÀ TRANSIT của màn này = chế độ outer_cycle (transits.py:224-226)
                let cycleData = await TransitEngine.shared.personalCycleBlocks(
                    profile: p, start: s, end: e)
                if Task.isCancelled { return }
                await MainActor.run {
                    houseRows = cycleData.rows
                    cycle = cycleData.spans
                }

                let data = try await TransitEngine.shared.timeline(
                    profile: p, start: s, end: e, houses: hs,
                    onProgress: { pct in
                        Task { @MainActor in
                            progress = pct
                            elapsed = String(format: "%.0fs", Date().timeIntervalSince(t0))
                        }
                    })
                if Task.isCancelled { return }
                await MainActor.run { timeline = data; running = false; progress = 1 }
            } catch is CancellationError {
                await MainActor.run { running = false }
            } catch {
                // Đúng tinh thần khối chống sập của web (`transits.py:231-234`).
                await MainActor.run {
                    self.error = "Tính toán quá nặng hoặc gặp lỗi: \(error). Hãy thu hẹp khoảng thời gian hoặc bớt số Nhà."
                    running = false
                }
            }
        }
    }
}

// MARK: - Khối phụ cho màn chi tiết ------------------------------------------

public extension TransitEngine {
    struct CycleBlocks: Sendable {
        public var rows: [TransitReports.TransitHouseRow]
        public var spans: [TransitReports.OuterCycleSpan]
    }

    /// Bảng NHÀ TRANSIT + dải đại hạn cho `/vanhan/chitiet` (transits.py:218-226).
    func personalCycleBlocks(profile: BirthProfile,
                             start: CivilDateTime, end: CivilDateTime) -> CycleBlocks {
        warmUp()
        guard let natal = profile.natalChart(),
              let ts = transitChart(on: start, lat: profile.lat, lon: profile.lon),
              let te = transitChart(on: end, lat: profile.lat, lon: profile.lon)
        else { return CycleBlocks(rows: [], spans: []) }
        let rows = TransitReports.houseRows(natal: natal, transit: ts,
                                            mode: .outerCycle, transitEnd: te)
        let spans = TransitReports.outerCycleData(lat: profile.lat, lon: profile.lon,
                                                  start: start, end: end) ?? []
        return CycleBlocks(rows: rows, spans: spans)
    }
}
