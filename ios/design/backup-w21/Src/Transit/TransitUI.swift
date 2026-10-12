//  TransitUI.swift
//  Mảnh giao diện dùng chung cho 4 màn vận hạn + 3 tra cứu.
//  Token lấy từ `Src/Design/Theme.swift` của W17 (Theme.Colors / Fonts / Space / Radius / Shadow).

import SwiftUI

// MARK: - Thẻ nội dung -------------------------------------------------------

public struct TCard<Content: View>: View {
    private let title: String?
    private let content: Content

    public init(_ title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.md) {
            if let title {
                Text(title.uppercased())
                    .font(Theme.Fonts.caps)
                    .kerning(0.8)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                Divider().overlay(Theme.Colors.separator)
            }
            content
        }
        .padding(Theme.Space.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Colors.bgSurface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                .stroke(Theme.Colors.border, lineWidth: 1)
        )
        .shadow(color: Theme.Shadow.card.color,
                radius: Theme.Shadow.card.radius, y: Theme.Shadow.card.y)
    }
}

// MARK: - Băng thông báo -----------------------------------------------------

public struct TBanner: View {
    public enum Kind { case info, warning, danger }
    public let kind: Kind
    public let text: String

    public init(_ kind: Kind, _ text: String) { self.kind = kind; self.text = text }

    private var tint: Color {
        switch kind {
        case .info:    return Theme.Colors.accent
        case .warning: return Theme.Colors.warning
        case .danger:  return Theme.Colors.danger
        }
    }
    private var icon: String {
        switch kind {
        case .info:    return "info.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .danger:  return "xmark.octagon.fill"
        }
    }

    public var body: some View {
        HStack(alignment: .top, spacing: Theme.Space.sm) {
            Image(systemName: icon).foregroundStyle(tint)
            Text(text).font(Theme.Fonts.footnote).foregroundStyle(Theme.Colors.textPrimary)
            Spacer(minLength: 0)
        }
        .padding(Theme.Space.md)
        .background(tint.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                    .stroke(tint.opacity(0.35), lineWidth: 1))
    }
}

// MARK: - Nút chính ----------------------------------------------------------

public struct TPrimaryButton: View {
    public let title: String
    public var tint: Color = Theme.Colors.accent
    public var busy: Bool = false
    public var disabled: Bool = false
    public let action: () -> Void

    public init(_ title: String, tint: Color = Theme.Colors.accent,
                busy: Bool = false, disabled: Bool = false, action: @escaping () -> Void) {
        self.title = title; self.tint = tint; self.busy = busy
        self.disabled = disabled; self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Space.sm) {
                if busy { ProgressView().tint(Theme.Colors.textOnAccent) }
                Text(busy ? "ĐANG XỬ LÝ…" : title.uppercased())
                    .font(Theme.Fonts.headline).kerning(1.0)
            }
            .frame(maxWidth: .infinity, minHeight: Theme.Layout.buttonHeight)
            .foregroundStyle(Theme.Colors.textOnAccent)
            .background(tint.opacity(disabled || busy ? 0.45 : 1))
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
        }
        .disabled(disabled || busy)
        .buttonStyle(.plain)
    }
}

// MARK: - Hàng bảng ----------------------------------------------------------

/// Hàng "ký hiệu + tên" giống ô hành tinh của web (`reports/transit.py:116-124`).
public struct TPlanetCell: View {
    public let symbol: String
    public let name: String
    public var tint: Color = Theme.Colors.textPrimary
    public var small: Bool = false

    public init(symbol: String, name: String,
                tint: Color = Theme.Colors.textPrimary, small: Bool = false) {
        self.symbol = symbol; self.name = name; self.tint = tint; self.small = small
    }

    public var body: some View {
        HStack(spacing: Theme.Space.xs) {
            Text(symbol)
                .font(.system(size: small ? 12 : 19, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 22, alignment: .center)
            Text(name).font(Theme.Fonts.footnote).foregroundStyle(Theme.Colors.textPrimary)
        }
    }
}

/// Màu hành tinh — port `get_p_color` (`reports/transit.py:60-64`).
public enum TransitPalette {
    public static func planet(_ name: String) -> Color {
        switch name {
        case "Sun", "Mars", "Jupiter":       return Theme.Colors.elementFire
        case "Moon", "Neptune", "Pluto":     return Theme.Colors.elementWater
        case "Mercury", "Venus", "Uranus":   return Theme.Colors.elementEarth
        default:                             return Theme.Colors.textPrimary
        }
    }
    /// Hành tinh transit trong bảng NHÀ TRANSIT của web luôn là màu xanh lá.
    public static let transitTint = Theme.Colors.success
}

// MARK: - Ô chọn ngày dạng D/M/Y --------------------------------------------

/// Web dùng 3 ô số riêng (`transit_personal.html:78-82`) chứ không dùng `<input type=date>`.
/// Giữ nguyên cách nhập đó, thêm kiểm biên ephemeris.
public struct TDMYField: View {
    public let title: String
    @Binding public var day: Int
    @Binding public var month: Int
    @Binding public var year: Int

    public init(title: String, day: Binding<Int>, month: Binding<Int>, year: Binding<Int>) {
        self.title = title; self._day = day; self._month = month; self._year = year
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.xs) {
            Text(title).font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.textSecondary)
            HStack(spacing: Theme.Space.sm) {
                numberBox($day, "Ngày", 1...31)
                numberBox($month, "Tháng", 1...12)
                numberBox($year, "Năm", 1800...2399)
            }
            if !EphemerisWindow.contains(year: year, month: month, day: max(1, min(day, 28))) {
                Text("Ngoài khoảng dữ liệu thiên văn (\(EphemerisWindow.rangeLabel)).")
                    .font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.danger)
            }
        }
    }

    private func numberBox(_ v: Binding<Int>, _ ph: String, _ range: ClosedRange<Int>) -> some View {
        VStack(spacing: 2) {
            TextField(ph, value: v, format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(Theme.Fonts.numeric)
                .padding(.vertical, 10)
                .background(Theme.Colors.bgChip)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))
                .onChange(of: v.wrappedValue) { _, nv in
                    if nv < range.lowerBound { v.wrappedValue = range.lowerBound }
                    if nv > range.upperBound { v.wrappedValue = range.upperBound }
                }
            Text(ph).font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.textMuted)
        }
    }
}
