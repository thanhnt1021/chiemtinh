//  RootTabView.swift
//  Khung điều hướng gốc: TabBar native 5 tab.
//  Bản đồ tab <-> route web: xem `docs/DESIGN.md` mục 6.
//
//  QUAN TRỌNG cho 3 worker mảng: chỗ cắm màn của các bạn nằm trong file này
//  (`PlaceholderScreen`). Thay bằng view thật của mình, GIỮ NGUYÊN nhãn tab.

import SwiftUI

public enum RootTab: String, Hashable, CaseIterable {
    case natal        // Lá số        <- /dashboard, /natal, /input
    case relationship // Hợp đôi      <- /synastry, /composite
    case transit      // Vận hạn      <- /vanhan, /vanhan/*
    case library      // Tra cứu      <- /planet-connect + 15 JSON nội dung
    case profile      // Hồ sơ        <- /user, /edit_profile, /nuoitool

    public var title: String {
        switch self {
        case .natal:        return "Lá số"
        case .relationship: return "Hợp đôi"
        case .transit:      return "Vận hạn"
        case .library:      return "Tra cứu"
        case .profile:      return "Hồ sơ"
        }
    }

    public var systemImage: String {
        switch self {
        case .natal:        return "sparkles"
        case .relationship: return "heart.circle"
        case .transit:      return "clock.arrow.2.circlepath"
        case .library:      return "book.closed"
        case .profile:      return "person.crop.circle"
        }
    }
}

public struct RootTabView: View {
    @EnvironmentObject private var app: AppState

    public init() {}

    public var body: some View {
        TabView(selection: $app.selectedTab) {

            // 1 — Lá số: dashboard + lá số cá nhân
            DashboardView()
                .tabItem { Label(RootTab.natal.title, systemImage: RootTab.natal.systemImage) }
                .tag(RootTab.natal)

            // 2 — Hợp đôi: worker Synastry/Composite cắm view thật vào đây
            NavigationStack {
                PlaceholderScreen(
                    title: "Hợp đôi (Synastry & Composite)",
                    owner: "worker mảng Synastry/Composite — Src/Relationship/",
                    note: "Màn tương hợp cặp đôi và biểu đồ hợp nhất (midpoint) đang được thi công song song. "
                        + "Khung điều hướng, token màu và bộ component đã sẵn sàng để cắm vào."
                )
                .navigationTitle(RootTab.relationship.title)
            }
            .tabItem { Label(RootTab.relationship.title, systemImage: RootTab.relationship.systemImage) }
            .tag(RootTab.relationship)

            // 3 — Vận hạn: worker Transit cắm view thật vào đây
            NavigationStack {
                PlaceholderScreen(
                    title: "Vận hạn (Transit)",
                    owner: "worker mảng Transit — Src/Transit/",
                    note: "Ba màn của web: Vận hạn chung (bầu trời hiện tại), Vận hạn riêng (transit lên lá số) "
                        + "và Vận hạn chi tiết (dòng thời gian theo nhà) đang được thi công song song."
                )
                .navigationTitle(RootTab.transit.title)
            }
            .tabItem { Label(RootTab.transit.title, systemImage: RootTab.transit.systemImage) }
            .tag(RootTab.transit)

            // 4 — Tra cứu: worker Data cắm nội dung 15 file JSON vào đây
            NavigationStack {
                PlaceholderScreen(
                    title: "Tra cứu nội dung",
                    owner: "worker mảng Dữ liệu — Src/Data/ + Resources/",
                    note: "Trao đổi năng lượng (Planet Connect) và toàn bộ diễn giải từ 15 file JSON "
                        + "sẽ hiển thị ở đây, đọc thẳng từ bundle nên chạy hoàn toàn ngoại tuyến."
                )
                .navigationTitle(RootTab.library.title)
            }
            .tabItem { Label(RootTab.library.title, systemImage: RootTab.library.systemImage) }
            .tag(RootTab.library)

            // 5 — Hồ sơ
            ProfileListView()
                .tabItem { Label(RootTab.profile.title, systemImage: RootTab.profile.systemImage) }
                .tag(RootTab.profile)
        }
        .tint(Theme.Colors.accent)
    }
}

#Preview {
    RootTabView().environmentObject(AppState())
}
