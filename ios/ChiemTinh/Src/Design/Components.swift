//  Components.swift
//  Thư viện view dùng lại của app — spec ở `docs/DESIGN.md` mục 4.
//  3 worker mảng (Chart / Relationship / Transit) dựng màn bằng những view này,
//  KHÔNG tự chế card/nút/hàng riêng, KHÔNG hardcode màu-size rời.

import SwiftUI

// MARK: - Nền màn hình --------------------------------------------------------

/// Nền chuẩn: xanh đêm sâu + trường sao mờ + quầng sáng vàng rất nhẹ ở đỉnh.
/// KHÔNG gradient tím-hồng (luật DESIGN.md mục 0).
public struct ScreenBackground: View {
    private let starCount: Int
    public init(starCount: Int = 90) { self.starCount = starCount }

    public var body: some View {
        ZStack {
            Theme.Colors.bgBase
            // quầng sáng đồng rất nhạt ở đỉnh màn
            RadialGradient(
                colors: [Theme.Colors.accentWash, Color.clear],
                center: .init(x: 0.5, y: -0.05),
                startRadius: 0, endRadius: 420
            )
            StarField(count: starCount)
        }
        .ignoresSafeArea()
    }
}

/// Trường sao tĩnh (không animation để khỏi tốn pin và khỏi layout shift khi cuộn).
struct StarField: View {
    let count: Int
    var body: some View {
        Canvas { ctx, size in
            var rng = SplitMix64(seed: 0x4368_6965_6D54_696E) // "ChiemTin" — cố định để không nhấp nháy
            for _ in 0..<count {
                let x = Double(rng.next01()) * size.width
                let y = Double(rng.next01()) * size.height
                let r = 0.6 + Double(rng.next01()) * 1.1
                let a = 0.02 + Double(rng.next01()) * 0.04   // opacity ≤ 6%
                ctx.fill(
                    Path(ellipseIn: CGRect(x: x, y: y, width: r * 2, height: r * 2)),
                    with: .color(Color.white.opacity(a))
                )
            }
        }
        .allowsHitTesting(false)
    }
}

/// Sinh số giả ngẫu nhiên xác định — cùng seed cho cùng bố cục sao mọi lần vẽ.
struct SplitMix64 {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
    mutating func next01() -> Double { Double(next() >> 11) / Double(1 << 53) }
}

// MARK: - Thẻ -----------------------------------------------------------------

public struct AstroCard<Content: View>: View {
    public enum Level { case flat, raised }

    private let level: Level
    private let padding: CGFloat
    private let content: Content

    public init(level: Level = .flat,
                padding: CGFloat = Theme.Space.lg,
                @ViewBuilder content: () -> Content) {
        self.level = level
        self.padding = padding
        self.content = content()
    }

    public var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(level == .flat ? Theme.Colors.bgSurface : Theme.Colors.bgSurfaceRaised)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                    .stroke(Theme.Colors.border, lineWidth: 1)
            )
            .themeShadow(level == .flat ? Theme.Shadow.card : Theme.Shadow.raised)
    }
}

// MARK: - Tiêu đề mục ---------------------------------------------------------

public struct SectionHeader<Accessory: View>: View {
    public enum Style { case title, caps }

    private let title: String
    private let subtitle: String?
    private let style: Style
    private let accessory: Accessory

    public init(_ title: String,
                subtitle: String? = nil,
                style: Style = .title,
                @ViewBuilder accessory: () -> Accessory) {
        self.title = title
        self.subtitle = subtitle
        self.style = style
        self.accessory = accessory()
    }

    public var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Space.md) {
            VStack(alignment: .leading, spacing: Theme.Space.xxs) {
                if style == .title {
                    Text(title)
                        .font(Theme.Fonts.sectionTitle)
                        .tracking(0.2)
                        .foregroundStyle(Theme.Colors.accent)
                } else {
                    Text(title.uppercased())
                        .font(Theme.Fonts.caps)
                        .tracking(1.2)
                        .foregroundStyle(Theme.Colors.accent)
                }
                if let subtitle {
                    Text(subtitle)
                        .font(Theme.Fonts.footnote)
                        .foregroundStyle(Theme.Colors.textMuted)
                }
            }
            Spacer(minLength: Theme.Space.sm)
            accessory
        }
        .accessibilityElement(children: .combine)
    }
}

public extension SectionHeader where Accessory == EmptyView {
    init(_ title: String, subtitle: String? = nil, style: Style = .title) {
        self.init(title, subtitle: subtitle, style: style) { EmptyView() }
    }
}

// MARK: - Hàng dữ liệu --------------------------------------------------------

/// Một hàng "nhãn — giá trị". Đây là đơn vị hiển thị số liệu chuẩn của app.
public struct DataRow<Leading: View>: View {
    public enum Tone { case normal, success, warning, danger, accent }

    private let label: String
    private let value: String
    private let detail: String?
    private let tone: Tone
    private let showsSeparator: Bool
    private let leading: Leading

    public init(_ label: String,
                value: String,
                detail: String? = nil,
                tone: Tone = .normal,
                showsSeparator: Bool = true,
                @ViewBuilder leading: () -> Leading) {
        self.label = label
        self.value = value
        self.detail = detail
        self.tone = tone
        self.showsSeparator = showsSeparator
        self.leading = leading()
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: Theme.Space.md) {
                leading
                VStack(alignment: .leading, spacing: Theme.Space.xxs) {
                    Text(label)
                        .font(Theme.Fonts.subheadline)
                        .foregroundStyle(Theme.Colors.textSecondary)
                    if let detail {
                        Text(detail)
                            .font(Theme.Fonts.caption)
                            .foregroundStyle(Theme.Colors.textMuted)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Text(value)
                    .numericStyle()
                    .foregroundStyle(valueColor)
                    .multilineTextAlignment(.trailing)
            }
            .frame(minHeight: Theme.Layout.rowMinHeight)
            .padding(.vertical, Theme.Space.xs)

            if showsSeparator {
                Rectangle()
                    .fill(Theme.Colors.separator)
                    .frame(height: 1)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("\(label): \(value)"))
    }

    private var valueColor: Color {
        switch tone {
        case .normal:  return Theme.Colors.textPrimary
        case .success: return Theme.Colors.success
        case .warning: return Theme.Colors.warning
        case .danger:  return Theme.Colors.danger
        case .accent:  return Theme.Colors.accent
        }
    }
}

public extension DataRow where Leading == EmptyView {
    init(_ label: String,
         value: String,
         detail: String? = nil,
         tone: Tone = .normal,
         showsSeparator: Bool = true) {
        self.init(label, value: value, detail: detail, tone: tone,
                  showsSeparator: showsSeparator) { EmptyView() }
    }
}

// MARK: - Chip ----------------------------------------------------------------

public struct Chip: View {
    public enum Tone { case neutral, accent, success, warning, danger }

    private let text: String
    private let glyph: String?
    private let systemImage: String?
    private let tone: Tone

    public init(_ text: String, glyph: String? = nil, systemImage: String? = nil, tone: Tone = .neutral) {
        self.text = text; self.glyph = glyph; self.systemImage = systemImage; self.tone = tone
    }

    public var body: some View {
        HStack(spacing: Theme.Space.xs) {
            if let glyph {
                Text(glyph).font(Theme.Fonts.glyph(size: 13))
            }
            if let systemImage {
                Image(systemName: systemImage).font(.system(size: 11, weight: .semibold))
            }
            Text(text).font(Theme.Fonts.caption)
        }
        .foregroundStyle(fg)
        .padding(.horizontal, 10)
        .frame(height: 26)
        .background(bg)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(fg.opacity(0.28), lineWidth: tone == .neutral ? 0 : 1))
    }

    private var fg: Color {
        switch tone {
        case .neutral: return Theme.Colors.textSecondary
        case .accent:  return Theme.Colors.accent
        case .success: return Theme.Colors.success
        case .warning: return Theme.Colors.warning
        case .danger:  return Theme.Colors.danger
        }
    }
    private var bg: Color {
        tone == .neutral ? Theme.Colors.bgChip : fg.opacity(0.14)
    }
}

// MARK: - Huy hiệu glyph ------------------------------------------------------

public struct GlyphBadge<Content: View>: View {
    private let tint: Color
    private let size: CGFloat
    private let content: Content

    public init(tint: Color = Theme.Colors.accent, size: CGFloat = 40, @ViewBuilder content: () -> Content) {
        self.tint = tint; self.size = size; self.content = content()
    }

    public var body: some View {
        content
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(tint.opacity(0.16))
            .clipShape(Circle())
    }
}

// MARK: - Nút -----------------------------------------------------------------

public struct AstroPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.Fonts.headline)
            .foregroundStyle(Theme.Colors.textOnAccent)
            .frame(maxWidth: .infinity)
            .frame(height: Theme.Layout.buttonHeight)
            .background(configuration.isPressed ? Theme.Colors.accentDim : Theme.Colors.accent)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
            .opacity(isEnabled ? 1 : 0.5)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(Theme.Motion.quick, value: configuration.isPressed)
    }
}

public struct AstroSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.Fonts.headline)
            .foregroundStyle(Theme.Colors.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: Theme.Layout.buttonHeight)
            .background(configuration.isPressed ? Theme.Colors.bgChip : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                    .stroke(Theme.Colors.borderStrong, lineWidth: 1)
            )
            .opacity(isEnabled ? 1 : 0.5)
            .animation(Theme.Motion.quick, value: configuration.isPressed)
    }
}

public struct AstroGhostButtonStyle: ButtonStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.Fonts.subheadline)
            .foregroundStyle(Theme.Colors.accent)
            .frame(minHeight: Theme.Layout.touchTarget)
            .opacity(configuration.isPressed ? 0.6 : 1)
            .animation(Theme.Motion.quick, value: configuration.isPressed)
    }
}

public extension ButtonStyle where Self == AstroPrimaryButtonStyle {
    static var astroPrimary: AstroPrimaryButtonStyle { .init() }
}
public extension ButtonStyle where Self == AstroSecondaryButtonStyle {
    static var astroSecondary: AstroSecondaryButtonStyle { .init() }
}
public extension ButtonStyle where Self == AstroGhostButtonStyle {
    static var astroGhost: AstroGhostButtonStyle { .init() }
}

// MARK: - Tile điều hướng (Dashboard) ----------------------------------------

public struct NavTile: View {
    private let systemImage: String
    private let title: String
    private let subtitle: String
    private let tint: Color

    public init(systemImage: String, title: String, subtitle: String, tint: Color = Theme.Colors.accent) {
        self.systemImage = systemImage; self.title = title; self.subtitle = subtitle; self.tint = tint
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            GlyphBadge(tint: tint, size: 40) {
                Image(systemName: systemImage).font(.system(size: 17, weight: .semibold))
            }
            Text(title)
                .font(Theme.Fonts.headline)
                .foregroundStyle(Theme.Colors.textPrimary)
                .multilineTextAlignment(.leading)
            Text(subtitle)
                .font(Theme.Fonts.caption)
                .foregroundStyle(Theme.Colors.textMuted)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: Theme.Layout.tileMinHeight, alignment: .topLeading)
        .padding(Theme.Space.lg)
        .background(Theme.Colors.bgSurface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous)
                .stroke(Theme.Colors.border, lineWidth: 1)
        )
        .themeShadow(Theme.Shadow.card)
        .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous))
    }
}

// MARK: - Bảng số liệu cuộn ngang --------------------------------------------

/// Bảng số liệu: cột đầu ghim trái, các cột còn lại cuộn ngang **trong thẻ**.
/// Thân màn hình không bao giờ cuộn ngang (luật DESIGN.md mục 3.5).
public struct StatTable: View {
    public struct Row: Identifiable {
        public let id: String
        public let head: String
        public let cells: [String]
        public let headTint: Color?
        public init(id: String, head: String, cells: [String], headTint: Color? = nil) {
            self.id = id; self.head = head; self.cells = cells; self.headTint = headTint
        }
    }

    private let headColumn: String
    private let columns: [String]
    private let rows: [Row]
    private let headWidth: CGFloat
    private let cellWidth: CGFloat

    public init(headColumn: String,
                columns: [String],
                rows: [Row],
                headWidth: CGFloat = 96,
                cellWidth: CGFloat = 72) {
        self.headColumn = headColumn
        self.columns = columns
        self.rows = rows
        self.headWidth = headWidth
        self.cellWidth = cellWidth
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // Cột ghim
            VStack(spacing: 0) {
                cellText(headColumn, isHeader: true)
                    .frame(width: headWidth, alignment: .leading)
                ForEach(Array(rows.enumerated()), id: \.element.id) { idx, row in
                    cellText(row.head, isHeader: false, tint: row.headTint)
                        .frame(width: headWidth, alignment: .leading)
                        .background(idx.isMultiple(of: 2) ? Theme.Colors.bgSunken.opacity(0.4) : Color.clear)
                }
            }
            Rectangle().fill(Theme.Colors.border).frame(width: 1)

            // Vùng cuộn ngang
            ScrollView(.horizontal, showsIndicators: true) {
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        ForEach(columns, id: \.self) { c in
                            cellText(c, isHeader: true).frame(width: cellWidth)
                        }
                    }
                    ForEach(Array(rows.enumerated()), id: \.element.id) { idx, row in
                        HStack(spacing: 0) {
                            ForEach(Array(row.cells.enumerated()), id: \.offset) { _, v in
                                cellText(v, isHeader: false).frame(width: cellWidth)
                            }
                        }
                        .background(idx.isMultiple(of: 2) ? Theme.Colors.bgSunken.opacity(0.4) : Color.clear)
                    }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                .stroke(Theme.Colors.border, lineWidth: 1)
        )
    }

    @ViewBuilder
    private func cellText(_ s: String, isHeader: Bool, tint: Color? = nil) -> some View {
        Text(isHeader ? s.uppercased() : s)
            .font(isHeader ? Theme.Fonts.caps : Theme.Fonts.numericSmall)
            .monospacedDigit()
            .tracking(isHeader ? 1.0 : 0)
            .foregroundStyle(tint ?? (isHeader ? Theme.Colors.textMuted : Theme.Colors.textPrimary))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.horizontal, Theme.Space.sm)
            .frame(height: isHeader ? 30 : 32)
    }
}

// MARK: - Trạng thái rỗng / đang tải -----------------------------------------

public struct EmptyState: View {
    private let systemImage: String
    private let title: String
    private let message: String
    private let actionTitle: String?
    private let action: (() -> Void)?

    public init(systemImage: String,
                title: String,
                message: String,
                actionTitle: String? = nil,
                action: (() -> Void)? = nil) {
        self.systemImage = systemImage; self.title = title; self.message = message
        self.actionTitle = actionTitle; self.action = action
    }

    public var body: some View {
        VStack(spacing: Theme.Space.md) {
            Image(systemName: systemImage)
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(Theme.Colors.accentDim)
            Text(title)
                .font(Theme.Fonts.title2)
                .foregroundStyle(Theme.Colors.textPrimary)
                .multilineTextAlignment(.center)
            Text(message)
                .font(Theme.Fonts.callout)
                .foregroundStyle(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.astroSecondary)
                    .padding(.top, Theme.Space.xs)
            }
        }
        .padding(Theme.Space.xl)
        .frame(maxWidth: .infinity)
    }
}

public struct LoadingBlock: View {
    private let text: String
    public init(_ text: String = "Đang tính…") { self.text = text }
    public var body: some View {
        VStack(spacing: Theme.Space.md) {
            ProgressView().tint(Theme.Colors.accent)
            Text(text)
                .font(Theme.Fonts.footnote)
                .foregroundStyle(Theme.Colors.textMuted)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
    }
}

// MARK: - Chỗ cắm cho worker khác --------------------------------------------

/// Placeholder tạm cho các màn do worker khác thi công.
/// Worker mảng nào thay được thì XOÁ chỗ gọi placeholder ở `RootTabView`/`DashboardView`.
public struct PlaceholderScreen: View {
    private let title: String
    private let owner: String
    private let note: String

    public init(title: String, owner: String, note: String) {
        self.title = title; self.owner = owner; self.note = note
    }

    public var body: some View {
        ZStack {
            ScreenBackground()
            ScrollView {
                VStack(spacing: Theme.Space.lg) {
                    EmptyState(
                        systemImage: "hammer",
                        title: title,
                        message: note
                    )
                    AstroCard {
                        VStack(alignment: .leading, spacing: Theme.Space.sm) {
                            SectionHeader("Chỗ cắm", style: .caps)
                            DataRow("Mảng", value: title, showsSeparator: true)
                            DataRow("Người thi công", value: owner, showsSeparator: false)
                        }
                    }
                }
                .padding(.horizontal, Theme.Space.screenH)
                .padding(.vertical, Theme.Space.lg)
            }
        }
    }
}

// MARK: - Tiện ích bố cục -----------------------------------------------------

public extension View {
    /// Lề ngang chuẩn của màn hình.
    func screenPadding() -> some View {
        padding(.horizontal, Theme.Space.screenH)
    }
}
