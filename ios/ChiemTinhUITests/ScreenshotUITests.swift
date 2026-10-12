//  ScreenshotUITests.swift
//  Tự cuộn màn hình và chụp ảnh BÊN TRONG simulator (không đụng chuột thật của người dùng).
//  Ảnh ghi vào thư mục tạm của tiến trình test — thư mục này nằm ngay trên đĩa máy Mac
//  (…/CoreSimulator/Devices/<udid>/data/…) nên agent đọc lại được để soi layout.

import XCTest

final class ScreenshotUITests: XCTestCase {

    func testCaptureNatalScreenScrolled() throws {
        let app = XCUIApplication()
        app.launch()

        let dir = FileManager.default.temporaryDirectory
        print("SHOTDIR=\(dir.path)")

        func snap(_ name: String) {
            let img = XCUIScreen.main.screenshot()
            let url = dir.appendingPathComponent("w08-\(name).png")
            try? img.pngRepresentation.write(to: url)
            print("SHOT=\(url.path)")
        }

        XCTAssertTrue(app.staticTexts["Bản đồ sao"].waitForExistence(timeout: 10),
                      "Không thấy tiêu đề màn hình")
        snap("01-dau")

        let list = app.tables.firstMatch.exists ? app.tables.firstMatch : app.collectionViews.firstMatch
        for i in 2...5 {
            list.swipeUp(velocity: .fast)
            snap(String(format: "%02d-cuon", i))
        }
    }
}
