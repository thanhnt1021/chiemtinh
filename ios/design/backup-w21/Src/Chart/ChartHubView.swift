//  ChartHubView.swift
//  ĐIỂM GHÉP NỐI cho phần còn lại của app: một màn hình gom đủ 4 loại biểu đồ.
//  Màn hình khác chỉ cần dựng `Chart` (từ `AstroCore.calculateChart`) rồi đưa vào đây.

import SwiftUI

public enum ChartKind: String, CaseIterable, Identifiable {
    case natal = "Bánh xe"
    case grid = "Bảng góc"
    case synastry = "Synastry"
    case composite = "Composite"
    public var id: String { rawValue }
}

public struct ChartHubView: View {
    @Environment(\.colorScheme) private var scheme
    @State private var kind: ChartKind = .natal

    public let chartA: Chart
    public let chartB: Chart?
    public let nameA: String
    public let nameB: String

    public init(chartA: Chart, nameA: String, chartB: Chart? = nil, nameB: String = "") {
        self.chartA = chartA; self.nameA = nameA; self.chartB = chartB; self.nameB = nameB
    }

    private var kinds: [ChartKind] {
        chartB == nil ? [.natal, .grid] : ChartKind.allCases
    }

    public var body: some View {
        let palette = ChartPalette(scheme)
        VStack(spacing: 0) {
            Picker("Loại biểu đồ", selection: $kind) {
                ForEach(kinds) { k in Text(k.rawValue).tag(k) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 12).padding(.vertical, 8)

            switch kind {
            case .natal:
                NatalWheelView(model: NatalWheelModel(chart: chartA, title: nameA))
            case .grid:
                NatalAspectGridView(model: NatalAspectGridModel(chart: chartA),
                                    title: "Góc chiếu — \(nameA)")
            case .synastry:
                if let b = chartB {
                    SynastryWheelView(model: SynastryWheelModel(chartA: chartA, chartB: b,
                                                                nameA: nameA, nameB: nameB))
                } else { missing }
            case .composite:
                if let b = chartB {
                    NatalWheelView(model: NatalWheelModel(
                        chart: CompositeChartBuilder.build(chartA, b),
                        title: "Composite: \(nameA) & \(nameB)"))
                } else { missing }
            }
        }
        .background(palette.backgroundTop.ignoresSafeArea())
    }

    private var missing: some View {
        VStack(spacing: 8) {
            Image(systemName: "person.2.slash").font(.largeTitle)
            Text("Cần chọn thêm lá số người thứ hai.").font(.callout)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .foregroundStyle(.secondary)
    }
}

// MARK: - Xem thử trong Xcode Preview (không ảnh hưởng app chạy thật)

#Preview("Bánh xe natal") {
    let c = AstroCore.calculateChart(dobStr: "15/05/1990", tobStr: "07:30",
                                     lat: 21.0285, lon: 105.8542, tzStr: "Asia/Ho_Chi_Minh")
    return Group {
        if let c { NavigationStack { ChartHubView(chartA: c, nameA: "Mẫu Hà Nội 1990") } }
        else { Text("Không tính được lá số mẫu") }
    }
}
