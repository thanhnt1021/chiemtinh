//  VanHanMenuScreen.swift
//  MÀN 1/4 — port `/vanhan` (`app/routes/transits.py:24-27`,
//  `app/templates/vanhan_menu.html`, 3 thẻ điều hướng + nút quay lại Dashboard).

import SwiftUI

public struct VanHanMenuScreen: View {

    @ObservedObject public var store: ProfileStore

    public init(store: ProfileStore = .shared) { self.store = store }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.lg) {
                Text("Ba cách nhìn vận hạn — bầu trời lúc này, dự báo cho riêng bạn, và dòng thời gian chi tiết theo Nhà.")
                    .font(Theme.Fonts.callout)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .padding(.bottom, Theme.Space.xs)

                NavigationLink { TransitGeneralScreen() } label: {
                    card(icon: "globe.asia.australia.fill",
                         title: "Vận Hạn Chung",
                         desc: "Xem bản đồ sao hiện tại (Current Planets)",
                         tint: Theme.Colors.accent)
                }.buttonStyle(.plain)

                NavigationLink { TransitPersonalScreen(store: store) } label: {
                    card(icon: "person.crop.circle.badge.clock",
                         title: "Vận Hạn Riêng",
                         desc: "Dự báo cá nhân (Transits to Natal)",
                         tint: Theme.Colors.elementWater)
                }.buttonStyle(.plain)

                NavigationLink { TransitDetailedScreen(store: store) } label: {
                    card(icon: "calendar.badge.clock",
                         title: "Vận Hạn Chi Tiết",
                         desc: "Phân tích chu kỳ Nhà (Detailed Timeline)",
                         tint: Theme.Colors.aspectSoft)
                }.buttonStyle(.plain)

                TBanner(.info, "Toàn bộ tính toán chạy trong máy. Dữ liệu thiên văn phủ \(EphemerisWindow.rangeLabel).")
            }
            .padding(Theme.Space.screenH)
        }
        .background(Theme.Colors.bgBase)
        .navigationTitle("Xem Vận Hạn")
        .navigationBarTitleDisplayMode(.large)
        .task {
            W20Services.install()                       // cắm bảng địa điểm + kéo hồ sơ từ AppState
            await TransitEngine.shared.warmUp()         // mồi engine như web (transits.py:165)
        }
    }

    private func card(icon: String, title: String, desc: String, tint: Color) -> some View {
        HStack(spacing: Theme.Space.lg) {
            ZStack {
                Circle().fill(tint.opacity(0.16)).frame(width: 56, height: 56)
                Image(systemName: icon).font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(tint)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(Theme.Fonts.title2).foregroundStyle(Theme.Colors.textPrimary)
                Text(desc).font(Theme.Fonts.footnote).foregroundStyle(Theme.Colors.textSecondary)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").foregroundStyle(Theme.Colors.textMuted)
        }
        .padding(Theme.Space.lg)
        .frame(maxWidth: .infinity, minHeight: Theme.Layout.tileMinHeight, alignment: .leading)
        .background(Theme.Colors.bgSurface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                    .stroke(tint.opacity(0.45), lineWidth: 1))
        .shadow(color: Theme.Shadow.card.color,
                radius: Theme.Shadow.card.radius, y: Theme.Shadow.card.y)
    }
}
