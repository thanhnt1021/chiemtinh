//  SynastryReportView.swift
//  Khối "PHÂN TÍCH CHI TIẾT" (`app/templates/synastry.html:104-107`) —
//  render đủ 5 mục của `app/utils/reports/synastry.py:31-126`, cộng khối
//  "Xem thông tin chi tiết (Show Time)" 2 cột ở đầu (`synastry.py:29`).
//  Số liệu do `RelReports.synastryReport` tính (port 1-1), view chỉ trình bày.

import SwiftUI

public struct SynastryReportView: View {
    public let report: RelReports.SynastryReport
    public let nameA: String
    public let nameB: String

    public init(report: RelReports.SynastryReport, nameA: String, nameB: String) {
        self.report = report; self.nameA = nameA; self.nameB = nameB
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.xl) {
            infoBlock
            section1
            section2
            section3
            section4
            section5
        }
    }

    // MARK: - Khối đầu: Show Time 2 cột — synastry.py:29

    private var infoBlock: some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            SectionHeader("Thông tin chi tiết (Show Time)", style: .caps) { EmptyView() }
            HStack(alignment: .top, spacing: Theme.Space.md) {
                infoColumn(nameA, report.infoA, Theme.Colors.aspectSoft)
                infoColumn(nameB, report.infoB, Theme.Colors.aspectHard)
            }
        }
    }

    private func infoColumn(_ name: String, _ i: RelReports.ShowTimeInfo, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(name).font(Theme.Fonts.headline).foregroundStyle(tint).lineLimit(1)
            infoLine("Ngày sinh (giờ địa phương)", i.dateOfBirthLocal)
            infoLine("Giờ quốc tế (UT/GMT)", i.universalTime)
            infoLine("Giờ sao (LST)", i.localSiderealTime)
            infoLine("Hệ nhà", i.houseSystem)
            infoLine("Vĩ độ, Kinh độ", i.latLon)
            infoLine("Thành phố", i.city)
            infoLine("Quốc gia", i.country)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func infoLine(_ l: String, _ v: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(l).font(Theme.Fonts.caps).foregroundStyle(Theme.Colors.textMuted)
            Text(v).font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.textSecondary)
        }
    }

    // MARK: - 1. LÕI VÀ NHÀ TRỘI CÁ NHÂN — synastry.py:31-32

    private var section1: some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            SectionHeader("1. Lõi và nhà trội cá nhân") { EmptyView() }
            HStack(alignment: .top, spacing: Theme.Space.md) {
                coreCard(nameA, report.coreA, report.dominantHousesA, Theme.Colors.aspectSoft)
                coreCard(nameB, report.coreB, report.dominantHousesB, Theme.Colors.aspectHard)
            }
        }
    }

    private func coreCard(_ name: String, _ c: RelReports.CoreSigns,
                          _ dom: [RelReports.HouseScore], _ tint: Color) -> some View {
        AstroCard {
            VStack(alignment: .leading, spacing: 4) {
                Text(name).font(Theme.Fonts.headline).foregroundStyle(tint).lineLimit(1)
                coreLine("AC", c.ascSign)
                coreLine("Sun", c.sunSign)
                coreLine("Moon", c.moonSign)
                Divider().overlay(Theme.Colors.separator)
                Text("Nhà trội").font(Theme.Fonts.caps).foregroundStyle(Theme.Colors.textMuted)
                Text(dom.isEmpty ? "Không có" : dom.map { "H\($0.house)" }.joined(separator: ", "))
                    .font(Theme.Fonts.numeric)
                    .foregroundStyle(Theme.Colors.accent)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func coreLine(_ k: String, _ v: String) -> some View {
        HStack(spacing: 6) {
            Text(k).font(Theme.Fonts.caps).foregroundStyle(Theme.Colors.textMuted).frame(width: 34, alignment: .leading)
            Text(v).font(Theme.Fonts.callout).foregroundStyle(Theme.Colors.textPrimary)
        }
    }

    // MARK: - 2. BẢNG TƯƠNG TÁC NHÀ — synastry.py:35-81

    private var section2: some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            SectionHeader("2. Bảng tương tác nhà",
                          subtitle: "Hành tinh của người này rơi vào nhà nào của người kia") { EmptyView() }
            ScrollView(.horizontal, showsIndicators: true) {
                VStack(spacing: 0) {
                    rowLine("HÀNH TINH", "ĐIỂM", "KÍCH HOẠT NHÀ CỦA \(nameA)", "KÍCH HOẠT NHÀ CỦA \(nameB)",
                            isHeader: true, symbol: nil)
                    ForEach(report.rows) { r in
                        rowLine(r.planet, "\(r.points)", "H\(r.houseInA)", "H\(r.houseInB)",
                                isHeader: false, symbol: r.planet)
                    }
                }
            }
            .background(Theme.Colors.bgSunken)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
        }
    }

    private func rowLine(_ c0: String, _ c1: String, _ c2: String, _ c3: String,
                         isHeader: Bool, symbol: String?) -> some View {
        HStack(spacing: 0) {
            HStack(spacing: 4) {
                if let s = symbol { AstroGlyph(planet: s, size: 13, tint: Theme.Colors.accent) }
                Text(c0).font(isHeader ? Theme.Fonts.caps : Theme.Fonts.callout)
                    .foregroundStyle(isHeader ? Theme.Colors.textMuted : Theme.Colors.textPrimary)
                Spacer(minLength: 0)
            }
            .frame(width: 128, alignment: .leading)
            cellText(c1, isHeader: isHeader, width: 52)
            cellText(c2, isHeader: isHeader, width: 150)
            cellText(c3, isHeader: isHeader, width: 150)
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 8)
        .background(isHeader ? Theme.Colors.bgChip : Color.clear)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.Colors.separator).frame(height: 0.5)
        }
    }

    private func cellText(_ s: String, isHeader: Bool, width: CGFloat) -> some View {
        Text(s)
            .font(isHeader ? Theme.Fonts.caps : Theme.Fonts.numeric)
            .foregroundStyle(isHeader ? Theme.Colors.textMuted : Theme.Colors.textPrimary)
            .multilineTextAlignment(.center)
            .frame(width: width)
    }

    // MARK: - 3. NHÀ ĐƯỢC KÍCH HOẠT NHIỀU — synastry.py:84-94

    private var section3: some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            SectionHeader("3. Nhà được kích hoạt nhiều") { EmptyView() }
            HStack(alignment: .top, spacing: Theme.Space.md) {
                activatedCard("\(nameA) được kích hoạt", report.activatedHousesOfA, Theme.Colors.aspectSoft)
                activatedCard("\(nameB) được kích hoạt", report.activatedHousesOfB, Theme.Colors.aspectHard)
            }
        }
    }

    private func activatedCard(_ title: String, _ list: [RelReports.HouseScore], _ tint: Color) -> some View {
        AstroCard {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(Theme.Fonts.caps).foregroundStyle(tint).lineLimit(2)
                if list.isEmpty {
                    Text("Không").font(Theme.Fonts.callout).foregroundStyle(Theme.Colors.textMuted)
                } else {
                    ForEach(list) { h in
                        HStack {
                            Text("H\(h.house)").font(Theme.Fonts.numeric)
                            Spacer()
                            Text("\(h.score)đ").font(Theme.Fonts.numericSmall)
                                .foregroundStyle(Theme.Colors.textSecondary)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - 4. NHÀ TRỘI CỦA MỐI QUAN HỆ — synastry.py:97-119

    private var section4: some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            SectionHeader("4. Nhà trội của mối quan hệ",
                          subtitle: "Xếp hạng cao → thấp") { EmptyView() }
            AstroCard(level: .raised) {
                if report.relationshipHouses.isEmpty {
                    Text("Không có nhà nào ≥ 4 điểm.")
                        .font(Theme.Fonts.callout)
                        .foregroundStyle(Theme.Colors.textMuted)
                        .frame(maxWidth: .infinity, alignment: .center)
                } else {
                    VStack(spacing: 0) {
                        ForEach(report.relationshipHouses) { h in
                            HStack {
                                Text("H\(h.house)").font(Theme.Fonts.body)
                                Spacer()
                                Text("\(h.score)đ").font(Theme.Fonts.numeric)
                                    .foregroundStyle(Theme.Colors.accent)
                            }
                            .padding(.vertical, 5)
                            .overlay(alignment: .bottom) {
                                Rectangle().fill(Theme.Colors.separator).frame(height: 0.5)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - 5. NHÀ TRỐNG — synastry.py:122-126

    private var section5: some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            SectionHeader("5. Nhà trống") { EmptyView() }
            AstroCard {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .top) {
                        Text("Tất cả nhà trống").font(Theme.Fonts.caps)
                            .foregroundStyle(Theme.Colors.textMuted)
                        Spacer()
                        Text(report.emptyHouses.isEmpty ? "Không có"
                             : report.emptyHouses.map { "H\($0)" }.joined(separator: ", "))
                            .font(Theme.Fonts.numeric)
                            .foregroundStyle(Theme.Colors.textPrimary)
                    }
                    HStack(alignment: .top) {
                        Text("Nhà trống cần chú ý").font(Theme.Fonts.caps)
                            .foregroundStyle(Theme.Colors.textMuted)
                        Spacer()
                        Text(report.specialEmptyHouses.isEmpty ? "Không có"
                             : report.specialEmptyHouses.map { "H\($0)" }.joined(separator: ", "))
                            .font(Theme.Fonts.numeric)
                            .foregroundStyle(Theme.Colors.danger)
                    }
                }
            }
        }
    }
}
