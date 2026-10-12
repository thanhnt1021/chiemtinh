//  RelationshipScreen.swift
//  Màn hình mảng QUAN HỆ — gộp 2 trang của web:
//    · `/synastry`  (`app/routes/charts.py:92-134`, `app/templates/synastry.html`)
//    · `/composite` (`app/routes/charts.py:136-175`, `app/templates/composite.html`)
//  Hai trang này có FORM GIỐNG HỆT NHAU (2 người A/B + "Góc thật"), chỉ khác khối
//  kết quả — nên native gộp 1 form + bộ chọn kết quả, KHÔNG bỏ bất kỳ khối nào.
//
//  Khối kết quả Synastry (synastry.html:98-121) — đủ 4:
//    1. Bản Đồ Synastry            -> SynastryWheelView (W18, Src/Chart)
//    2. PHÂN TÍCH CHI TIẾT (5 mục) -> SynastryReportView
//    3. BẢNG TƯƠNG TÁC GÓC         -> SynastryGridView (cuộn ngang, cột trái ghim)
//    4. THEME CHÍNH CỦA MỐI QUAN HỆ + THEME PHỤ -> SynastryThemeView
//  Khối kết quả Composite (composite.html) — đủ 2:
//    1. Bánh xe Composite          -> NatalWheelView (W18) trên chart midpoint
//    2. Phân Tích Chi Tiết Composite -> CompositeReportView (8 khối như natal)

import SwiftUI

public struct RelationshipScreen: View {

    public enum Mode: String, CaseIterable, Identifiable {
        case synastry  = "Hợp đôi"
        case composite = "Hợp nhất"
        case guideText = "Cách luận"
        public var id: String { rawValue }
    }

    /// Kết quả tính một lượt.
    public struct Result {
        public var pA: BirthProfile
        public var pB: BirthProfile
        public var cA: Chart
        public var cB: Chart
        public var report: RelReports.SynastryReport
        public var composite: CompositeChart?
        public var compositeReport: RelReports.NatalReport?
    }

    @State private var inputA = PersonInput()
    @State private var inputB = PersonInput()
    @State private var profiles: [BirthProfile] = []
    @State private var showRealOrb = false
    @State private var mode: Mode = .synastry
    @State private var result: Result? = nil
    @State private var errorText: String? = nil

    private let store = ProfileStore.shared

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                ScreenBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Space.lg) {
                        modePicker
                        if mode == .guideText {
                            SynastryGuideView()
                        } else {
                            formSection
                            if let e = errorText { errorCard(e) }
                            if let r = result {
                                if mode == .synastry { synastryResult(r) } else { compositeResult(r) }
                            } else {
                                EmptyState(systemImage: "person.2",
                                           title: "Chưa có kết quả",
                                           message: "Chọn/nhập 2 hồ sơ rồi bấm nút bên trên. Web cũng KHÔNG hiện gì trước khi submit (charts.py:120).")
                            }
                        }
                    }
                    .screenPadding()
                    .padding(.vertical, Theme.Space.lg)
                }
            }
            .navigationTitle("Quan hệ")
            // W21: trên iOS 26 tiêu đề .large KHÔNG vẽ chữ (chỉ chừa dải đen ~165pt) —
            // đã chụp ảnh chứng minh. Dùng .inline như tab "Lá số" (đang hiện đúng).
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear { profiles = store.all() }
    }

    // MARK: - Chọn chế độ

    private var modePicker: some View {
        Picker("Chế độ", selection: $mode) {
            ForEach(Mode.allCases) { m in Text(m.rawValue).tag(m) }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Form 2 người (synastry.html:18-95 / composite.html)

    private var formSection: some View {
        VStack(spacing: Theme.Space.md) {
            PersonInputCard(input: $inputA, title: "Người A (Trong)",
                            tint: Theme.Colors.aspectSoft, profiles: profiles)
            PersonInputCard(input: $inputB, title: "Người B (Ngoài)",
                            tint: Theme.Colors.aspectHard, profiles: profiles)

            // synastry.html:88-91 — checkbox "Hiển thị Góc thật (Show Real Orb)"
            Toggle("Hiển thị “Góc thật” (Show Real Orb)", isOn: $showRealOrb)
                .font(Theme.Fonts.callout)
                .tint(Theme.Colors.accent)

            Button(action: compute) {
                Text(mode == .synastry ? "XEM TƯƠNG HỢP" : "XEM COMPOSITE")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(AstroPrimaryButtonStyle())
        }
    }

    private func errorCard(_ e: String) -> some View {
        AstroCard {
            Label(e, systemImage: "exclamationmark.triangle.fill")
                .font(Theme.Fonts.callout)
                .foregroundStyle(Theme.Colors.danger)
        }
    }

    // MARK: - Kết quả Synastry — 4 khối

    @ViewBuilder private func synastryResult(_ r: Result) -> some View {
        // Khối 1 — synastry.html:100-103
        block("Bản đồ Synastry") {
            VStack(spacing: Theme.Space.sm) {
                SynastryWheelView(model: SynastryWheelModel(chartA: r.cA, chartB: r.cB,
                                                            nameA: r.pA.name, nameB: r.pB.name))
                    .frame(height: 420)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
                NavigationLink {
                    ChartHubView(chartA: r.cA, nameA: r.pA.name, chartB: r.cB, nameB: r.pB.name)
                } label: {
                    Label("Mở toàn màn hình (bánh xe · bảng góc · composite)", systemImage: "arrow.up.left.and.arrow.down.right")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(AstroGhostButtonStyle())
            }
        }

        // Khối 2 — synastry.html:104-107
        block("Phân tích chi tiết") {
            SynastryReportView(report: r.report, nameA: r.pA.name, nameB: r.pB.name)
        }

        // Khối 3 — synastry.html:108-113
        block("Bảng tương tác góc") {
            SynastryGridView(chartA: r.cA, chartB: r.cB,
                             nameA: r.pA.name, nameB: r.pB.name,
                             analysis: r.report.analysis, showRealOrb: showRealOrb)
        }

        // Khối 4 — synastry.html:114-119 (web chỉ hiện khi có theme_html)
        if let a = r.report.analysis {
            block("Theme chính của mối quan hệ") {
                SynastryThemeView(analysis: a, nameA: r.pA.name, nameB: r.pB.name)
            }
        }
    }

    // MARK: - Kết quả Composite — 2 khối

    @ViewBuilder private func compositeResult(_ r: Result) -> some View {
        if let comp = r.composite, let rep = r.compositeReport {
            block("Composite: \(r.pA.name) & \(r.pB.name)") {
                NatalWheelView(model: NatalWheelModel(
                    chart: comp.chart,
                    title: "Composite: \(r.pA.name) & \(r.pB.name)"))
                    .frame(height: 420)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
            }
            block("Phân tích chi tiết Composite") {
                CompositeReportView(chart: comp.chart, report: rep, showRealOrb: showRealOrb)
            }
        } else {
            errorCard("Không dựng được chart Composite từ 2 lá số này.")
        }
    }

    // MARK: - Khung khối

    @ViewBuilder private func block<Content: View>(_ title: String,
                                                  @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            SectionHeader(title) { EmptyView() }
            content()
        }
    }

    // MARK: - Tính (tương ứng charts.py:99-131 và 143-172)

    private func compute() {
        errorText = nil
        let list = store.all()
        guard let pA = inputA.resolve(store: list) else {
            errorText = "Chưa đủ dữ liệu Người A."; result = nil; return
        }
        guard let pB = inputB.resolve(store: list) else {
            errorText = "Chưa đủ dữ liệu Người B."; result = nil; return
        }

        // charts.py:102-113 — chỉ lưu khi tab "Nhập mới" VÀ có tick "Lưu hồ sơ",
        // và chỉ lưu nếu chưa trùng tên.
        if inputA.mode == .new && inputA.saveProfile { _ = store.saveIfNew(pA) }
        if inputB.mode == .new && inputB.saveProfile { _ = store.saveIfNew(pB) }
        profiles = store.all()

        guard let cA = pA.natalChart(), let cB = pB.natalChart() else {
            // charts.py:129-131 — web nuốt exception và không hiện gì.
            errorText = "Không tính được lá số (vĩ độ quá cao hoặc dữ liệu sai)."
            result = nil; return
        }

        let rep = RelReports.synastryReport(cA: cA, cB: cB,
                                            addressA: pA.address, addressB: pB.address)
        let comp = CompositeLogic.calculateCompositeChart(cA, cB)
        // charts.py:170-171 — báo cáo composite chạy `generate_natal_report` với
        // address cố định "Midpoint Method".
        let compRep = comp.map { RelReports.natalReport($0.chart, address: "Midpoint Method") }

        result = Result(pA: pA, pB: pB, cA: cA, cB: cB,
                        report: rep, composite: comp, compositeReport: compRep)
    }
}

#Preview("Quan hệ") {
    RelationshipScreen()
}
