//  ParityTests.swift
//  BẰNG CHỨNG NGHIỆM THU: chạy 12 ca kiểm NGAY TRÊN iOS Simulator (arm64-ios),
//  in JSON ra stdout giữa hai mốc để harness ngoài bóc ra so với JSON của Python.

import XCTest
@testable import ChiemTinh

final class ParityTests: XCTestCase {

    /// Trỏ Swiss Ephemeris vào 3 file .se1 nằm trong bundle CỦA APP (không phải bundle test).
    private func setUpEphePath() -> String {
        // Test chạy cùng process với app host → Bundle.main chính là bundle app.
        let appBundle = Bundle(for: ParityTests.self).bundleURL
            .deletingLastPathComponent()   // .../Debug-iphonesimulator/ChiemTinh.app/PlugIns -> ...
        var path = Bundle.main.resourcePath ?? appBundle.path
        if !FileManager.default.fileExists(atPath: path + "/sepl_18.se1") {
            // Dự phòng: tìm trong bundle của app target
            if let p = Bundle(identifier: "fun.jst4.chiemtinh")?.resourcePath { path = p }
        }
        SwissEph.setEphePath(path)
        return path
    }

    func testEphemerisFilesArePresent() throws {
        let path = setUpEphePath()
        for f in ["seas_18.se1", "semo_18.se1", "sepl_18.se1"] {
            XCTAssertTrue(FileManager.default.fileExists(atPath: path + "/" + f),
                          "Thiếu file ephemeris \(f) trong bundle: \(path)")
        }
        print("EPHE_PATH=\(path)")
    }

    /// Kiểm nhanh: Mặt Trời tại 15/05/1990 07:30 UT (Bước 2 của đề bài).
    func testSunLongitudeSmoke() throws {
        _ = setUpEphePath()
        let jd = SwissEph.julday(1990, 5, 15, 7.5)
        let res = SwissEph.calcUT(jd, SwePlanet.sun, SweFlag.swieph | SweFlag.speed)
        print("SMOKE libswe=\(SwissEph.version()) jd=\(jd) sun_lon=\(res.lon) retflag=\(res.retFlag) err=\(res.error ?? "-")")
        XCTAssertGreaterThanOrEqual(res.retFlag, 0, "swe_calc_ut lỗi: \(res.error ?? "?")")
        // Giá trị tham chiếu do pyswisseph 2.10.03 in ra trên cùng ephe: 54.21531085470255
        XCTAssertEqual(res.lon, 54.21531085470255, accuracy: 1e-9)
    }

    /// Xuất JSON toàn bộ ca kiểm để so với `dump_python.py`.
    func testDumpAllCasesAsJSON() throws {
        let ephe = setUpEphePath()
        guard let url = Bundle(for: ParityTests.self).url(forResource: "cases", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            return XCTFail("Không tìm thấy cases.json trong bundle test")
        }
        let cases = ChartDump.loadCases(from: data)
        XCTAssertGreaterThanOrEqual(cases.count, 5, "Đề bài yêu cầu tối thiểu 5 bộ input")
        let json = ChartDump.runAll(cases: cases)
        print("EPHE_PATH=\(ephe)")
        print("<<<CHIEMTINH_SWIFT_JSON_BEGIN>>>")
        // In theo từng khúc 4000 ký tự để tránh bị cắt dòng quá dài trong log xcodebuild
        var idx = json.startIndex
        while idx < json.endIndex {
            let end = json.index(idx, offsetBy: 4000, limitedBy: json.endIndex) ?? json.endIndex
            print("§" + String(json[idx..<end]))
            idx = end
        }
        print("<<<CHIEMTINH_SWIFT_JSON_END>>>")
    }
}
