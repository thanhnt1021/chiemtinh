//  SynastryWheelView.swift
//  BÁNH XE SYNASTRY 2 VÒNG — port `app/utils/drawing/synastry.py`.
//  Vòng trong = người A (màu xanh), vòng ngoài = người B (màu đỏ),
//  đường góc chiếu A×B vẽ ở tâm với bộ orb siêu chặt (`synastry.py:133-141`).

import SwiftUI

private let synContentRadius: Double = SynastryRing.outer

public struct SynastryWheelCanvas: View {
    public let model: SynastryWheelModel
    public let palette: ChartPalette
    public let selected: (name: String, owner: SynastryOwner)?
    public let viewport: ChartViewport
    public let size: CGSize

    public static func transform(size: CGSize, ascDeg: Double, viewport: ChartViewport) -> WheelTransform {
        let base = min(size.width, size.height) / 2 / CGFloat(synContentRadius) * 0.97
        return WheelTransform(center: CGPoint(x: size.width / 2 + viewport.offset.width,
                                              y: size.height / 2 + viewport.offset.height),
                              unit: base * viewport.scale, ascDeg: ascDeg)
    }

    public var body: some View {
        Canvas(rendersAsynchronously: false) { ctx, _ in
            let t = Self.transform(size: size, ascDeg: model.ascDeg, viewport: viewport)
            draw(&ctx, t)
        }
    }

    private func draw(_ ctx: inout GraphicsContext, _ t: WheelTransform) {
        let g = WheelPainter(t)
        let cA = palette.person(.a), cB = palette.person(.b)

        // 1) NỀN — synastry.py:33-38
        g.fillRing(&ctx, 0, SynastryRing.center, palette.innerFill)
        g.fillRing(&ctx, SynastryRing.center, SynastryRing.bOut, palette.ringFill)
        g.fillRing(&ctx, SynastryRing.bOut, SynastryRing.zodiacOuter, palette.innerFill)
        g.fillRing(&ctx, SynastryRing.zodiacOuter, SynastryRing.outer, palette.outerFill)

        // 2) VÀNH 12 CUNG — synastry.py:42-49
        WheelBackground.zodiacBand(&ctx, painter: g, palette: palette,
                                   bandIn: SynastryRing.zodiacBandIn, bandOut: SynastryRing.zodiacBandOut,
                                   sepFrom: SynastryRing.bOut, sepTo: SynastryRing.zodiacOuter)

        // 3) VIỀN — synastry.py:40-41
        for r in [SynastryRing.center, SynastryRing.aOut, SynastryRing.bOut,
                  SynastryRing.zodiacBandIn, SynastryRing.zodiacBandOut, SynastryRing.zodiacOuter] {
            g.strokeCircle(&ctx, r, palette.hairline, 0.8)
        }

        // 4) GÓC CHIẾU A×B ở tâm — synastry.py:144-176
        for a in model.aspects {
            let dim: Bool = {
                guard let s = selected else { return false }
                return s.owner == .a ? a.nameA != s.name : a.nameB != s.name
            }()
            let color = palette.aspect(a.visual)
            let alpha = dim ? a.alpha * 0.15 : a.alpha
            if a.visual == .conjunction {
                g.chord(&ctx, lonA: a.lonA, lonB: a.lonB, r: SynastryRing.center,
                        color: color, lineWidth: CGFloat(a.lineWidth) * t.unit / 40, alpha: alpha)
            } else {
                g.spindle(&ctx, lonA: a.lonA, lonB: a.lonB, r: SynastryRing.center,
                          maxWidth: 0.18, orbRatio: a.orbRatio, color: color, alpha: alpha)
            }
        }

        // 5) ĐỈNH NHÀ 2 NGƯỜI — synastry.py:51-68
        func cuspRing(_ cusps: [Double], _ r0: Double, _ r1: Double, _ color: Color, numR: Double) {
            for (i, deg) in cusps.enumerated() {
                g.radial(&ctx, lon: deg, r0, r1, color.opacity(0.6), i % 3 == 0 ? 2.2 : 0.7)
                g.text(&ctx, "\(i + 1)", lon: deg + 3.0, r: numR, size: 0.31,
                       color: color.opacity(0.9), weight: .semibold)
            }
        }
        cuspRing(model.cuspsA, SynastryRing.center, SynastryRing.aOut, cA,
                 numR: SynastryRing.center + 0.25)
        cuspRing(model.cuspsB, SynastryRing.aOut, SynastryRing.bOut, cB,
                 numR: SynastryRing.bOut - 0.25)

        // 6) HÀNH TINH NGƯỜI A — synastry.py:91-100
        drawPlanets(&ctx, g, model.placementsA, owner: .a, color: cA,
                    tick1: (SynastryRing.aOut - SynastryRing.tickLen, SynastryRing.aOut),
                    tick2: (SynastryRing.center, SynastryRing.center + SynastryRing.tickLen))
        // 7) HÀNH TINH NGƯỜI B — synastry.py:109-118
        drawPlanets(&ctx, g, model.placementsB, owner: .b, color: cB,
                    tick1: (SynastryRing.aOut, SynastryRing.aOut + SynastryRing.tickLen),
                    tick2: (SynastryRing.bOut - SynastryRing.tickLen, SynastryRing.bOut))
    }

    private func drawPlanets(_ ctx: inout GraphicsContext, _ g: WheelPainter,
                             _ list: [PlacedPlanet], owner: SynastryOwner, color: Color,
                             tick1: (Double, Double), tick2: (Double, Double)) {
        for p in list {
            let isSel = (selected?.name == p.name && selected?.owner == owner)
            let c = isSel ? palette.accent : color
            g.radial(&ctx, lon: p.lon, tick1.0, tick1.1, c, isSel ? 2.4 : 1.5)
            g.radial(&ctx, lon: p.lon, tick2.0, tick2.1, c, isSel ? 2.4 : 1.5)
            if abs(normDeg(p.lon - p.dispLon)) > 0.05 {
                var path = Path()
                path.move(to: g.t.point(lon: p.lon, r: (tick1.0 + tick1.1) / 2))
                path.addLine(to: g.t.point(lon: p.dispLon, r: p.dispR))
                ctx.stroke(path, with: .color(c.opacity(0.35)),
                           style: StrokeStyle(lineWidth: 0.6, dash: [2, 2.5]))
            }
            if isSel {
                let pt = g.t.point(lon: p.dispLon, r: p.dispR)
                let rr = 0.46 * g.t.unit
                let rect = CGRect(x: pt.x - rr, y: pt.y - rr, width: rr * 2, height: rr * 2)
                ctx.fill(Path(ellipseIn: rect), with: .color(palette.accent.opacity(0.22)))
                ctx.stroke(Path(ellipseIn: rect), with: .color(palette.accent), lineWidth: 1.4)
            }
            // synastry.py:99/117 — B nhỏ hơn A một chút (fontsize 18 vs 20)
            var size = GlyphScale.smallSymbolNames.contains(p.name)
                ? GlyphScale.planetSmall : GlyphScale.planet
            if owner == .b { size *= 0.9 }
            ChartGlyphDraw.draw(&ctx, symbol: p.symbol,
                                center: g.t.point(lon: p.dispLon, r: p.dispR),
                                size: max(size * g.t.unit, 11), color: c)
        }
    }
}

public struct SynastryWheelView: View {
    @Environment(\.colorScheme) private var scheme
    @State private var selected: (name: String, owner: SynastryOwner)? = nil
    @State private var cluster: [String] = []

    public let model: SynastryWheelModel
    public init(model: SynastryWheelModel) { self.model = model }

    public var body: some View {
        let palette = ChartPalette(scheme)
        ZStack(alignment: .bottom) {
            LinearGradient(colors: [palette.backgroundTop, palette.backgroundBottom],
                           startPoint: .top, endPoint: .bottom).ignoresSafeArea()

            VStack(spacing: 0) {
                HStack(spacing: 16) {
                    Label(model.nameA, systemImage: "circle.fill")
                        .foregroundColor(palette.person(.a)).font(.caption.bold())
                    Label(model.nameB, systemImage: "circle.fill")
                        .foregroundColor(palette.person(.b)).font(.caption.bold())
                }
                .padding(.top, 6)

                ZoomPanChart(content: { size, vp in
                    SynastryWheelCanvas(model: model, palette: palette, selected: selected,
                                        viewport: vp, size: size)
                }, onTap: { pt, size, vp in
                    let t = SynastryWheelCanvas.transform(size: size, ascDeg: model.ascDeg, viewport: vp)
                    var hit: (String, SynastryOwner)? = nil
                    if let a = ChartHitTest.planet(at: pt, placements: model.placementsA, transform: t),
                       let b = ChartHitTest.planet(at: pt, placements: model.placementsB, transform: t) {
                        // Chọn cái gần hơn khi cả 2 vòng đều nằm trong vùng chạm.
                        let pa = model.placementsA.first { $0.name == a }!
                        let pb = model.placementsB.first { $0.name == b }!
                        let da = hypot(t.point(lon: pa.dispLon, r: pa.dispR).x - pt.x,
                                       t.point(lon: pa.dispLon, r: pa.dispR).y - pt.y)
                        let db = hypot(t.point(lon: pb.dispLon, r: pb.dispR).x - pt.x,
                                       t.point(lon: pb.dispLon, r: pb.dispR).y - pt.y)
                        hit = da <= db ? (a, .a) : (b, .b)
                    } else if let a = ChartHitTest.planet(at: pt, placements: model.placementsA, transform: t) {
                        hit = (a, .a)
                    } else if let b = ChartHitTest.planet(at: pt, placements: model.placementsB, transform: t) {
                        hit = (b, .b)
                    }
                    withAnimation(.easeInOut(duration: 0.18)) {
                        if let h = hit {
                            cluster = ChartHitTest.candidates(
                                at: pt,
                                placements: h.1 == .a ? model.placementsA : model.placementsB,
                                transform: t)
                            if let cur = selected, cur.owner == h.1, cluster.contains(cur.name),
                               let nxt = ChartHitTest.next(after: cur.name, in: cluster) {
                                selected = (nxt, h.1)
                            } else {
                                selected = (h.0, h.1)
                            }
                        } else { selected = nil; cluster = [] }
                    }
                })
                .padding(6)
            }

            if let s = selected {
                let det = s.owner == .a ? model.detailsA[s.name] : model.detailsB[s.name]
                if let d = det {
                    PlanetDetailCard(detail: d, aspects: model.aspects(of: s.name, owner: s.owner),
                                     palette: palette, cluster: cluster,
                                     onPick: { selected = ($0, s.owner) },
                                     otherName: { $0 }, onClose: { selected = nil; cluster = [] })
                        .padding(.horizontal, 12).padding(.bottom, 12)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .navigationTitle("Synastry")
        .navigationBarTitleDisplayMode(.inline)
    }
}
