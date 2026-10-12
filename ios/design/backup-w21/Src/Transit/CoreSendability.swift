//  CoreSendability.swift
//  ⚠️ FILE TẠM — CHỖ KHAI `Sendable` CHO CÁC KIỂU CỦA `Src/Core/`.
//
//  VÌ SAO CẦN: `TransitEngine` là `actor`; trả kiểu của Core qua biên actor thì Swift
//  đòi kiểu đó phải `Sendable`. Swift KHÔNG tự suy ra `Sendable` cho `struct` `public`,
//  nên trình dịch cảnh báo ("this is an error in the Swift 6 language mode").
//
//  VÌ SAO KHÔNG SỬA THẲNG `Src/Core/`: worker W20 bị CẤM ghi vào `Src/Core/`.
//  Mọi kiểu dưới đây chỉ chứa `Int`/`Double`/`String`/`Array`/`Dictionary` bất biến
//  ⇒ khai `Sendable` là ĐÚNG, không phải né tránh.
//
//  👉 KHI GỘP MÃ: nếu worker khác cũng khai mấy dòng này thì sẽ báo "duplicate
//     conformance" — lúc đó hãy CHUYỂN HẲN các khai báo này vào chính `Src/Core/`
//     và xoá file này.

import Foundation

extension CivilDateTime: @unchecked Sendable {}
extension PlanetPosition: @unchecked Sendable {}
extension ChartTechnicalInfo: @unchecked Sendable {}
extension ChartMeta: @unchecked Sendable {}
extension Chart: @unchecked Sendable {}
extension AspectHit: @unchecked Sendable {}
extension TimeStamp: @unchecked Sendable {}
extension AspectPeriod: @unchecked Sendable {}
extension ReturnPeriod: @unchecked Sendable {}
extension HouseTransitPeriod: @unchecked Sendable {}
extension HouseInterval: @unchecked Sendable {}
