//  Glyphs.swift
//  Ký hiệu chiêm tinh cho toàn app. Danh sách LẤY TỪ `app/astro00_lib/const.py`:
//    - `PLANET_SYMBOLS`  (const.py:31-36) -> AstroConst.planetSymbols
//    - `ZODIAC_SYMBOLS`  (const.py:42)    -> AstroConst.zodiacSymbols
//    - `ZODIAC_NAMES`    (const.py:43-44) -> AstroConst.zodiacNames
//    - `ASPECTS_DEF`     (const.py:53-61) -> AstroConst.aspectsDef
//  KHÔNG tự nghĩ thêm ký hiệu nào ngoài danh sách trên.
//
//  ĐÃ ĐO THẬT bằng CoreText (không đoán) — font `AppleSymbols` (ship cùng iOS):
//    CÓ  : ♈♉♊♋♌♍♎♏♐♑♒♓  ☉☽☿♀♂♃♄♅♆♇  ☊ ☋  ☌ ☍ □ △
//    THIẾU: ⚷ (U+26B7 Chiron) · ⚸ (U+26B8 Lilith) · ⚹ (U+26B9 Sextile)
//           ⚺ (U+26BA Semisextile) · ⚻ (U+26BB Quincunx)
//  -> 5 ký hiệu thiếu được VẼ BẰNG VECTOR `Shape` ở cuối file, không phụ thuộc font.
//
//  API dùng chung cho 3 mảng (Chart / Relationship / Transit):
//      AstroGlyph(planet: "Sun")
//      AstroGlyph(signIndex: 4)
//      AstroGlyph(aspect: "Trine")

import SwiftUI
import CoreText
import UIKit

// MARK: - Tra cứu & kiểm tra font ---------------------------------------------

public enum Glyphs {

    /// Ký hiệu chữ của một hành tinh/điểm. Trả `nil` nếu tên không có trong `PLANET_SYMBOLS`.
    public static func planetSymbol(_ name: String) -> String? {
        AstroConst.planetSymbols[name]
    }

    /// Ký hiệu chữ của cung (0 = Bạch Dương … 11 = Song Ngư).
    public static func signSymbol(_ index: Int) -> String {
        AstroConst.zodiacSymbols[((index % 12) + 12) % 12]
    }

    /// Tên cung tiếng Việt — dùng làm `accessibilityLabel`.
    public static func signName(_ index: Int) -> String {
        AstroConst.zodiacNames[((index % 12) + 12) % 12]
    }

    /// Định nghĩa góc hợp theo tên tiếng Anh trong `ASPECTS_DEF`.
    public static func aspectDef(_ name: String) -> AstroConst.AspectDef? {
        AstroConst.aspectsDef.first { $0.name == name }
    }

    /// Những ký hiệu KHÔNG có trong font hệ thống iOS -> phải vẽ vector.
    /// Danh sách này là kết quả đo bằng CoreText, xem `docs/DESIGN.md` mục 5.1.
    public static let drawnScalars: Set<String> = ["⚷", "⚸", "⚹", "⚺", "⚻"]

    /// `Asc`/`MC`/`Vertex` là chữ cái (AC/MC/Vx), không phải glyph ký hiệu.
    public static func isLetterCode(_ symbol: String) -> Bool {
        symbol.unicodeScalars.allSatisfy { CharacterSet.letters.contains($0) }
    }

    /// Kiểm tra lúc chạy: font hệ thống có glyph cho chuỗi này không.
    /// Dùng làm lưới an toàn — nếu một bản iOS nào đó thiếu thêm glyph thì tự rơi về vector/chữ.
    public static func hasSystemGlyph(_ s: String, size: CGFloat = 20) -> Bool {
        let font = UIFont.systemFont(ofSize: size)
        var utf16 = Array(s.utf16)
        var glyphs = [CGGlyph](repeating: 0, count: utf16.count)
        let ok = CTFontGetGlyphsForCharacters(font as CTFont, &utf16, &glyphs, utf16.count)
        if ok && !glyphs.contains(0) { return true }
        // Font hệ thống không có -> thử cascade (CTLine sẽ tìm font dự phòng của hệ thống).
        let attr = NSAttributedString(string: s, attributes: [.font: font])
        let line = CTLineCreateWithAttributedString(attr)
        guard let runs = CTLineGetGlyphRuns(line) as? [CTRun] else { return false }
        for run in runs {
            let count = CTRunGetGlyphCount(run)
            var g = [CGGlyph](repeating: 0, count: count)
            CTRunGetGlyphs(run, CFRangeMake(0, count), &g)
            if g.contains(0) { return false }
        }
        return !runs.isEmpty
    }
}

// MARK: - View chính ----------------------------------------------------------

/// Ký hiệu chiêm tinh dùng chung. **Mọi mảng gọi view này**, cấm tự viết bảng ký hiệu riêng.
public struct AstroGlyph: View {

    public enum Kind: Equatable {
        case planet(String)   // tên theo `PLANET_SYMBOLS`: "Sun", "Chiron", "Asc"…
        case sign(Int)        // 0..11
        case aspect(String)   // tên theo `ASPECTS_DEF`: "Trine", "Sextile"…
    }

    private let kind: Kind
    private let size: CGFloat
    private let tint: Color?

    public init(planet name: String, size: CGFloat = 20, tint: Color? = nil) {
        self.kind = .planet(name); self.size = size; self.tint = tint
    }
    public init(signIndex: Int, size: CGFloat = 20, tint: Color? = nil) {
        self.kind = .sign(signIndex); self.size = size; self.tint = tint
    }
    public init(aspect name: String, size: CGFloat = 20, tint: Color? = nil) {
        self.kind = .aspect(name); self.size = size; self.tint = tint
    }

    public var body: some View {
        content
            .foregroundStyle(resolvedTint)
            .frame(width: size * 1.5, height: size * 1.5)
            .accessibilityLabel(Text(a11yLabel))
    }

    // --- chọn cách vẽ ---
    @ViewBuilder
    private var content: some View {
        switch kind {
        case .planet(let name):
            if let sym = Glyphs.planetSymbol(name) {
                symbolView(sym, fallbackText: shortCode(for: name))
            } else {
                text(shortCode(for: name), letterLike: true)
            }
        case .sign(let idx):
            symbolView(Glyphs.signSymbol(idx), fallbackText: AstroConst.zodiacCodes[((idx % 12) + 12) % 12])
        case .aspect(let name):
            if let def = Glyphs.aspectDef(name) {
                symbolView(def.symbol, fallbackText: String(def.symbol))
            } else {
                text("?", letterLike: true)
            }
        }
    }

    @ViewBuilder
    private func symbolView(_ sym: String, fallbackText: String) -> some View {
        if Glyphs.isLetterCode(sym) {
            // "AC" / "MC" / "Vx" — chữ cái, không phải glyph ký hiệu.
            text(sym, letterLike: true)
        } else if Glyphs.drawnScalars.contains(sym) {
            drawn(sym)
        } else if Glyphs.hasSystemGlyph(sym, size: size) {
            text(sym, letterLike: false)
        } else {
            text(fallbackText, letterLike: true)
        }
    }

    private func text(_ s: String, letterLike: Bool) -> some View {
        Text(s)
            .font(letterLike
                  ? Theme.Fonts.serif(size * 0.78, weight: .semibold, relativeTo: .body)
                  : Theme.Fonts.glyph(size: size))
            .lineLimit(1)
            .minimumScaleFactor(0.6)
    }

    @ViewBuilder
    private func drawn(_ sym: String) -> some View {
        let w = max(1.2, size * 0.085)
        switch sym {
        case "⚷": ChironGlyph().stroke(style: strokeStyle(w)).frame(width: size, height: size)
        case "⚸": LilithGlyph().stroke(style: strokeStyle(w)).frame(width: size, height: size)
        case "⚹": SextileGlyph().stroke(style: strokeStyle(w)).frame(width: size, height: size)
        case "⚺": SemisextileGlyph().stroke(style: strokeStyle(w)).frame(width: size, height: size)
        case "⚻": QuincunxGlyph().stroke(style: strokeStyle(w)).frame(width: size, height: size)
        default:  Text(sym).font(Theme.Fonts.glyph(size: size))
        }
    }

    private func strokeStyle(_ w: CGFloat) -> StrokeStyle {
        StrokeStyle(lineWidth: w, lineCap: .round, lineJoin: .round)
    }

    // --- màu ---
    private var resolvedTint: Color {
        if let tint { return tint }
        switch kind {
        case .sign(let idx):   return Theme.Colors.elementForSign(idx)
        case .aspect(let n):   return Theme.Colors.aspect(type: Glyphs.aspectDef(n)?.type ?? "")
        case .planet:          return Theme.Colors.textPrimary
        }
    }

    // --- nhãn trợ năng tiếng Việt ---
    private var a11yLabel: String {
        switch kind {
        case .planet(let n): return Self.planetNameVN[n] ?? n
        case .sign(let i):   return "Cung \(Glyphs.signName(i))"
        case .aspect(let n): return "Góc \(Glyphs.aspectDef(n)?.nameVN ?? n)"
        }
    }

    private func shortCode(for name: String) -> String {
        String(name.prefix(2))
    }

    /// Tên tiếng Việt của 18 khoá trong `PLANET_SYMBOLS` (`const.py:31-36`).
    static let planetNameVN: [String: String] = [
        "Sun": "Mặt Trời", "Moon": "Mặt Trăng", "Mercury": "Sao Thuỷ",
        "Venus": "Sao Kim", "Mars": "Sao Hoả", "Jupiter": "Sao Mộc",
        "Saturn": "Sao Thổ", "Uranus": "Thiên Vương Tinh",
        "Neptune": "Hải Vương Tinh", "Pluto": "Diêm Vương Tinh",
        "True Node": "La Hầu (True Node)", "South Node": "Kế Đô (South Node)",
        "Chiron": "Chiron", "Lilith": "Lilith",
        "Vertex": "Vertex", "Asc": "Cung Mọc (AC)", "MC": "Thiên Đỉnh (MC)"
    ]
}

// MARK: - Vector cho 5 ký hiệu font hệ thống KHÔNG có -------------------------
// Hệ toạ độ: mọi Shape vẽ trong hình vuông `rect`, tự co giãn theo `size`.

/// ⚷ U+26B7 — Chiron: chữ "K" đặt trên một vòng tròn nhỏ.
public struct ChironGlyph: Shape {
    public init() {}
    public func path(in r: CGRect) -> Path {
        var p = Path()
        let s = min(r.width, r.height)
        let x = r.midX, top = r.midY - s * 0.46
        let circleR = s * 0.17
        let circleCY = r.midY + s * 0.29
        // thân dọc: từ đỉnh xuống đỉnh vòng tròn
        p.move(to: CGPoint(x: x, y: top))
        p.addLine(to: CGPoint(x: x, y: circleCY - circleR))
        // vòng tròn dưới
        p.addEllipse(in: CGRect(x: x - circleR, y: circleCY - circleR,
                                width: circleR * 2, height: circleR * 2))
        // hai nhánh chữ K
        let armY = r.midY - s * 0.06
        p.move(to: CGPoint(x: x + s * 0.26, y: top))
        p.addLine(to: CGPoint(x: x, y: armY))
        p.addLine(to: CGPoint(x: x + s * 0.26, y: armY + s * 0.24))
        return p
    }
}

/// ⚸ U+26B8 — Lilith (Black Moon): trăng lưỡi liềm đặt trên dấu thập.
public struct LilithGlyph: Shape {
    public init() {}
    public func path(in r: CGRect) -> Path {
        var p = Path()
        let s = min(r.width, r.height)
        let x = r.midX
        let moonCY = r.midY - s * 0.24
        let outerR = s * 0.24
        // lưỡi liềm: cung ngoài + cung trong lệch phải
        p.addArc(center: CGPoint(x: x, y: moonCY), radius: outerR,
                 startAngle: .degrees(120), endAngle: .degrees(420), clockwise: false)
        p.move(to: CGPoint(x: x + outerR * cos(.pi * 120 / 180),
                           y: moonCY + outerR * sin(.pi * 120 / 180)))
        p.addQuadCurve(to: CGPoint(x: x + outerR * cos(.pi * 60 / 180),
                                   y: moonCY + outerR * sin(.pi * 60 / 180)),
                       control: CGPoint(x: x + s * 0.20, y: moonCY))
        // thân dọc + gạch ngang (dấu thập)
        p.move(to: CGPoint(x: x, y: moonCY + outerR * 0.7))
        p.addLine(to: CGPoint(x: x, y: r.midY + s * 0.46))
        p.move(to: CGPoint(x: x - s * 0.17, y: r.midY + s * 0.26))
        p.addLine(to: CGPoint(x: x + s * 0.17, y: r.midY + s * 0.26))
        return p
    }
}

/// ⚹ U+26B9 — Sextile: sao 6 cánh = 3 đường thẳng cắt nhau tại tâm.
public struct SextileGlyph: Shape {
    public init() {}
    public func path(in r: CGRect) -> Path {
        var p = Path()
        let s = min(r.width, r.height) * 0.42
        let c = CGPoint(x: r.midX, y: r.midY)
        for deg in stride(from: 0.0, to: 180.0, by: 60.0) {
            let a = deg * .pi / 180
            p.move(to: CGPoint(x: c.x - s * cos(a), y: c.y - s * sin(a)))
            p.addLine(to: CGPoint(x: c.x + s * cos(a), y: c.y + s * sin(a)))
        }
        return p
    }
}

/// ⚺ U+26BA — Semisextile: nửa TRÊN của sao 6 cánh (3 tia hướng lên).
public struct SemisextileGlyph: Shape {
    public init() {}
    public func path(in r: CGRect) -> Path { halfStar(in: r, pointingUp: true) }
}

/// ⚻ U+26BB — Quincunx: nửa DƯỚI của sao 6 cánh (semisextile xoay 180°).
public struct QuincunxGlyph: Shape {
    public init() {}
    public func path(in r: CGRect) -> Path { halfStar(in: r, pointingUp: false) }
}

/// Nửa sao 6 cánh dùng chung cho Semisextile / Quincunx.
private func halfStar(in r: CGRect, pointingUp: Bool) -> Path {
    var p = Path()
    let s = min(r.width, r.height) * 0.42
    let c = CGPoint(x: r.midX, y: r.midY)
    // 3 tia: 60°, 120°, 90° tính từ trục ngang; hướng lên = y giảm.
    let sign: CGFloat = pointingUp ? -1 : 1
    for deg in [0.0, 60.0, 120.0] {
        let a = deg * .pi / 180
        p.move(to: c)
        p.addLine(to: CGPoint(x: c.x + s * cos(a), y: c.y + sign * s * sin(a)))
    }
    // thanh đáy nối 2 tia ngoài cho ra đúng hình "nửa sao"
    p.move(to: CGPoint(x: c.x - s, y: c.y))
    p.addLine(to: CGPoint(x: c.x + s, y: c.y))
    return p
}
