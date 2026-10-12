//  DashboardView.swift
//  Màn chính của tab "Lá số". Bản NATIVE cho điện thoại, KHÔNG copy bố cục web.
//  Đối chiếu nội dung web: `app/templates/dashboard.html` có 6 thẻ điều hướng
//  (Nhập Dữ Liệu · Natal · Synastry · Composite · Trao Đổi Năng Lượng · Vận Hạn — dashboard.html:48-53).
//  App giữ đủ 6 lối vào đó nhưng xếp lại theo thói quen dùng điện thoại:
//  hồ sơ đang xem lên đầu (thứ người dùng chạm nhiều nhất), rồi mới tới lưới chức năng.

import SwiftUI

/// Các màn con của tab "Lá số".
public enum NatalRoute: Hashable {
    case natalChart
    case profileForm(UUID?)   // nil = tạo mới
}

public struct DashboardView: View {
    @EnvironmentObject private var app: AppState
    @State private var path: [NatalRoute] = []

    public init() {}

    public var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                ScreenBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Space.xl) {
                        headerBlock
                        currentProfileBlock
                        featureGrid
                        footerBlock
                    }
                    .screenPadding()
                    .padding(.top, Theme.Space.sm)
                    .padding(.bottom, Theme.Space.xxl)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Lá số")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        path.append(.profileForm(nil))
                    } label: {
                        Image(systemName: "plus")
                    }
                    .tint(Theme.Colors.accent)
                    .accessibilityLabel("Thêm hồ sơ mới")
                }
            }
            .navigationDestination(for: NatalRoute.self) { route in
                switch route {
                case .natalChart:
                    NatalScreen()
                        .navigationTitle("Bản đồ sao")
                        .navigationBarTitleDisplayMode(.inline)
                case .profileForm(let id):
                    ProfileFormView(editingID: id)
                }
            }
            // Hồ sơ có thể được lưu từ màn Quan hệ / Vận hạn (cùng kho SwiftData),
            // nên nạp lại bản chụp mỗi lần màn hiện ra.
            .onAppear { app.reload() }
        }
    }

    // MARK: - Khối tiêu đề

    private var headerBlock: some View {
        VStack(alignment: .leading, spacing: Theme.Space.xs) {
            Text("Chiêm Tinh")
                .font(Theme.Fonts.display)
                .tracking(0.2)
                .foregroundStyle(Theme.Colors.textPrimary)
            Text(Self.todayVN)
                .font(Theme.Fonts.footnote)
                .foregroundStyle(Theme.Colors.textMuted)
            HStack(spacing: Theme.Space.sm) {
                Chip("Ngoại tuyến 100%", systemImage: "wifi.slash", tone: .accent)
                Chip("Placidus", tone: .neutral)
            }
            .padding(.top, Theme.Space.xs)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private static var todayVN: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "vi_VN")
        f.dateFormat = "EEEE, d MMMM yyyy"
        return f.string(from: Date()).capitalizedFirst
    }

    // MARK: - Hồ sơ đang xem

    @ViewBuilder
    private var currentProfileBlock: some View {
        VStack(alignment: .leading, spacing: Theme.Space.md) {
            SectionHeader("Hồ sơ đang xem", style: .caps) {
                if !app.profiles.isEmpty {
                    Button("Đổi") { app.selectedTab = .profile }
                        .buttonStyle(.astroGhost)
                }
            }

            if let p = app.selectedProfile {
                AstroCard {
                    VStack(alignment: .leading, spacing: Theme.Space.md) {
                        HStack(spacing: Theme.Space.md) {
                            GlyphBadge(tint: Theme.Colors.accent, size: 44) {
                                Image(systemName: "person.fill").font(.system(size: 18, weight: .semibold))
                            }
                            VStack(alignment: .leading, spacing: Theme.Space.xxs) {
                                Text(p.name)
                                    .font(Theme.Fonts.title2)
                                    .foregroundStyle(Theme.Colors.textPrimary)
                                Text(p.summaryLine)
                                    .font(Theme.Fonts.footnote)
                                    .foregroundStyle(Theme.Colors.textMuted)
                                    .lineLimit(2)
                            }
                            Spacer(minLength: 0)
                        }

                        if p.timeUnknown {
                            Chip("Giờ sinh không rõ — nhà và AC sẽ lệch",
                                 systemImage: "exclamationmark.triangle", tone: .warning)
                        }

                        HStack(spacing: Theme.Space.md) {
                            Button("Xem lá số") { path.append(.natalChart) }
                                .buttonStyle(.astroPrimary)
                            Button("Sửa") { path.append(.profileForm(p.id)) }
                                .buttonStyle(.astroSecondary)
                                .frame(maxWidth: 96)
                        }
                    }
                }
            } else {
                AstroCard {
                    EmptyState(
                        systemImage: "person.badge.plus",
                        title: "Chưa có hồ sơ nào",
                        message: "Thêm ngày, giờ và nơi sinh để tính lá số. Mọi dữ liệu chỉ nằm trên máy bạn.",
                        actionTitle: "Thêm hồ sơ",
                        action: { path.append(.profileForm(nil)) }
                    )
                }
            }
        }
    }

    // MARK: - Lưới chức năng (6 lối vào như dashboard.html:48-53)

    private var featureGrid: some View {
        VStack(alignment: .leading, spacing: Theme.Space.md) {
            SectionHeader("Chức năng", style: .caps)

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: Theme.Space.md),
                               count: Theme.Layout.tileColumns),
                spacing: Theme.Space.md
            ) {
                tileButton(action: { path.append(.profileForm(nil)) }) {
                    NavTile(systemImage: "person.badge.plus",
                            title: "Nhập dữ liệu",
                            subtitle: "Thêm, sửa, xoá hồ sơ sinh",
                            tint: Theme.Colors.accent)
                }
                tileButton(action: { path.append(.natalChart) }) {
                    NavTile(systemImage: "sparkles",
                            title: "Bản đồ sao",
                            subtitle: "Lá số cá nhân & phân tích",
                            tint: Theme.Colors.accent)
                }
                tileButton(action: { app.selectedTab = .relationship }) {
                    NavTile(systemImage: "heart",
                            title: "Cặp đôi",
                            subtitle: "Tương hợp Synastry giữa 2 người",
                            tint: Theme.Colors.elementFire)
                }
                tileButton(action: { app.selectedTab = .relationship }) {
                    NavTile(systemImage: "circle.hexagongrid",
                            title: "Composite",
                            subtitle: "Biểu đồ hợp nhất (midpoint)",
                            tint: Theme.Colors.elementWater)
                }
                tileButton(action: { app.selectedTab = .library }) {
                    NavTile(systemImage: "bolt.horizontal.circle",
                            title: "Trao đổi năng lượng",
                            subtitle: "Planet Connect: nhận & truyền",
                            tint: Theme.Colors.elementAir)
                }
                tileButton(action: { app.selectedTab = .transit }) {
                    NavTile(systemImage: "clock.arrow.2.circlepath",
                            title: "Vận hạn",
                            subtitle: "Vận hạn chung, riêng & chi tiết",
                            tint: Theme.Colors.elementEarth)
                }
            }
        }
    }

    private func tileButton<V: View>(action: @escaping () -> Void, @ViewBuilder label: () -> V) -> some View {
        Button(action: action, label: label)
            .buttonStyle(.plain)
    }

    // MARK: - Chân trang

    private var footerBlock: some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            Rectangle().fill(Theme.Colors.separator).frame(height: 1)
            Text("Tính bằng Swiss Ephemeris \(SwissEph.version()) biên dịch thẳng vào app — không gọi máy chủ nào.")
                .font(Theme.Fonts.caption)
                .foregroundStyle(Theme.Colors.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, Theme.Space.sm)
    }
}

extension String {
    /// Viết hoa chữ cái đầu, giữ nguyên phần còn lại (tránh `capitalized` phá tên riêng).
    var capitalizedFirst: String {
        guard let f = first else { return self }
        return String(f).uppercased() + dropFirst()
    }
}

#Preview {
    DashboardView().environmentObject(AppState())
}
