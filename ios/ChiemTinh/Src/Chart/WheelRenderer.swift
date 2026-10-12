//  WheelRenderer.swift
//  BÚT VẼ VECTOR cho bánh xe chiêm tinh (SwiftUI Canvas / Core Graphics).
//  Toàn bộ toạ độ lấy từ `ChartGeometry.swift` (đã đối chiếu khớp Python tới 1e-13 độ).
//
//  Tỉ lệ chữ: matplotlib dùng figsize 12in × dpi 100 cho bán kính 11.5 đơn vị
//  (`natal.py:88-91`) ⇒ 1 đơn vị ≈ 40 px, nên fontsize 20 ≈ 0.7 đơn vị,
//  fontsize 25 ≈ 0.87, fontsize 14 ≈ 0.49, fontsize 10 ≈ 0.35. Giữ đúng các tỉ lệ đó.

import SwiftUI

public enum GlyphScale {
    public static let planet: CGFloat      = 0.70   // natal.py:193 fontsize 20
    public static let planetSmall: CGFloat = 0.49   // natal.py:192 fontsize 14
    public static let zodiac: CGFloat      = 0.87   // natal.py:136 fontsize 25
    public static let houseNum: CGFloat    = 0.35   // natal.py:156 fontsize 10
    public static let axisLabel: CGFloat   = 0.62   // natal.py:150 fontsize 20
    /// Các điểm ảo web vẽ nhỏ hơn — `natal.py:192`.
    public static let smallSymbolNames: Set<String> = ["Vertex", "Chiron", "True Node", "Lilith"]
}

/// Vẽ ký hiệu chiêm tinh bằng ĐÚNG bộ glyph của W17 (`Src/Design/Glyphs.swift`):
/// 5 ký hiệu font hệ thống không có (⚷ ⚸ ⚹ ⚺ ⚻) dùng Shape vector của họ,
/// "AC"/"MC"/"Vx" dùng chữ serif, còn lại dùng font glyph của Theme.
public enum ChartGlyphDraw {
    /// Lấy Path từ Shape của W17 — `Glyphs.drawnScalars` (Glyphs.swift:50).
    public static func vectorPath(_ symbol: String, in rect: CGRect) -> Path? {
        switch symbol {
        case "⚷": return ChironGlyph().path(in: rect)
        case "⚸": return LilithGlyph().path(in: rect)
        case "⚹": return SextileGlyph().path(in: rect)
        case "⚺": return SemisextileGlyph().path(in: rect)
        case "⚻": return QuincunxGlyph().path(in: rect)
        default:  return nil
        }
    }

    /// Bộ nhớ đệm kết quả `Glyphs.hasSystemGlyph` — hàm đó gọi CoreText, không được
    /// chạy lại cho từng ký hiệu ở mỗi khung hình khi người dùng zoom/pan.
    private static let glyphCacheLock = NSLock()
    nonisolated(unsafe) private static var glyphCache: [String: Bool] = [:]

    static func systemHasGlyph(_ s: String) -> Bool {
        glyphCacheLock.lock()
        if let hit = glyphCache[s] { glyphCacheLock.unlock(); return hit }
        glyphCacheLock.unlock()
        let v = Glyphs.hasSystemGlyph(s, size: 20)
        glyphCacheLock.lock(); glyphCache[s] = v; glyphCacheLock.unlock()
        return v
    }

    /// - Parameter fallback: mã chữ dùng khi font hệ thống KHÔNG có glyph (tránh ô vuông ▯).
    ///   Bỏ trống thì lấy 2 ký tự đầu của chính `symbol`.
    public static func draw(_ ctx: inout GraphicsContext, symbol: String, center: CGPoint,
                            size: CGFloat, color: Color, fallback: String? = nil) {
        let rect = CGRect(x: center.x - size / 2, y: center.y - size / 2, width: size, height: size)
        if let path = vectorPath(symbol, in: rect) {
            // Glyphs.swift:157 — cùng công thức độ dày nét của W17.
            ctx.stroke(path, with: .color(color),
                       style: StrokeStyle(lineWidth: max(1.2, size * 0.085),
                                          lineCap: .round, lineJoin: .round))
        } else if Glyphs.isLetterCode(symbol) {
            ctx.draw(Text(symbol)
                        .font(Theme.Fonts.serif(size * 0.78, weight: .semibold, relativeTo: .body))
                        .foregroundColor(color), at: center, anchor: .center)
        } else if systemHasGlyph(symbol) {
            ctx.draw(Text(symbol).font(Theme.Fonts.glyph(size: size)).foregroundColor(color),
                     at: center, anchor: .center)
        } else {
            // Lưới an toàn W21: iOS thiếu glyph -> in mã chữ thay vì ô vuông (Glyphs.swift:59).
            let code = fallback ?? String(symbol.prefix(2))
            ctx.draw(Text(code)
                        .font(Theme.Fonts.serif(size * 0.62, weight: .semibold, relativeTo: .body))
                        .foregroundColor(color), at: center, anchor: .center)
        }
    }
}

public struct WheelPainter {
    public let t: WheelTransform
    public init(_ t: WheelTransform) { self.t = t }

    // MARK: hình cơ bản

    public func circlePath(_ r: Double) -> Path {
        let rr = CGFloat(r) * t.unit
        return Path(ellipseIn: CGRect(x: t.center.x - rr, y: t.center.y - rr,
                                      width: rr * 2, height: rr * 2))
    }

    /// Tô hình vành khăn r0…r1.
    public func fillRing(_ ctx: inout GraphicsContext, _ r0: Double, _ r1: Double, _ color: Color) {
        var p = circlePath(r1)
        if r0 > 0 { p.addPath(circlePath(r0)) }
        ctx.fill(p, with: .color(color), style: FillStyle(eoFill: true))
    }

    public func strokeCircle(_ ctx: inout GraphicsContext, _ r: Double, _ color: Color, _ lw: CGFloat) {
        ctx.stroke(circlePath(r), with: .color(color), lineWidth: lw)
    }

    /// Đoạn thẳng theo phương bán kính tại một kinh độ.
    public func radial(_ ctx: inout GraphicsContext, lon: Double, _ r0: Double, _ r1: Double,
                       _ color: Color, _ lw: CGFloat, dash: [CGFloat] = []) {
        var p = Path()
        p.move(to: t.point(lon: lon, r: r0))
        p.addLine(to: t.point(lon: lon, r: r1))
        ctx.stroke(p, with: .color(color),
                   style: StrokeStyle(lineWidth: lw, lineCap: .round, dash: dash))
    }

    /// Múi quạt (dùng cho vành nguyên tố của 12 cung).
    public func wedge(_ ctx: inout GraphicsContext, lonFrom: Double, lonTo: Double,
                      _ r0: Double, _ r1: Double, _ color: Color, opacity: Double = 1) {
        var p = Path()
        let steps = max(2, Int((lonTo - lonFrom).magnitude))
        p.move(to: t.point(lon: lonFrom, r: r0))
        for i in 0...steps {
            let l = lonFrom + (lonTo - lonFrom) * Double(i) / Double(steps)
            p.addLine(to: t.point(lon: l, r: r0))
        }
        for i in stride(from: steps, through: 0, by: -1) {
            let l = lonFrom + (lonTo - lonFrom) * Double(i) / Double(steps)
            p.addLine(to: t.point(lon: l, r: r1))
        }
        p.closeSubpath()
        ctx.fill(p, with: .color(color.opacity(opacity)))
    }

    /// `minPoints`: sàn cỡ chữ theo pt màn hình — ký hiệu hành tinh không được nhỏ hơn 11 pt
    /// dù thu nhỏ hết cỡ, để còn đọc được trên iPhone.
    public func text(_ ctx: inout GraphicsContext, _ s: String, lon: Double, r: Double,
                     size: CGFloat, color: Color, weight: Font.Weight = .bold,
                     minPoints: CGFloat = 6) {
        let f = Font.system(size: max(size * t.unit, minPoints), weight: weight)
        ctx.draw(Text(s).font(f).foregroundColor(color), at: t.point(lon: lon, r: r), anchor: .center)
    }

    /// Hình thoi "thanh kiếm" của đường góc chiếu — `helpers.py:110`.
    public func spindle(_ ctx: inout GraphicsContext, lonA: Double, lonB: Double, r: Double,
                        maxWidth: Double, orbRatio: Double, color: Color, alpha: Double) {
        let v = spindleVertices(angle1: t.angle(lonA), angle2: t.angle(lonB), radius: r,
                                maxWidth: maxWidth, orbRatio: orbRatio)
        guard v.count == 6 else { return }
        var p = Path()
        p.move(to: t.point(chart: v[0]))
        for i in 1..<6 { p.addLine(to: t.point(chart: v[i])) }
        p.closeSubpath()
        ctx.fill(p, with: .color(color.opacity(alpha)))
        ctx.stroke(p, with: .color(color.opacity(min(1, alpha + 0.25))), lineWidth: 0.6)
    }

    /// Dây cung nối 2 kinh độ ở cùng bán kính (dùng cho góc Trùng — `natal.py:207-210`).
    public func chord(_ ctx: inout GraphicsContext, lonA: Double, lonB: Double, r: Double,
                      color: Color, lineWidth: CGFloat, alpha: Double) {
        var p = Path()
        p.move(to: t.point(lon: lonA, r: r))
        p.addLine(to: t.point(lon: lonB, r: r))
        ctx.stroke(p, with: .color(color.opacity(alpha)),
                   style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
    }
}

// MARK: - Vẽ nền chung (vành zodiac + vạch chia độ)

public enum WheelBackground {
    /// Vành 12 cung + ký hiệu. Dùng chung cho natal, composite và synastry.
    public static func zodiacBand(_ ctx: inout GraphicsContext, painter: WheelPainter,
                                  palette: ChartPalette, bandIn: Double, bandOut: Double,
                                  sepFrom: Double, sepTo: Double) {
        for i in 0..<12 {
            let start = Double(i) * 30.0
            painter.wedge(&ctx, lonFrom: start, lonTo: start + 30, bandIn, bandOut,
                          palette.element(i), opacity: palette.isDark ? 0.78 : 0.95)
            painter.radial(&ctx, lon: start, sepFrom, sepTo, Color.white.opacity(0.75), 0.8)
            ChartGlyphDraw.draw(&ctx, symbol: Glyphs.signSymbol(i),
                                center: painter.t.point(lon: start + 15, r: (bandIn + bandOut) / 2),
                                size: max(GlyphScale.zodiac * painter.t.unit, 12),
                                color: Theme.Colors.textOnAccent,
                                fallback: AstroConst.zodiacCodes[i])
        }
        // Vạch chia độ mảnh mỗi 5° ở mép trong vành cung — chi tiết native, web không có.
        for d in stride(from: 0.0, to: 360.0, by: 5.0) {
            let isTen = d.truncatingRemainder(dividingBy: 10) == 0
            painter.radial(&ctx, lon: d, bandIn - (isTen ? 0.16 : 0.09), bandIn,
                           palette.hairline.opacity(isTen ? 0.9 : 0.5), isTen ? 0.7 : 0.5)
        }
    }

    /// Ký hiệu hành tinh + vạch tick tại vị trí thật + đường nối khi bị dịch chỗ.
    public static func planets(_ ctx: inout GraphicsContext, painter: WheelPainter,
                               placements: [PlacedPlanet], tickInner: Double, tickOuter: Double,
                               tickLen: Double, color: Color, glyphColor: Color,
                               selected: String?, accent: Color) {
        for p in placements {
            let isSel = (p.name == selected)
            let c = isSel ? accent : color
            // natal.py:190-191 — 2 vạch tick tại KINH ĐỘ THẬT
            painter.radial(&ctx, lon: p.lon, tickInner, tickInner + tickLen, c, isSel ? 2.4 : 1.5)
            painter.radial(&ctx, lon: p.lon, tickOuter - tickLen, tickOuter, c, isSel ? 2.4 : 1.5)
            // Đường nối mảnh từ vị trí thật tới ký hiệu đã dịch (bản web chỉ làm cho transit).
            if abs(normDeg(p.lon - p.dispLon)) > 0.05 {
                var path = Path()
                path.move(to: painter.t.point(lon: p.lon, r: tickInner + tickLen))
                path.addLine(to: painter.t.point(lon: p.dispLon, r: p.dispR - 0.42))
                ctx.stroke(path, with: .color(c.opacity(0.45)),
                           style: StrokeStyle(lineWidth: 0.7, dash: [2, 2.5]))
            }
            if isSel {
                let pt = painter.t.point(lon: p.dispLon, r: p.dispR)
                let rr = 0.52 * painter.t.unit
                ctx.fill(Path(ellipseIn: CGRect(x: pt.x - rr, y: pt.y - rr, width: rr * 2, height: rr * 2)),
                         with: .color(accent.opacity(0.22)))
                ctx.stroke(Path(ellipseIn: CGRect(x: pt.x - rr, y: pt.y - rr, width: rr * 2, height: rr * 2)),
                           with: .color(accent), lineWidth: 1.4)
            }
            let size = GlyphScale.smallSymbolNames.contains(p.name)
                ? GlyphScale.planetSmall : GlyphScale.planet
            ChartGlyphDraw.draw(&ctx, symbol: p.symbol,
                                center: painter.t.point(lon: p.dispLon, r: p.dispR),
                                size: max(size * painter.t.unit, 11),
                                color: isSel ? accent : glyphColor,
                                fallback: String(p.name.prefix(2)))
        }
    }
}
