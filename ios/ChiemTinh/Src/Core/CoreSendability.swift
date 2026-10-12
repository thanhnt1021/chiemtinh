//  CoreSendability.swift
//  KHAI `Sendable` CHO CÁC KIỂU GIÁ TRỊ CỦA `Src/Core/`.
//
//  VÌ SAO CẦN: `TransitEngine` (`Src/Transit/TransitEngine.swift`) là `actor`; trả kiểu
//  của Core qua biên actor thì Swift đòi kiểu đó phải `Sendable`. Swift KHÔNG tự suy ra
//  `Sendable` cho `struct` `public`, nên trình dịch cảnh báo
//  ("this is an error in the Swift 6 language mode").
//
//  W21 (gộp app): W20 phải đặt tạm khai báo này ở `Src/Transit/CoreSendability.swift`
//  vì bị cấm ghi vào `Src/Core/`. Nay chuyển hẳn về đúng chỗ — cạnh nơi khai báo kiểu —
//  để không bao giờ có 2 nơi cùng khai (duplicate conformance). File cũ đã xoá.
//
//  Mọi kiểu dưới đây chỉ chứa `Int`/`Double`/`String`/`Array`/`Dictionary` bất biến
//  ⇒ khai `Sendable` là ĐÚNG. KHÔNG đụng tới thuật toán của Core.
//
//  Nơi khai báo kiểu:
//    · CivilDateTime                                   -> Src/Core/CivilDateTime.swift:11
//    · PlanetPosition / ChartTechnicalInfo / ChartMeta  -> Src/Core/AstroCore.swift:41,50,58
//    · Chart / AspectHit / TimeStamp                    -> Src/Core/AstroCore.swift:65,77,86
//    · AspectPeriod / ReturnPeriod                      -> Src/Core/AstroCore.swift:91,97
//    · HouseTransitPeriod / HouseInterval               -> Src/Core/AstroCore.swift:104,110

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
