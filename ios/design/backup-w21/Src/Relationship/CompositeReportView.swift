//  CompositeReportView.swift
//  Khối "Phân Tích Chi Tiết Composite" (`app/templates/composite.html`),
//  web chạy `generate_natal_report` trên dữ liệu composite (`app/routes/charts.py:170-171`).
//  Đủ 8 khối như báo cáo natal của web (`app/utils/reports/natal.py:7-115`):
//    Show Time · VỊ TRÍ HÀNH TINH · LÕI · BẢNG NGUYÊN TỐ–TÍNH CHẤT ·
//    NHÀ TRỘI CÁ NHÂN · Bảng góc hợp · HÀNH TINH TẠO NHIỀU GÓC NHẤT · GÓC INNER CHẶT NHẤT
//  Số liệu do `RelReports.natalReport` tính (port 1-1); bảng góc hợp lấy mô hình
//  `NatalAspectGridModel` của W18 (`Src/Chart/AspectGridModel.swift`).

import SwiftUI

public struct CompositeReportView: View {
    public let chart: Chart
    public let report: RelReports.NatalReport
    public let showRealOrb: Bool

    public init(chart: Chart, report: RelReports.NatalReport, showRealOrb: Bool) {
        self.chart = chart; self.report = report; self.showRealOrb = showRealOrb
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.xl) {
            infoBlock
            planetsBlock
            coreBlock
            elementsBlock
            dominantHousesBlock
            aspectGridBlock
            dominantPlanetsBlock
            innerAspectsBlock
        }
    }

    // MARK: Show Time — components.py:96-128

    private var infoBlock: some View {
        AstroCard {
            VStack(alignment: .leading, spacing: 3) {
                SectionHeader("Thông tin chi tiết (Show Time)", style: .caps) { EmptyView() }
                line("Ngày sinh (giờ địa phương)", report.info.dateOfBirthLocal)
                line("Giờ quốc tế (UT/GMT)", report.info.universalTime)
                line("Giờ sao (LST)", report.info.localSiderealTime)
                line("Hệ nhà", report.info.houseSystem)
                line("Vĩ độ, Kinh độ", report.info.latLon)
                line("Thành phố", report.info.city)
                line("Quốc gia", report.info.country)
            }
        }
    }

    private func line(_ l: String, _ v: String) -> some View {
        HStack(alignment: .top) {
            Text(l).font(Theme.Fonts.caps).foregroundStyle(Theme.Colors.textMuted)
            Spacer(minLength: Theme.Space.sm)
            Text(v).font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.textSecondary)
                .multilineTextAlignment(.trailing)
        }
    }

    // MARK: VỊ TRÍ HÀNH TINH — natal.py:14-36

    private var planetsBlock: some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            SectionHeader("Vị trí hành tinh") { EmptyView() }
            VStack(spacing: 0) {
                planetHeaderRow
                ForEach(report.planetRows) { r in planetRow(r) }
            }
            .background(Theme.Colors.bgSurface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                .stroke(Theme.Colors.border, lineWidth: 1))
        }
    }

    private var planetHeaderRow: some View {
        HStack(spacing: 0) {
            Text("HÀNH TINH").font(Theme.Fonts.caps).foregroundStyle(Theme.Colors.textMuted)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("CUNG").font(Theme.Fonts.caps).foregroundStyle(Theme.Colors.textMuted).frame(width: 48)
            Text("ĐỘ").font(Theme.Fonts.caps).foregroundStyle(Theme.Colors.textMuted).frame(width: 64)
            Text("NHÀ").font(Theme.Fonts.caps).foregroundStyle(Theme.Colors.textMuted).frame(width: 44)
        }
        .padding(.vertical, 6).padding(.horizontal, Theme.Space.md)
        .background(Theme.Colors.bgChip)
    }

    private func planetRow(_ r: RelReports.PlanetRow) -> some View {
        HStack(spacing: 0) {
            HStack(spacing: 6) {
                AstroGlyph(planet: r.planet, size: 15, tint: Theme.Colors.accent)
                Text(r.planet).font(Theme.Fonts.callout).foregroundStyle(Theme.Colors.textPrimary)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(r.zodiacSymbol).font(Theme.Fonts.glyph(size: 15))
                .foregroundStyle(Theme.Colors.textSecondary).frame(width: 48)
            Text(r.degreeText).font(Theme.Fonts.numericSmall)
                .foregroundStyle(Theme.Colors.textSecondary).frame(width: 64)
            Text("\(r.house)").font(Theme.Fonts.numeric)
                .foregroundStyle(Theme.Colors.textPrimary).frame(width: 44)
        }
        .padding(.vertical, 5).padding(.horizontal, Theme.Space.md)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.Colors.separator).frame(height: 0.5) }
    }

    // MARK: LÕI — natal.py:39-56

    private var coreBlock: some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            SectionHeader("Lõi") { EmptyView() }
            AstroCard(level: .raised) {
                VStack(spacing: 4) {
                    coreLine("AC", report.core.ascSign)
                    coreLine("Sun", report.core.sunSign)
                    coreLine("Moon", report.core.moonSign)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func coreLine(_ k: String, _ v: String) -> some View {
        HStack(spacing: Theme.Space.sm) {
            Text(k).font(Theme.Fonts.caps).foregroundStyle(Theme.Colors.accent).frame(width: 44, alignment: .trailing)
            Text(v).font(Theme.Fonts.body).foregroundStyle(Theme.Colors.textPrimary)
        }
    }

    // MARK: BẢNG NGUYÊN TỐ – TÍNH CHẤT — components.py:4-93

    private var elementsBlock: some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            SectionHeader("Bảng nguyên tố – tính chất") { EmptyView() }
            ScrollView(.horizontal, showsIndicators: true) {
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        elemCell("", w: 76, header: true, tint: nil)
                        ForEach(RelReports.ElementMatrix.colNames, id: \.self) {
                            elemCell($0, w: 84, header: true, tint: nil)
                        }
                        elemCell("Total", w: 60, header: true, tint: nil)
                    }
                    ForEach(0..<4, id: \.self) { r in
                        HStack(spacing: 0) {
                            elemCell(RelReports.ElementMatrix.rowNames[r], w: 76, header: true,
                                     tint: Theme.Colors.element(r))
                            ForEach(0..<3, id: \.self) { c in
                                elemSymbolCell(report.elements.symbols[r][c], tint: Theme.Colors.element(r))
                            }
                            elemCell("\(report.elements.rowTotals[r])", w: 60, header: false,
                                     tint: Theme.Colors.element(r))
                        }
                    }
                    HStack(spacing: 0) {
                        elemCell("Total", w: 76, header: true, tint: nil)
                        ForEach(0..<3, id: \.self) { c in
                            elemCell("\(report.elements.colTotals[c])", w: 84, header: false, tint: nil)
                        }
                        elemCell("", w: 60, header: true, tint: nil)
                    }
                }
            }
            .background(Theme.Colors.bgSunken)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                .stroke(Theme.Colors.border, lineWidth: 1))
        }
    }

    private func elemCell(_ s: String, w: CGFloat, header: Bool, tint: Color?) -> some View {
        Text(s)
            .font(header ? Theme.Fonts.caps : Theme.Fonts.numeric)
            .foregroundStyle(tint ?? (header ? Theme.Colors.textMuted : Theme.Colors.textPrimary))
            .frame(width: w, height: 44)
            .background(header ? Theme.Colors.bgChip : Theme.Colors.bgSurface)
            .overlay(Rectangle().stroke(Theme.Colors.separator, lineWidth: 0.5))
    }

    private func elemSymbolCell(_ syms: [String], tint: Color) -> some View {
        Text(syms.joined(separator: " "))
            .font(Theme.Fonts.glyph(size: 14))
            .foregroundStyle(tint)
            .lineLimit(2).minimumScaleFactor(0.6)
            .frame(width: 84, height: 44)
            .background(Theme.Colors.bgSurface)
            .overlay(Rectangle().stroke(Theme.Colors.separator, lineWidth: 0.5))
    }

    // MARK: NHÀ TRỘI CÁ NHÂN — natal.py:60-62

    private var dominantHousesBlock: some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            SectionHeader("Nhà trội") { EmptyView() }
            AstroCard {
                Text(report.dominantHouses.isEmpty ? "Không có"
                     : report.dominantHouses.map { "H\($0.house)" }.joined(separator: ", "))
                    .font(Theme.Fonts.title2)
                    .foregroundStyle(Theme.Colors.accent)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }

    // MARK: Bảng góc hợp — natal.py:65-67 (mô hình của W18)

    private var aspectGridBlock: some View {
        let model = NatalAspectGridModel(chart: chart)
        return VStack(alignment: .leading, spacing: Theme.Space.sm) {
            SectionHeader("Bảng góc hợp của bản đồ sao",
                          subtitle: "Vuốt ngang để xem hết") { EmptyView() }
            ScrollView(.horizontal, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(model.rows.enumerated()), id: \.offset) { _, row in
                        HStack(spacing: 0) {
                            ForEach(Array(row.enumerated()), id: \.offset) { _, slot in
                                natalSlot(slot).frame(width: 40, height: 40)
                            }
                        }
                    }
                }
                .padding(4)
            }
            .background(Theme.Colors.bgSunken)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                .stroke(Theme.Colors.border, lineWidth: 1))
        }
    }

    @ViewBuilder private func natalSlot(_ slot: GridSlot) -> some View {
        switch slot {
        case .empty:
            Rectangle().fill(Theme.Colors.bgSunken)
                .overlay(Rectangle().stroke(Theme.Colors.separator, lineWidth: 0.5))
        case .header(let name, _):
            AstroGlyph(planet: name, size: 15, tint: Theme.Colors.textPrimary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.Colors.bgChip)
                .overlay(Rectangle().stroke(Theme.Colors.separator, lineWidth: 0.5))
        case .aspect(let a):
            ZStack {
                Rectangle().fill(Theme.Colors.bgSurface)
                AstroGlyph(aspect: a.aspect, size: 15, tint: RelAspectColor.color(a))
                // grid.py:347 — số orb làm tròn ở góc trên-phải.
                VStack { HStack { Spacer(); Text("\(a.orbRounded)")
                    .font(.system(size: 7)).foregroundStyle(Theme.Colors.textMuted) }; Spacer() }
                    .padding(2)
                if showRealOrb {
                    VStack { Spacer(); HStack { Text(a.orbText)
                        .font(.system(size: 7)).foregroundStyle(Theme.Colors.textMuted); Spacer() } }
                        .padding(2)
                }
            }
            .overlay(Rectangle().stroke(Theme.Colors.separator, lineWidth: 0.5))
        }
    }

    // MARK: HÀNH TINH TẠO NHIỀU GÓC NHẤT — natal.py:70-84

    private var dominantPlanetsBlock: some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            SectionHeader("Hành tinh tạo nhiều góc nhất") { EmptyView() }
            AstroCard(level: .raised) {
                if report.dominantPlanets.isEmpty {
                    Text("Không xác định.").font(Theme.Fonts.callout)
                        .foregroundStyle(Theme.Colors.textMuted)
                        .frame(maxWidth: .infinity, alignment: .center)
                } else {
                    VStack(spacing: 6) {
                        ForEach(report.dominantPlanets) { d in
                            HStack(spacing: Theme.Space.sm) {
                                AstroGlyph(planet: d.name, size: 20, tint: Theme.Colors.accent)
                                Text(d.name.uppercased())
                                    .font(Theme.Fonts.headline)
                                    .foregroundStyle(Theme.Colors.textPrimary)
                                Spacer()
                                Chip("\(d.count) góc", tone: .accent)
                                Chip("Σorb \(d.totalOrb)", tone: .neutral)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: GÓC INNER CHẶT NHẤT — natal.py:86-114

    private var innerAspectsBlock: some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            SectionHeader("Góc Inner chặt nhất") { EmptyView() }
            AstroCard {
                if report.tightestInnerAspects.isEmpty {
                    Text("Không có góc Inner nào.").font(Theme.Fonts.callout)
                        .foregroundStyle(Theme.Colors.textMuted)
                        .frame(maxWidth: .infinity, alignment: .center)
                } else {
                    VStack(spacing: 0) {
                        ForEach(report.tightestInnerAspects) { a in
                            HStack(spacing: 6) {
                                AstroGlyph(planet: a.p1, size: 16, tint: Theme.Colors.accent)
                                Text(a.p1).font(Theme.Fonts.callout)
                                Text("–").foregroundStyle(Theme.Colors.textMuted)
                                AstroGlyph(planet: a.p2, size: 16, tint: Theme.Colors.accent)
                                Text(a.p2).font(Theme.Fonts.callout)
                                Spacer()
                                Chip("\(a.nameVN) \(a.orbRound)°", tone: .success)
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
}
