//  main.swift — CLI đối chiếu (chạy trên macOS) dùng CHÍNH các file Swift của app.
//  Mục đích: lặp nhanh khi dò lệch số. Bằng chứng nghiệm thu CHÍNH THỨC là XCTest
//  chạy trên iOS Simulator (target ChiemTinhTests) — file này chỉ là bản chạy nhanh.
//  Dùng: swift_harness <ephe_dir> <cases.json> <out.json>

import Foundation

let args = CommandLine.arguments
guard args.count >= 4 else {
    FileHandle.standardError.write("Dùng: \(args[0]) <ephe_dir> <cases.json> <out.json>\n".data(using: .utf8)!)
    exit(2)
}
SwissEph.setEphePath(args[1])
guard let data = FileManager.default.contents(atPath: args[2]) else {
    FileHandle.standardError.write("Không đọc được \(args[2])\n".data(using: .utf8)!)
    exit(2)
}
let cases = ChartDump.loadCases(from: data)
let json = ChartDump.runAll(cases: cases)
try! json.data(using: .utf8)!.write(to: URL(fileURLWithPath: args[3]))
FileHandle.standardError.write("libswe \(SwissEph.version()) — \(cases.count) ca -> \(args[3])\n".data(using: .utf8)!)
