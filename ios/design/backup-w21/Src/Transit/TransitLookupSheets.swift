//  TransitLookupSheets.swift
//  3 MÀN TRA CỨU — port `app/templates/transit_modals_shared.html` (302 dòng).
//    1. "Giai đoạn tạo góc"  ← POST /api/tra-goc-transit   (api.py:151)
//    2. "Giai đoạn Hồi vị"   ← POST /api/tra-hoi-vi        (api.py:168)
//    3. "Hành trình tại Nhà" ← POST /api/tra-nha-transit   (api.py:185)
//  Ở đây KHÔNG gọi mạng: gọi thẳng `TransitEngine` (chạy nền, huỷ được, có đệm).

import SwiftUI

// MARK: - Khung chung --------------------------------------------------------

private struct LookupScaffold<Controls: View, Body_: View>: View {
    let title: String
    let tint: Color
    let running: Bool
    let notice: EphemerisClampNotice?
    let error: String?
    @ViewBuilder var controls: () -> Controls
    @ViewBuilder var results: () -> Body_
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.lg) {
                    TCard { controls() }
                    if let error { TBanner(.danger, error) }
                    if let n = notice, let m = n.message { TBanner(.warning, m) }
                    if running {
                        HStack(spacing: Theme.Space.sm) {
                            ProgressView().tint(tint)
                            Text("Đang quét…").font(Theme.Fonts.footnote)
                                .foregroundStyle(Theme.Colors.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Space.xl)
                    } else {
                        results()
                    }
                }
                .padding(Theme.Space.screenH)
            }
            .background(Theme.Colors.bgBase)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Đóng", action: onClose).tint(tint)
                }
            }
        }
    }
}

private struct StampCell: View {
    let stamp: TimeStamp
    let tint: Color
    var caption: String? = nil

    var body: some View {
        VStack(spacing: 2) {
            Text(stamp.d).font(Theme.Fonts.numeric).foregroundStyle(Theme.Colors.textPrimary)
            Text(stamp.t).font(Theme.Fonts.numericSmall).monospaced().foregroundStyle(tint)
            if let caption {
                Text(caption).font(Theme.Fonts.caption).foregroundStyle(tint)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Space.sm)
    }
}

// MARK: - 1. Giai đoạn tạo góc ----------------------------------------------

public struct AspectLookupSheet: View {
    public let profile: BirthProfile
    @State public var pTrans: String
    @State public var pNatal: String
    @State public var aspect: String
    @State private var day: Int
    @State private var month: Int
    @State private var year: Int

    @State private var rows: [AspectPeriod] = []
    @State private var notice: EphemerisClampNotice? = nil
    @State private var running = false
    @State private var error: String? = nil
    @State private var task: Task<Void, Never>? = nil

    @Environment(\.dismiss) private var dismiss
    /// Mở màn "Vận Hạn Riêng" ở đúng ngày — link "Transit lúc đó" của web.
    public var onOpenTransit: ((CivilDateTime) -> Void)? = nil

    /// Danh sách điểm natal của web: TRANSIT_PLANET_ORDER + NATAL_SPECIAL_POINTS
    /// (`transit_modals_shared.html:189`).
    public static let natalChoices = AstroConst.transitPlanetOrder + AstroConst.natalSpecialPoints

    public init(profile: BirthProfile, pTrans: String, aspect: String, pNatal: String,
                date: CivilDateTime, onOpenTransit: ((CivilDateTime) -> Void)? = nil) {
        self.profile = profile
        _pTrans = State(initialValue: pTrans)
        _aspect = State(initialValue: aspect)
        _pNatal = State(initialValue: pNatal)
        _day = State(initialValue: date.day)
        _month = State(initialValue: date.month)
        _year = State(initialValue: date.year)
        self.onOpenTransit = onOpenTransit
    }

    public var body: some View {
        LookupScaffold(title: "Giai đoạn tạo góc", tint: Theme.Colors.aspectSoft,
                       running: running, notice: notice, error: error) {
            VStack(alignment: .leading, spacing: Theme.Space.md) {
                Picker("Hành tinh transit", selection: $pTrans) {
                    ForEach(AstroConst.transitPlanetOrder, id: \.self) { Text($0).tag($0) }
                }.pickerStyle(.menu).tint(Theme.Colors.accent)

                Picker("Góc", selection: $aspect) {
                    ForEach(AstroConst.majorAspects, id: \.self) { a in
                        Text("\(AstroConst.aspectByName[a]?.symbol ?? "") \(a)").tag(a)
                    }
                }.pickerStyle(.menu).tint(Theme.Colors.accent)

                Picker("Điểm cá nhân", selection: $pNatal) {
                    ForEach(Self.natalChoices, id: \.self) { Text($0).tag($0) }
                }.pickerStyle(.menu).tint(Theme.Colors.accent)

                TDMYField(title: "Từ ngày", day: $day, month: $month, year: $year)
                TPrimaryButton("Tra cứu", tint: Theme.Colors.success, busy: running,
                               disabled: !EphemerisWindow.contains(year: year, month: month, day: 1)) {
                    run()
                }
            }
        } results: {
            if rows.isEmpty {
                TBanner(.info, "Không tạo góc chính xác trong khoảng quét.")
            } else {
                TCard {
                    VStack(spacing: 0) {
                        header(["GÓC BẮT ĐẦU", "GÓC CHÍNH XÁC", "GÓC KẾT THÚC"])
                        ForEach(Array(rows.enumerated()), id: \.offset) { _, item in
                            HStack(alignment: .top, spacing: 0) {
                                StampCell(stamp: item.start, tint: Theme.Colors.aspectSoft)
                                VStack(spacing: Theme.Space.sm) {
                                    if item.exactHits.isEmpty {
                                        Text("Không tạo góc chính xác")
                                            .font(Theme.Fonts.caption)
                                            .foregroundStyle(Theme.Colors.textMuted)
                                    }
                                    ForEach(Array(item.exactHits.enumerated()), id: \.offset) { _, hit in
                                        VStack(spacing: 2) {
                                            Text(hit.d).font(Theme.Fonts.numeric).bold()
                                            Text(hit.t).font(Theme.Fonts.numericSmall).monospaced()
                                            if let cb = onOpenTransit, let d = CivilDateTime.parseDMY(hit.d) {
                                                Button("TRANSIT LÚC ĐÓ") { dismiss(); cb(d) }
                                                    .font(Theme.Fonts.caps)
                                                    .tint(Theme.Colors.success)
                                            }
                                        }
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, Theme.Space.sm)
                                .background(Theme.Colors.success.opacity(0.10))
                                StampCell(stamp: item.end, tint: Theme.Colors.danger)
                            }
                            Divider().overlay(Theme.Colors.separator)
                        }
                    }
                }
            }
        } onClose: {
            task?.cancel(); dismiss()
        }
        .onAppear { run() }
        .onDisappear { task?.cancel() }
    }

    private func run() {
        task?.cancel()
        running = true; error = nil
        let p = profile, t = pTrans, n = pNatal, a = aspect, d = day, m = month, y = year
        task = Task {
            do {
                let (res, note) = try await TransitEngine.shared.aspectPeriods(
                    profile: p, pTrans: t, pNatal: n, aspect: a, day: d, month: m, year: y)
                if Task.isCancelled { return }
                await MainActor.run { rows = res; notice = note; running = false }
            } catch is CancellationError {
                await MainActor.run { running = false }
            } catch {
                await MainActor.run { self.error = String(describing: error); running = false }
            }
        }
    }
}

// MARK: - 2. Giai đoạn Hồi vị ------------------------------------------------

public struct ReturnLookupSheet: View {
    public let profile: BirthProfile
    @State private var planet: String
    @State private var day: Int
    @State private var month: Int
    @State private var year: Int

    @State private var rows: [ReturnPeriod] = []
    @State private var notice: EphemerisClampNotice? = nil
    @State private var running = false
    @State private var error: String? = nil
    @State private var task: Task<Void, Never>? = nil

    @Environment(\.dismiss) private var dismiss
    public var onOpenTransit: ((CivilDateTime) -> Void)? = nil

    public init(profile: BirthProfile, planet: String, date: CivilDateTime,
                onOpenTransit: ((CivilDateTime) -> Void)? = nil) {
        self.profile = profile
        _planet = State(initialValue: planet)
        _day = State(initialValue: date.day)
        _month = State(initialValue: date.month)
        _year = State(initialValue: date.year)
        self.onOpenTransit = onOpenTransit
    }

    public var body: some View {
        LookupScaffold(title: "Giai đoạn Hồi vị", tint: Theme.Colors.accent,
                       running: running, notice: notice, error: error) {
            VStack(alignment: .leading, spacing: Theme.Space.md) {
                Picker("Hành tinh", selection: $planet) {
                    ForEach(AstroConst.returnPlanetOrder, id: \.self) { Text($0).tag($0) }
                }.pickerStyle(.menu).tint(Theme.Colors.accent)
                TDMYField(title: "Từ ngày", day: $day, month: $month, year: $year)
                TPrimaryButton("Tra cứu", tint: Theme.Colors.accent, busy: running,
                               disabled: !EphemerisWindow.contains(year: year, month: month, day: 1)) {
                    run()
                }
            }
        } results: {
            if rows.isEmpty {
                TBanner(.info, "Không có hồi vị chính xác trong khoảng dữ liệu phủ được.")
            } else {
                TCard {
                    VStack(spacing: 0) {
                        header(["BẮT ĐẦU", "HỒI VỊ CHÍNH XÁC (0º)", "KẾT THÚC"])
                        ForEach(Array(rows.enumerated()), id: \.offset) { _, item in
                            HStack(alignment: .top, spacing: 0) {
                                StampCell(stamp: item.start, tint: Theme.Colors.aspectSoft,
                                          caption: "VÀO H\(item.house)")
                                VStack(spacing: Theme.Space.sm) {
                                    if item.exactHits.isEmpty {
                                        Text("Không có hồi vị chính xác")
                                            .font(Theme.Fonts.caption)
                                            .foregroundStyle(Theme.Colors.textMuted)
                                    }
                                    ForEach(Array(item.exactHits.enumerated()), id: \.offset) { _, hit in
                                        VStack(spacing: 2) {
                                            Text(hit.d).font(Theme.Fonts.numeric).bold()
                                            Text(hit.t).font(Theme.Fonts.numericSmall).monospaced()
                                            if let cb = onOpenTransit, let d = CivilDateTime.parseDMY(hit.d) {
                                                Button("TRANSIT LÚC ĐÓ") { dismiss(); cb(d) }
                                                    .font(Theme.Fonts.caps)
                                                    .tint(Theme.Colors.accent)
                                            }
                                        }
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, Theme.Space.sm)
                                .background(Theme.Colors.accentWash)
                                StampCell(stamp: item.end, tint: Theme.Colors.danger,
                                          caption: "RA H\(item.house)")
                            }
                            Divider().overlay(Theme.Colors.separator)
                        }
                    }
                }
            }
        } onClose: {
            task?.cancel(); dismiss()
        }
        .onAppear { run() }
        .onDisappear { task?.cancel() }
    }

    private func run() {
        task?.cancel()
        running = true; error = nil
        let p = profile, pl = planet, d = day, m = month, y = year
        task = Task {
            do {
                let (res, note) = try await TransitEngine.shared.returnPeriods(
                    profile: p, pTrans: pl, day: d, month: m, year: y)
                if Task.isCancelled { return }
                await MainActor.run { rows = res; notice = note; running = false }
            } catch is CancellationError {
                await MainActor.run { running = false }
            } catch {
                await MainActor.run { self.error = String(describing: error); running = false }
            }
        }
    }
}

// MARK: - 3. Hành trình tại Nhà ---------------------------------------------

public struct HouseTransitLookupSheet: View {
    public let profile: BirthProfile
    public let planet: String
    private let day: Int?, month: Int?, year: Int?

    @State private var period: HouseTransitPeriod? = nil
    @State private var notice: EphemerisClampNotice? = nil
    @State private var running = false
    @State private var error: String? = nil
    @State private var task: Task<Void, Never>? = nil

    @Environment(\.dismiss) private var dismiss
    public var onOpenTransit: ((CivilDateTime) -> Void)? = nil

    public init(profile: BirthProfile, planet: String, date: CivilDateTime?,
                onOpenTransit: ((CivilDateTime) -> Void)? = nil) {
        self.profile = profile; self.planet = planet
        self.day = date?.day; self.month = date?.month; self.year = date?.year
        self.onOpenTransit = onOpenTransit
    }

    public var body: some View {
        LookupScaffold(title: period.map { "\(planet) ở Nhà \($0.house)" } ?? "Hành trình tại Nhà",
                       tint: Theme.Colors.aspectSoft,
                       running: running, notice: notice, error: error) {
            HStack {
                TPlanetCell(symbol: AstroConst.planetSymbols[planet] ?? planet,
                            name: planet, tint: TransitPalette.transitTint)
                Spacer()
                Text(profile.name).font(Theme.Fonts.footnote)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
        } results: {
            if let item = period {
                TCard {
                    VStack(spacing: 0) {
                        header(["VÀO NHÀ", "RA KHỎI NHÀ"])
                        HStack(alignment: .top, spacing: 0) {
                            cell(item.start, Theme.Colors.aspectSoft)
                            cell(item.end, Theme.Colors.danger)
                        }
                    }
                }
            } else if !running {
                TBanner(.danger, "Không xác định được nhà transit cho \(planet).")
            }
        } onClose: {
            task?.cancel(); dismiss()
        }
        .onAppear { run() }
        .onDisappear { task?.cancel() }
    }

    private func cell(_ s: TimeStamp, _ tint: Color) -> some View {
        VStack(spacing: 4) {
            Text(s.d).font(Theme.Fonts.title2).foregroundStyle(Theme.Colors.textPrimary)
            Text(s.t).font(Theme.Fonts.numericSmall).monospaced().foregroundStyle(tint)
            if let cb = onOpenTransit, let d = CivilDateTime.parseDMY(s.d) {
                Button("TRANSIT LÚC ĐÓ") { dismiss(); cb(d) }
                    .font(Theme.Fonts.caps).tint(Theme.Colors.success)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Space.lg)
    }

    private func run() {
        task?.cancel()
        running = true; error = nil
        let p = profile, pl = planet, d = day, m = month, y = year
        task = Task {
            do {
                let (res, note) = try await TransitEngine.shared.houseTransitPeriod(
                    profile: p, pTrans: pl, day: d, month: m, year: y)
                if Task.isCancelled { return }
                await MainActor.run { period = res; notice = note; running = false }
            } catch is CancellationError {
                await MainActor.run { running = false }
            } catch {
                await MainActor.run { self.error = String(describing: error); running = false }
            }
        }
    }
}

// MARK: - Tiêu đề bảng dùng chung -------------------------------------------

@ViewBuilder
private func header(_ cols: [String]) -> some View {
    HStack(spacing: 0) {
        ForEach(cols, id: \.self) { c in
            Text(c).font(Theme.Fonts.caps)
                .foregroundStyle(Theme.Colors.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Space.sm)
        }
    }
    .background(Theme.Colors.bgChip)
    Divider().overlay(Theme.Colors.separator)
}
