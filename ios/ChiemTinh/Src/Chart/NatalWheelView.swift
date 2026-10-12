//  NatalWheelView.swift
//  BÁNH XE NATAL (và COMPOSITE — web dùng chung hàm vẽ, `app/routes/charts.py:170`).
//  Vẽ hoàn toàn bằng SwiftUI Canvas: 12 cung, 12 nhà, ký hiệu hành tinh + độ,
//  đường góc chiếu bên trong. Có phóng to / kéo / chạm xem chi tiết.

import SwiftUI

/// Bán kính nội dung MẶC ĐỊNH (đơn vị chart) để canh khung — nhãn AC/IC/DC/MC nằm ở 10.5
/// (`natal.py:151`), vành ngoài 11.5 (`natal.py:84`).
/// Ở chế độ transit `outer_cycle`, web tính lại `R_OUTER` theo số lane (`natal.py:76-77`)
/// nên khung phải nới theo `model.outerRadius`.
public let contentRadius: Double = NatalRing.outer

public struct NatalWheelCanvas: View {
    public let model: NatalWheelModel
    public let palette: ChartPalette
    public let selected: String?
    public let viewport: ChartViewport
    public let size: CGSize

    public static func transform(size: CGSize, ascDeg: Double, viewport: ChartViewport,
                                 outerRadius: Double = contentRadius) -> WheelTransform {
        let base = min(size.width, size.height) / 2 / CGFloat(max(outerRadius, 1)) * 0.97
        return WheelTransform(center: CGPoint(x: size.width / 2 + viewport.offset.width,
                                              y: size.height / 2 + viewport.offset.height),
                              unit: base * viewport.scale, ascDeg: ascDeg)
    }

    public var body: some View {
        Canvas(rendersAsynchronously: false) { ctx, _ in
            let t = Self.transform(size: size, ascDeg: model.ascDeg, viewport: viewport,
                                   outerRadius: model.outerRadius)
            draw(&ctx, t)
        }
    }

    private func draw(_ ctx: inout GraphicsContext, _ t: WheelTransform) {
        let g = WheelPainter(t)

        // 1) NỀN CÁC VÀNH — natal.py:126-130
        g.fillRing(&ctx, 0, NatalRing.mid, palette.innerFill)
        g.fillRing(&ctx, NatalRing.mid, NatalRing.planet, palette.ringFill)
        g.fillRing(&ctx, NatalRing.zodiacInner, NatalRing.zodiacOuter, palette.innerFill)
        g.fillRing(&ctx, NatalRing.zodiacOuter, NatalRing.outer, palette.outerFill)

        // 2) VÀNH 12 CUNG — natal.py:133-137
        WheelBackground.zodiacBand(&ctx, painter: g, palette: palette,
                                   bandIn: NatalRing.zodiacBandIn, bandOut: NatalRing.zodiacBandOut,
                                   sepFrom: NatalRing.zodiacInner, sepTo: NatalRing.zodiacOuter)

        // 3) CÁC ĐƯỜNG TRÒN VIỀN — natal.py:132
        for r in [NatalRing.mid, NatalRing.planet, NatalRing.zodiacBandIn,
                  NatalRing.zodiacBandOut, NatalRing.zodiacOuter] {
            g.strokeCircle(&ctx, r, palette.hairline, 0.8)
        }
        g.strokeCircle(&ctx, NatalRing.innerRing, palette.hairline.opacity(0.7), 1.0)   // natal.py:129
        g.strokeCircle(&ctx, NatalRing.outer, palette.hairline.opacity(0.6), 0.8)

        // 4) ĐƯỜNG GÓC CHIẾU — natal.py:196-219 (vẽ trước để ký hiệu nằm trên)
        for a in model.aspects {
            let dim = selected != nil && !a.involves(selected!)
            let color = palette.aspect(a.visual)
            let alpha = dim ? a.alpha * 0.18 : a.alpha
            if a.visual == .conjunction {
                g.chord(&ctx, lonA: a.lonA, lonB: a.lonB, r: NatalRing.aspectTip,
                        color: color, lineWidth: CGFloat(a.lineWidth) * t.unit / 40, alpha: alpha)
            } else {
                g.spindle(&ctx, lonA: a.lonA, lonB: a.lonB, r: NatalRing.aspectTip,
                          maxWidth: 0.25, orbRatio: a.orbRatio, color: color, alpha: alpha)
            }
        }

        // 5) TÂM
        g.fillRing(&ctx, 0, NatalRing.centerDot, palette.strongLine)

        // 6) ĐỈNH NHÀ — natal.py:141-156
        if !model.hideHouses {
            for (i, deg) in model.cusps.enumerated() {
                if i % 3 == 0 {   // AC / IC / DC / MC
                    g.radial(&ctx, lon: deg, NatalRing.innerRing, NatalRing.planet, palette.strongLine, 2.2)
                    g.radial(&ctx, lon: deg, NatalRing.zodiacOuter, NatalRing.zodiacOuter + 0.2,
                             palette.strongLine, 1.6)
                    g.text(&ctx, ["AC", "IC", "DC", "MC"][i / 3], lon: deg, r: NatalRing.zodiacOuter + 1.0,
                           size: GlyphScale.axisLabel, color: palette.strongLine)
                } else {
                    g.radial(&ctx, lon: deg, NatalRing.mid, NatalRing.planet, palette.hairline, 0.8)
                }
            }
            for l in model.houseLabels {
                g.text(&ctx, "\(l.number)", lon: l.lon, r: NatalRing.mid + 0.35,
                       size: GlyphScale.houseNum, color: palette.glyphSecondary, weight: .semibold)
            }
        }

        // 7) HÀNH TINH — natal.py:186-194
        WheelBackground.planets(&ctx, painter: g, placements: model.placements,
                                tickInner: NatalRing.mid - NatalRing.tickLen,
                                tickOuter: NatalRing.planet,
                                tickLen: NatalRing.tickLen,
                                color: palette.tick, glyphColor: palette.glyph,
                                selected: selected, accent: palette.accent)

        // 8) VÒNG NGOÀI TRANSIT — natal.py:222-270
        drawTransit(&ctx, g)
    }

    /// Port `natal.py:222-270`. Web vẽ toàn bộ phần transit bằng `COLOR_MINOR`
    /// (`styles.py`), ở đây dùng `palette.aspect(.minor)` cho đúng bộ màu.
    private func drawTransit(_ ctx: inout GraphicsContext, _ g: WheelPainter) {
        guard let mode = model.transitMode else { return }
        let col = palette.aspect(.minor)

        switch mode {
        case .single:
            // natal.py:233-239
            for p in model.transitPlacements {
                g.radial(&ctx, lon: p.lon, TransitRing.singleRootBase, TransitRing.singleRootTip, col, 2.0)
                var path = Path()
                path.move(to: g.t.point(lon: p.lon, r: TransitRing.singleRootTip))
                path.addLine(to: g.t.point(lon: p.dispLon, r: TransitRing.singleTextPos - 0.3))
                ctx.stroke(path, with: .color(col),
                           style: StrokeStyle(lineWidth: 0.5, dash: [1.5, 2]))
                let size = GlyphScale.smallSymbolNames.contains(p.name)
                    ? GlyphScale.planetSmall : GlyphScale.planet      // natal.py:237
                ChartGlyphDraw.draw(&ctx, symbol: p.symbol,
                                    center: g.t.point(lon: p.dispLon, r: p.dispR),
                                    size: max(size * g.t.unit, 11), color: col)
            }

        case .outerCycle:
            // natal.py:246-253 — ký hiệu tại vị trí đầu kỳ 'A'
            for p in model.transitPlacements {
                g.radial(&ctx, lon: p.lon, TransitRing.cycleRootBase, TransitRing.cycleRootTip, col, 2.0)
                var path = Path()
                path.move(to: g.t.point(lon: p.lon, r: TransitRing.cycleRootTip))
                path.addLine(to: g.t.point(lon: p.dispLon, r: TransitRing.cycleTextPos - 0.3))
                ctx.stroke(path, with: .color(col),
                           style: StrokeStyle(lineWidth: 0.5, dash: [1.5, 2]))
                let size = GlyphScale.smallSymbolNames.contains(p.name)
                    ? GlyphScale.planetSmall : GlyphScale.planet
                ChartGlyphDraw.draw(&ctx, symbol: p.symbol,
                                    center: g.t.point(lon: p.dispLon, r: p.dispR),
                                    size: max(size * g.t.unit, 11), color: col)
            }
            // natal.py:255-270 — dải quét + 2 vạch tick A/B
            for a in model.transitArcs {
                let rLane = TransitRing.laneBaseDraw + Double(a.laneIndex) * TransitRing.laneHeight
                let rOut = rLane + TransitRing.laneBarThickness
                let s = a.arc.start
                let e = a.arc.end < a.arc.start ? a.arc.end + 360 : a.arc.end   // natal.py:260-264
                g.wedge(&ctx, lonFrom: s, lonTo: e, rLane, rOut, col, opacity: 0.8)
                for tick in [a.arc.lonA, a.arc.lonB] {                          // natal.py:268-270
                    g.radial(&ctx, lon: tick, rLane - TransitRing.laneTickLen, rLane, col, 0.8)
                }
            }
        }
    }
}

// MARK: - Màn hình hoàn chỉnh (nền, cử chỉ, thẻ chi tiết)

public struct NatalWheelView: View {
    @Environment(\.colorScheme) private var scheme
    @State private var selected: String? = nil
    @State private var cluster: [String] = []

    public let model: NatalWheelModel
    public init(model: NatalWheelModel) { self.model = model }

    public var body: some View {
        let palette = ChartPalette(scheme)
        ZStack(alignment: .bottom) {
            LinearGradient(colors: [palette.backgroundTop, palette.backgroundBottom],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            ZoomPanChart(content: { size, vp in
                NatalWheelCanvas(model: model, palette: palette, selected: selected,
                                 viewport: vp, size: size)
            }, onTap: { pt, size, vp in
                let t = NatalWheelCanvas.transform(size: size, ascDeg: model.ascDeg, viewport: vp,
                                                   outerRadius: model.outerRadius)
                let list = ChartHitTest.candidates(at: pt, placements: model.placements, transform: t)
                withAnimation(.easeInOut(duration: 0.18)) {
                    if list.isEmpty { selected = nil; cluster = [] }
                    else if let s = selected, list.contains(s) {
                        // chạm lại vào cùng cụm -> xoay vòng sang ký hiệu kế bên
                        cluster = list
                        selected = ChartHitTest.next(after: s, in: list)
                    } else {
                        cluster = list
                        selected = list[0]
                    }
                }
            })
            .padding(6)

            if let s = selected, let d = model.details[s] {
                PlanetDetailCard(detail: d, aspects: model.aspects(of: s), palette: palette,
                                 cluster: cluster, onPick: { selected = $0 },
                                 otherName: { $0 }, onClose: { selected = nil; cluster = [] })
                    .padding(.horizontal, 12).padding(.bottom, 12)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .navigationTitle(model.title + model.titleSuffix)   // natal.py:272-275
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Thẻ chi tiết hành tinh

public struct PlanetDetailCard: View {
    public let detail: PlanetDetail
    public let aspects: [AspectEdge]
    public let palette: ChartPalette
    /// Cụm ký hiệu nằm chung vùng chạm — hiện thành chip để chọn chính xác.
    public let cluster: [String]
    public let onPick: (String) -> Void
    /// Cho phép màn hình synastry gắn thêm nhãn "A/B" vào tên đối tác.
    public let otherName: (String) -> String
    public let onClose: () -> Void

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Text(detail.symbol)
                    .font(.system(size: 30, weight: .bold))
                    .foregroundColor(palette.accent)
                    .frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(ChartText.name(detail.name))
                        .font(.headline).foregroundColor(palette.glyph)
                    Text("\(detail.degreeText) \(detail.signSymbol) \(detail.signName) · Nhà \(detail.house)"
                         + (detail.isRetrograde ? " · Nghịch hành ℞" : ""))
                        .font(.subheadline).foregroundColor(palette.glyphSecondary)
                }
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2).foregroundColor(palette.glyphSecondary)
                }
                .frame(width: 44, height: 44)
                .accessibilityLabel("Đóng")
            }
            if cluster.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(cluster, id: \.self) { n in
                            Button { onPick(n) } label: {
                                Text("\(AstroConst.planetSymbols[n] ?? n) \(ChartText.name(n))")
                                    .font(.caption.bold())
                                    .padding(.horizontal, 10).padding(.vertical, 8)
                                    .background(Capsule().fill(n == detail.name
                                        ? palette.accent.opacity(0.28) : palette.gridHeader))
                                    .foregroundColor(palette.glyph)
                            }
                            .frame(minHeight: 44)
                        }
                    }
                }
            }
            if aspects.isEmpty {
                Text("Không có góc chiếu nào trong dung sai.")
                    .font(.footnote).foregroundColor(palette.glyphSecondary)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(aspects) { a in
                            let other = (a.nameA == detail.name) ? a.nameB : a.nameA
                            HStack(spacing: 8) {
                                Text(a.symbol).font(.system(size: 17, weight: .bold))
                                    .foregroundColor(palette.aspect(a.visual))
                                    .frame(width: 22)
                                Text("\(ChartText.aspectVN[a.aspect] ?? a.aspect) với \(ChartText.name(otherName(other)))")
                                    .font(.footnote).foregroundColor(palette.glyph)
                                Spacer()
                                Text(String(format: "%.2f°", a.orb))
                                    .font(.caption.monospacedDigit())
                                    .foregroundColor(palette.glyphSecondary)
                            }
                        }
                    }
                }
                .frame(maxHeight: 168)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(palette.cardBackground)
            .shadow(color: .black.opacity(0.25), radius: 12, y: 4))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .stroke(palette.accent.opacity(0.35), lineWidth: 1))
    }
}
