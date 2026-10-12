//  ProfileListView.swift
//  Tab "Hồ sơ". Đối chiếu web: `/user` (`app/templates/user.html:64-101`) — danh sách hồ sơ đã lưu
//  với 3 thao tác Xem / Sửa / Xoá, cộng khối "Ủng hộ" của `/nuoitool` (`nuoitool.html:26-63`).
//  Web còn có "Thông tin tài khoản" + "Đổi mật khẩu": app chạy ngoại tuyến, không có tài khoản
//  nên hai khối đó bị bỏ (ghi rõ trong `docs/DESIGN.md` mục 6).

import SwiftUI

public struct ProfileListView: View {
    @EnvironmentObject private var app: AppState
    @State private var path: [NatalRoute] = []
    @State private var pendingDelete: SavedProfile?

    public init() {}

    public var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                ScreenBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Space.xl) {
                        profilesSection
                        aboutSection
                    }
                    .screenPadding()
                    .padding(.vertical, Theme.Space.lg)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Hồ sơ")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { path.append(.profileForm(nil)) } label: { Image(systemName: "plus") }
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
            .alert("Xoá hồ sơ?", isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            )) {
                Button("Xoá", role: .destructive) {
                    if let p = pendingDelete { app.delete(id: p.id) }
                    pendingDelete = nil
                }
                Button("Huỷ", role: .cancel) { pendingDelete = nil }
            } message: {
                Text("Hồ sơ “\(pendingDelete?.name ?? "")” sẽ bị xoá khỏi máy. Không khôi phục được.")
            }
        }
    }

    // MARK: - Danh sách hồ sơ

    @ViewBuilder
    private var profilesSection: some View {
        VStack(alignment: .leading, spacing: Theme.Space.md) {
            SectionHeader("Hồ sơ đã lưu",
                          subtitle: app.profiles.isEmpty ? nil : "\(app.profiles.count) hồ sơ trên máy này")

            if app.profiles.isEmpty {
                AstroCard {
                    EmptyState(
                        systemImage: "person.crop.circle.badge.plus",
                        title: "Chưa có hồ sơ",
                        message: "Hồ sơ lưu ngay trên máy, không gửi đi đâu cả.",
                        actionTitle: "Thêm hồ sơ",
                        action: { path.append(.profileForm(nil)) }
                    )
                }
            } else {
                VStack(spacing: Theme.Space.md) {
                    ForEach(app.profiles) { p in
                        profileCard(p)
                    }
                }
            }
        }
    }

    private func profileCard(_ p: SavedProfile) -> some View {
        let isSelected = app.selectedProfile?.id == p.id
        return AstroCard(level: isSelected ? .raised : .flat) {
            VStack(alignment: .leading, spacing: Theme.Space.md) {
                HStack(spacing: Theme.Space.md) {
                    GlyphBadge(tint: isSelected ? Theme.Colors.accent : Theme.Colors.textMuted, size: 40) {
                        Image(systemName: isSelected ? "star.fill" : "person.fill")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    VStack(alignment: .leading, spacing: Theme.Space.xxs) {
                        Text(p.name)
                            .font(Theme.Fonts.headline)
                            .foregroundStyle(Theme.Colors.textPrimary)
                        Text(p.summaryLine)
                            .font(Theme.Fonts.caption)
                            .foregroundStyle(Theme.Colors.textMuted)
                            .lineLimit(2)
                    }
                    Spacer(minLength: 0)
                    Chip(p.gender.labelVN, tone: .neutral)
                }

                HStack(spacing: Theme.Space.lg) {
                    Button("Xem") {
                        app.selectedProfileID = p.id
                        app.selectedTab = .natal
                    }
                    .buttonStyle(.astroGhost)

                    Button("Sửa") { path.append(.profileForm(p.id)) }
                        .buttonStyle(.astroGhost)

                    Button("Xoá") { pendingDelete = p }
                        .buttonStyle(.astroGhost)
                        .tint(Theme.Colors.danger)

                    Spacer(minLength: 0)

                    if !isSelected {
                        Button("Chọn") { app.selectedProfileID = p.id }
                            .buttonStyle(.astroGhost)
                    }
                }
            }
        }
    }

    // MARK: - Giới thiệu & ủng hộ

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: Theme.Space.md) {
            SectionHeader("Về ứng dụng", style: .caps)
            AstroCard {
                VStack(spacing: 0) {
                    DataRow("Swiss Ephemeris", value: SwissEph.version())
                    DataRow("Hệ nhà", value: "Placidus")
                    DataRow("Dữ liệu", value: "Chỉ lưu trên máy")
                    DataRow("Kết nối máy chủ", value: "Không", tone: .success, showsSeparator: false)
                }
            }
            Link(destination: URL(string: "https://forms.gle/VhjiQdgXCRFQNoHbA")!) {
                HStack(spacing: Theme.Space.sm) {
                    Image(systemName: "text.bubble")
                    Text("Ý kiến ý cò")
                }
                .font(Theme.Fonts.subheadline)
                .foregroundStyle(Theme.Colors.accent)
                .frame(minHeight: Theme.Layout.touchTarget)
            }
        }
    }
}

#Preview {
    ProfileListView().environmentObject(AppState())
}
