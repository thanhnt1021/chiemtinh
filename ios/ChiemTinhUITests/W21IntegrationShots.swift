//  W21IntegrationShots.swift
//  Đi hết 5 tab sau khi W21 nối app, chụp từng màn. Bấm bằng API BÊN TRONG simulator
//  (XCUITest) — KHÔNG đụng chuột thật, không cần cửa sổ Simulator nổi lên.

import XCTest

final class W21IntegrationShots: XCTestCase {

    private var dir: URL { FileManager.default.temporaryDirectory }

    private func snap(_ name: String) {
        let img = XCUIScreen.main.screenshot()
        let url = dir.appendingPathComponent("w21-\(name).png")
        try? img.pngRepresentation.write(to: url)
        print("SHOT=\(url.path)")
    }

    func testWalkAllTabs() throws {
        let app = XCUIApplication()
        app.launch()
        print("SHOTDIR=\(dir.path)")

        let tabs = app.tabBars.firstMatch
        XCTAssertTrue(tabs.waitForExistence(timeout: 20), "Không thấy TabBar")

        // 1 — Dashboard (tab Lá số)
        _ = app.staticTexts["Chiêm Tinh"].waitForExistence(timeout: 10)
        snap("01-dashboard")

        // 2 — Lá số: vào màn bản đồ sao qua ô "Bản đồ sao"
        let tile = app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "Bản đồ sao")).firstMatch
        if tile.waitForExistence(timeout: 5) {
            tile.tap()
            sleep(3)
            snap("02-lasodang-bang")
            // cuộn xuống tới khối "Bản đồ sao" (bánh xe)
            let sc = app.collectionViews.firstMatch.exists ? app.collectionViews.firstMatch : app.tables.firstMatch
            sc.swipeUp(velocity: .slow)
            sleep(1)
            snap("03-banh-xe")
            sc.swipeUp(velocity: .slow)
            sleep(1)
            snap("04-banh-xe-duoi")

            // mở toàn màn hình (ChartHubView) — cuộn tìm tới khi thấy nút
            let full = app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "toàn màn hình")).firstMatch
            var tries = 0
            while !full.exists && tries < 6 { sc.swipeDown(velocity: .slow); tries += 1; sleep(1) }
            if full.exists {
                full.tap(); sleep(3)
                snap("05-chart-hub-banh-xe")
                let seg = app.segmentedControls.firstMatch
                if seg.exists && seg.buttons.count > 1 {
                    seg.buttons.element(boundBy: 1).tap(); sleep(2)
                    snap("06-aspect-grid")
                }
                app.navigationBars.buttons.element(boundBy: 0).tap(); sleep(1)
            }
        }

        // 3 — Hợp đôi
        tabs.buttons["Hợp đôi"].tap(); sleep(3)
        snap("07-hop-doi")

        // 4 — Vận hạn: menu rồi vào "Vận Hạn Chung"
        tabs.buttons["Vận hạn"].tap(); sleep(3)
        snap("08-van-han-menu")
        let chung = app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "Vận Hạn Chung")).firstMatch
        if chung.waitForExistence(timeout: 5) {
            chung.tap(); sleep(2)
            let run = app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "Check Current Planets")).firstMatch
            if run.waitForExistence(timeout: 5) { run.tap() }
            sleep(8)
            snap("09-van-han-chi-tiet")
            app.scrollViews.firstMatch.swipeUp(velocity: .slow); sleep(1)
            snap("10-van-han-banh-xe")
        }

        // 5 — Tra cứu
        tabs.buttons["Tra cứu"].tap(); sleep(3)
        snap("11-tra-cuu")
        let firstItem = app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "12 cung")).firstMatch
        if firstItem.waitForExistence(timeout: 5) {
            firstItem.tap(); sleep(3)
            snap("12-tra-cuu-chi-tiet")
        }

        // 6 — Hồ sơ
        tabs.buttons["Hồ sơ"].tap(); sleep(3)
        snap("13-ho-so")
    }

    /// Tạo 1 hồ sơ rồi vào Vận Hạn Riêng để chụp BÁNH XE CÓ VÒNG NGOÀI TRANSIT.
    func testTransitOuterRing() throws {
        let app = XCUIApplication()
        app.launch()
        print("SHOTDIR=\(dir.path)")

        let tabs = app.tabBars.firstMatch
        XCTAssertTrue(tabs.waitForExistence(timeout: 20))
        tabs.buttons["Hồ sơ"].tap(); sleep(2)

        let add = app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "Thêm hồ sơ")).firstMatch
        if add.waitForExistence(timeout: 5) {
            add.tap(); sleep(2)
            let field = app.textFields.firstMatch
            if field.waitForExistence(timeout: 5) {
                field.tap(); field.typeText("Mau W21")
            }
            snap("14-form-ho-so")
            let save = app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "Lưu hồ sơ")).firstMatch
            if save.exists { save.tap(); sleep(2) }
            snap("15-ho-so-da-luu")
        }

        // Vận hạn -> Vận Hạn Riêng
        tabs.buttons["Vận hạn"].tap(); sleep(2)
        let rieng = app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "Vận Hạn Riêng")).firstMatch
        if rieng.waitForExistence(timeout: 5) {
            rieng.tap(); sleep(3)
            snap("16-van-han-rieng-form")
            let run = app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "XEM")).firstMatch
            if run.waitForExistence(timeout: 5) { run.tap() }
            sleep(12)
            snap("17-van-han-rieng-ket-qua")
            app.scrollViews.firstMatch.swipeUp(velocity: .slow); sleep(2)
            snap("18-banh-xe-vong-transit")
        }
    }
}
