//  ChiemTinhApp.swift
//  App SwiftUI native 100% — toàn bộ tính toán chạy TRONG máy, KHÔNG gọi backend nào.
//  Hệ thiết kế: `docs/DESIGN.md` (SSOT token) -> `Src/Design/Theme.swift`.

import SwiftUI

@main
struct ChiemTinhApp: App {
    @StateObject private var appState = AppState()

    init() {
        // Trỏ Swiss Ephemeris vào 3 file .se1 nằm trong bundle app.
        SwissEph.bootstrapFromBundle()
        // Áp token màu/typography cho TabBar + NavigationBar (phần UIKit còn sót của SwiftUI).
        Theme.applyGlobalAppearance()
        // W21: cắm dịch vụ dùng chung MỘT LẦN cho TOÀN APP, không để từng màn tự cắm ở `.task`
        // (trước đây chỉ 4 màn Vận Hạn gọi, các màn khác vẫn xài bảng tạm 12 tỉnh).
        //  · `LocationSearch.provider` -> `LocationDirectory` (bảng 177 địa điểm, tìm mờ, múi giờ)
        //  · kéo nốt hồ sơ cũ trong UserDefaults sang SwiftData
        MainActor.assumeIsolated { W20Services.install() }
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(appState)
                // Dark-first theo hướng founder chốt (DESIGN.md mục 0).
                .preferredColorScheme(.dark)
                .tint(Theme.Colors.accent)
        }
    }
}
