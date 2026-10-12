//  ChartStyle.swift
//  BẢNG MÀU của phần vẽ biểu đồ — CHỈ LÀ LỚP CHUYỂN TIẾP sang token của W17
//  (`Src/Design/Theme.swift`). Không tự định nghĩa mã màu nào nữa ngoài 2 chỗ
//  buộc phải có (nền vành trong/ngoài lấy từ bgSurface/bgSunken của Theme).
//
//  Vì `Theme.Colors.*` đã là màu động (tự đổi theo dark/light qua UIColor),
//  `ChartPalette` không cần tự phân nhánh sáng/tối; `isDark` chỉ còn dùng cho
//  vài quyết định độ mờ (opacity) của nét vẽ.

import SwiftUI

public struct ChartPalette {
    public let isDark: Bool

    public init(_ scheme: ColorScheme) { self.isDark = (scheme == .dark) }

    // Nền & khung — token W17: Theme.Colors (Src/Design/Theme.swift:40-61)
    public var backgroundTop: Color    { Theme.Colors.bgBase }
    public var backgroundBottom: Color { Theme.Colors.bgSunken }
    /// Vùng trong cùng (nơi vẽ đường góc chiếu) — tương ứng BG_COLOR_1 của web.
    public var innerFill: Color        { Theme.Colors.bgSunken }
    /// Vành hành tinh — tương ứng BG_COLOR_2 của web.
    public var ringFill: Color         { Theme.Colors.bgSurface }
    public var outerFill: Color        { Theme.Colors.bgBase }

    public var hairline: Color         { Theme.Colors.border }
    public var strongLine: Color       { Theme.Colors.borderStrong }
    public var accent: Color           { Theme.Colors.accent }
    public var glyph: Color            { Theme.Colors.textPrimary }
    public var glyphSecondary: Color   { Theme.Colors.textSecondary }
    public var tick: Color             { Theme.Colors.aspectSoft }
    public var cardBackground: Color   { Theme.Colors.bgSurfaceRaised }

    /// Màu 4 nguyên tố — dùng thẳng token của W17 (`Theme.Colors.elementForSign`),
    /// vốn suy ra từ `AstroConst.zodiacMatrix` nên khớp `get_element_color` của web
    /// (`app/utils/drawing/helpers.py:5-11`: fire/earth/air/water theo `idx % 4`).
    public func element(_ zodiacIndex: Int) -> Color {
        Theme.Colors.elementForSign(zodiacIndex)
    }

    /// Màu đường góc chiếu. Ngữ nghĩa giữ như web (`styles.py:2-6`);
    /// mã màu lấy từ `Theme.Colors.aspect*` + accent cho góc Trùng.
    public func aspect(_ v: AspectVisual) -> Color {
        switch v {
        case .conjunction: return Theme.Colors.accent
        case .opposition, .hard: return Theme.Colors.aspectHard
        case .soft: return Theme.Colors.aspectSoft
        case .minor: return Theme.Colors.aspectMinor
        }
    }

    /// Hai người trong synastry — `styles.py:9-10` (A xanh, B đỏ).
    public func person(_ owner: SynastryOwner) -> Color {
        switch owner {
        case .a: return Theme.Colors.aspectSoft
        case .b: return Theme.Colors.aspectHard
        }
    }

    public var gridEmpty: Color  { Theme.Colors.bgSunken }
    public var gridFilled: Color { Theme.Colors.bgSurface }
    public var gridHeader: Color { Theme.Colors.bgChip }
    public var gridBorder: Color { Theme.Colors.separator }
}

// MARK: - Nhãn tiếng Việt

public enum ChartText {
    /// Tên tiếng Việt lấy THẲNG từ bảng của W17 (`Src/Design/Glyphs.swift:198-207`)
    /// để cả app gọi tên giống nhau. Web không có tên tiếng Việt cho hành tinh.
    public static func name(_ key: String) -> String {
        AstroGlyph.planetNameVN[key] ?? key
    }

    public static let aspectVN: [String: String] = [
        "Conjunction": "Trùng", "Semisextile": "Bán Lục Hợp", "Sextile": "Lục Hợp",
        "Square": "Vuông Góc", "Trine": "Tam Hợp", "Quincunx": "Ngũ Chiếu", "Opposition": "Đối Đỉnh"
    ]
}
