//  RootTabView.swift
//  Khung điều hướng gốc: TabBar native 5 tab.
//  Bản đồ tab <-> route web: xem `docs/DESIGN.md` mục 6.
//
//  W21 đã cắm ĐỦ 5 màn thật (không còn `PlaceholderScreen` nào):
//    Lá số -> DashboardView · Hợp đôi -> RelationshipScreen · Vận hạn -> VanHanMenuScreen
//    Tra cứu -> LibraryScreen · Hồ sơ -> ProfileListView

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

            // 2 — Hợp đôi: `RelationshipScreen` TỰ CÓ NavigationStack (RelationshipScreen.swift:52)
            //     nên KHÔNG bọc thêm, tránh lồng 2 thanh điều hướng.
            RelationshipScreen()
                .tabItem { Label(RootTab.relationship.title, systemImage: RootTab.relationship.systemImage) }
                .tag(RootTab.relationship)

            // 3 — Vận hạn: menu 3 màn của web (`transits.py:24-27`).
            NavigationStack {
                VanHanMenuScreen()
            }
            .tabItem { Label(RootTab.transit.title, systemImage: RootTab.transit.systemImage) }
            .tag(RootTab.transit)

            // 4 — Tra cứu: `LibraryScreen` tự có NavigationStack, đọc 14 JSON + 8 bảng
            //     trong bundle qua `VaultLoader`.
            LibraryScreen()
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
