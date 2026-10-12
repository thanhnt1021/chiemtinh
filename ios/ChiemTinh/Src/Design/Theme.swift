//  Theme.swift
//  SSOT token của app — khớp 1-1 với `docs/DESIGN.md`.
//  Đổi giá trị ở đây thì PHẢI sửa `docs/DESIGN.md` cùng lúc (luật univ3: DESIGN.md là nguồn sự thật).
//
//  Cách dùng (3 worker khác gọi đúng những tên này):
//      Theme.Colors.accent · Theme.Fonts.body · Theme.Space.lg · Theme.Radius.md
//      Theme.Shadow.card   · Theme.Motion.standard
//
//  Dark là mặc định; mọi màu là dynamic color nên tự đảo theo light/dark của hệ thống.

import SwiftUI
import UIKit

public enum Theme {

    // MARK: - Hạ tầng màu động ------------------------------------------------

    /// Dựng `Color` đổi theo giao diện sáng/tối. `dark` là giá trị mặc định của app.
    static func dyn(dark: UInt32, light: UInt32) -> Color {
        Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .light ? UIColor(rgb: light) : UIColor(rgb: dark)
        })
    }

    static func dyn(dark: UInt32, darkAlpha: Double,
                    light: UInt32, lightAlpha: Double) -> Color {
        Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .light
                ? UIColor(rgb: light).withAlphaComponent(lightAlpha)
                : UIColor(rgb: dark).withAlphaComponent(darkAlpha)
        })
    }

    // MARK: - 1. Palette -----------------------------------------------------
    // Bảng đối chiếu: docs/DESIGN.md mục 1.

    public enum Colors {

        // 1.1 Nền
        public static let bgBase          = dyn(dark: 0x0B1020, light: 0xFBF7EF)
        public static let bgSunken        = dyn(dark: 0x070B18, light: 0xF1EADC)
        public static let bgSurface       = dyn(dark: 0x141B33, light: 0xFFFFFF)
        public static let bgSurfaceRaised = dyn(dark: 0x1B2444, light: 0xFFFFFF)
        public static let bgChip          = dyn(dark: 0x1F2A4C, light: 0xF2ECDD)

        // 1.2 Chữ
        public static let textPrimary   = dyn(dark: 0xF2EEE4, light: 0x16182A)
        public static let textSecondary = dyn(dark: 0xA7B0C8, light: 0x4A5270)
        public static let textMuted     = dyn(dark: 0x8791AE, light: 0x676E8C)
        public static let textOnAccent  = dyn(dark: 0x0B1020, light: 0xFFFFFF)

        // 1.3 Nhấn — vàng kim / đồng
        public static let accent     = dyn(dark: 0xD9A94A, light: 0x8A6110)
        public static let accentDim  = dyn(dark: 0x8A6A2A, light: 0xC8A968)
        public static let accentWash = dyn(dark: 0xD9A94A, darkAlpha: 0.14,
                                           light: 0x8A6110, lightAlpha: 0.10)

        // 1.4 Viền & phân cách
        public static let border       = dyn(dark: 0x26314F, light: 0xE2DACA)
        public static let borderStrong = dyn(dark: 0x5B6484, light: 0x8F856E)
        public static let separator    = dyn(dark: 0x1E2842, light: 0xEAE2D2)

        // 1.5 Trạng thái
        public static let success = dyn(dark: 0x57C08A, light: 0x1F7A4D)
        public static let warning = dyn(dark: 0xE0A33A, light: 0x8A5A05)
        public static let danger  = dyn(dark: 0xE5645E, light: 0xB3322C)

        // 1.6 Nguyên tố — thứ tự khớp `AstroConst.elementNames` = Fire/Earth/Air/Water
        public static let elementFire  = dyn(dark: 0xE0764A, light: 0xB4501F)
        public static let elementEarth = dyn(dark: 0x8FA870, light: 0x4C6B2E)
        public static let elementAir   = dyn(dark: 0x7FB6D9, light: 0x1F6A94)
        public static let elementWater = dyn(dark: 0x9B96E0, light: 0x5B4FB0)

        /// `index` 0..3 theo `AstroConst.elementNames` (`const.py:51`).
        public static func element(_ index: Int) -> Color {
            switch index {
            case 0: return elementFire
            case 1: return elementEarth
            case 2: return elementAir
            case 3: return elementWater
            default: return textSecondary
            }
        }

        /// Màu nguyên tố của một cung (0 = Bạch Dương … 11 = Song Ngư).
        /// Hàng của `AstroConst.zodiacMatrix` chính là chỉ số nguyên tố (`const.py:46-50`).
        public static func elementForSign(_ signIndex: Int) -> Color {
            guard let cell = AstroConst.zodiacMatrix[((signIndex % 12) + 12) % 12] else {
                return textSecondary
            }
            return element(cell.row)
        }

        // 1.7 Góc hợp — theo `AstroConst.AspectDef.type`
        public static let aspectHard  = dyn(dark: 0xE5645E, light: 0xB3322C)
        public static let aspectSoft  = dyn(dark: 0x7FB6D9, light: 0x1F6A94)
        public static let aspectMinor = dyn(dark: 0x8FA870, light: 0x4C6B2E)

        /// Nhận đúng chuỗi `"Hard" / "Soft" / "Minor"` của `AstroConst.aspectsDef`.
        public static func aspect(type: String) -> Color {
            switch type {
            case "Hard":  return aspectHard
            case "Soft":  return aspectSoft
            case "Minor": return aspectMinor
            default:      return textSecondary
            }
        }
    }

    // MARK: - 2. Typography ---------------------------------------------------
    // Tiêu đề = New York (serif hệ thống) qua UIFontDescriptor.withDesign(.serif).
    // Thân = SF Pro. Mọi bậc đi qua UIFontMetrics -> hỗ trợ Dynamic Type.

    public enum Fonts {

        /// New York (serif hệ thống Apple), có scale theo Dynamic Type.
        public static func serif(_ size: CGFloat,
                                 weight: UIFont.Weight = .semibold,
                                 relativeTo style: UIFont.TextStyle = .body) -> Font {
            let base = UIFont.systemFont(ofSize: size, weight: weight)
            let desc = base.fontDescriptor.withDesign(.serif) ?? base.fontDescriptor
            let styled = UIFont(descriptor: desc, size: size)
            return Font(UIFontMetrics(forTextStyle: style).scaledFont(for: styled))
        }

        /// SF Pro, có scale theo Dynamic Type.
        public static func sans(_ size: CGFloat,
                                weight: UIFont.Weight = .regular,
                                relativeTo style: UIFont.TextStyle = .body) -> Font {
            let base = UIFont.systemFont(ofSize: size, weight: weight)
            return Font(UIFontMetrics(forTextStyle: style).scaledFont(for: base))
        }

        // --- Tiêu đề (serif New York) ---
        public static let display      = serif(34, weight: .semibold, relativeTo: .largeTitle)
        public static let title1       = serif(28, weight: .semibold, relativeTo: .title1)
        public static let title2       = serif(22, weight: .semibold, relativeTo: .title2)
        public static let sectionTitle = serif(17, weight: .semibold, relativeTo: .headline)

        // --- Thân (SF Pro) ---
        public static let headline    = sans(17, weight: .semibold, relativeTo: .headline)
        public static let body        = sans(17, weight: .regular,  relativeTo: .body)
        public static let callout     = sans(16, weight: .regular,  relativeTo: .callout)
        public static let subheadline = sans(15, weight: .regular,  relativeTo: .subheadline)
        public static let footnote    = sans(13, weight: .regular,  relativeTo: .footnote)
        public static let caption     = sans(12, weight: .regular,  relativeTo: .caption1)

        // --- Số liệu (dùng kèm .monospacedDigit() ở call-site hoặc modifier .numericStyle()) ---
        public static let numeric      = sans(15, weight: .medium,  relativeTo: .subheadline)
        public static let numericSmall = sans(12, weight: .regular, relativeTo: .caption1)

        /// Ký hiệu chiêm tinh — serif để nét glyph hợp với tiêu đề New York.
        public static func glyph(size: CGFloat = 20) -> Font {
            serif(size, weight: .regular, relativeTo: .body)
        }

        /// Nhãn viết hoa nhỏ (SectionHeader kiểu `.caps`).
        public static let caps = sans(11, weight: .semibold, relativeTo: .caption2)
    }

    // MARK: - 3. Spacing ------------------------------------------------------

    public enum Space {
        public static let xxs: CGFloat = 2
        public static let xs:  CGFloat = 4
        public static let sm:  CGFloat = 8
        public static let md:  CGFloat = 12
        public static let lg:  CGFloat = 16
        public static let xl:  CGFloat = 24
        public static let xxl: CGFloat = 32
        public static let xxxl: CGFloat = 48

        /// Lề ngang chuẩn của mọi màn.
        public static let screenH: CGFloat = 16
    }

    // MARK: - 4. Radius -------------------------------------------------------

    public enum Radius {
        public static let sm:   CGFloat = 8
        public static let md:   CGFloat = 12
        public static let lg:   CGFloat = 16
        public static let xl:   CGFloat = 22
        public static let pill: CGFloat = 999
    }

    // MARK: - 5. Shadow -------------------------------------------------------

    public struct ShadowSpec {
        public let color: Color
        public let radius: CGFloat
        public let y: CGFloat
    }

    public enum Shadow {
        public static let card = ShadowSpec(
            color: dyn(dark: 0x000000, darkAlpha: 0.45, light: 0x3A2E14, lightAlpha: 0.10),
            radius: 14, y: 6)
        public static let raised = ShadowSpec(
            color: dyn(dark: 0x000000, darkAlpha: 0.55, light: 0x3A2E14, lightAlpha: 0.14),
            radius: 24, y: 10)
        public static let accentGlow = ShadowSpec(
            color: dyn(dark: 0xD9A94A, darkAlpha: 0.28, light: 0x8A6110, lightAlpha: 0.18),
            radius: 18, y: 0)
    }

    // MARK: - 6. Motion -------------------------------------------------------

    public enum Motion {
        public static let quick    = Animation.easeOut(duration: 0.18)
        public static let standard = Animation.easeInOut(duration: 0.28)
        public static let slow     = Animation.spring(response: 0.45, dampingFraction: 0.85)
    }

    // MARK: - 7. Layout -------------------------------------------------------

    public enum Layout {
        /// Chiều cao tối thiểu vùng chạm (HIG).
        public static let touchTarget: CGFloat = 44
        /// Chiều cao nút chính/phụ.
        public static let buttonHeight: CGFloat = 50
        /// Chiều cao tối thiểu 1 hàng dữ liệu.
        public static let rowMinHeight: CGFloat = 36
        /// Số cột lưới tile ở Dashboard.
        public static let tileColumns: Int = 2
        /// Chiều cao tối thiểu 1 tile điều hướng.
        public static let tileMinHeight: CGFloat = 108
    }

    // MARK: - 8. Áp theme cho các thành phần UIKit còn sót (TabBar / NavBar) ---

    /// Gọi 1 lần lúc app khởi động. Chỉnh nền TabBar + NavBar cho khớp `bgSurface`,
    /// và ép tiêu đề NavBar dùng New York.
    public static func applyGlobalAppearance() {
        let bg = UIColor { t in
            t.userInterfaceStyle == .light ? UIColor(rgb: 0xFFFFFF) : UIColor(rgb: 0x141B33)
        }
        let ink = UIColor { t in
            t.userInterfaceStyle == .light ? UIColor(rgb: 0x16182A) : UIColor(rgb: 0xF2EEE4)
        }

        // --- Tab bar ---
        let tab = UITabBarAppearance()
        tab.configureWithOpaqueBackground()
        tab.backgroundColor = bg
        UITabBar.appearance().standardAppearance = tab
        UITabBar.appearance().scrollEdgeAppearance = tab

        // --- Navigation bar: tiêu đề dùng New York ---
        let nav = UINavigationBarAppearance()
        nav.configureWithOpaqueBackground()
        nav.backgroundColor = UIColor { t in
            t.userInterfaceStyle == .light ? UIColor(rgb: 0xFBF7EF) : UIColor(rgb: 0x0B1020)
        }
        nav.shadowColor = UIColor { t in
            t.userInterfaceStyle == .light ? UIColor(rgb: 0xE2DACA) : UIColor(rgb: 0x26314F)
        }
        nav.titleTextAttributes = [
            .foregroundColor: ink,
            .font: serifUIFont(17, weight: .semibold, relativeTo: .headline)
        ]
        nav.largeTitleTextAttributes = [
            .foregroundColor: ink,
            .font: serifUIFont(34, weight: .semibold, relativeTo: .largeTitle)
        ]
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
        UINavigationBar.appearance().compactAppearance = nav
    }

    /// Bản `UIFont` của New York — dùng cho các API UIKit (NavBar appearance).
    static func serifUIFont(_ size: CGFloat,
                            weight: UIFont.Weight,
                            relativeTo style: UIFont.TextStyle) -> UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        let desc = base.fontDescriptor.withDesign(.serif) ?? base.fontDescriptor
        return UIFontMetrics(forTextStyle: style).scaledFont(for: UIFont(descriptor: desc, size: size))
    }
}

// MARK: - Tiện ích ------------------------------------------------------------

extension UIColor {
    /// Khởi tạo từ mã hex 0xRRGGBB.
    convenience init(rgb: UInt32) {
        self.init(
            red:   CGFloat((rgb >> 16) & 0xFF) / 255.0,
            green: CGFloat((rgb >> 8)  & 0xFF) / 255.0,
            blue:  CGFloat(rgb & 0xFF)         / 255.0,
            alpha: 1.0
        )
    }
}

public extension View {
    /// Áp 1 `ShadowSpec` của Theme.
    func themeShadow(_ spec: Theme.ShadowSpec) -> some View {
        shadow(color: spec.color, radius: spec.radius, x: 0, y: spec.y)
    }

    /// Chữ số cột: font `numeric` + chữ số đều bề ngang.
    func numericStyle() -> some View {
        font(Theme.Fonts.numeric).monospacedDigit()
    }
}
