//  AspectGridView.swift
//  BẢNG GÓC CHIẾU dạng tam giác (natal) và chữ nhật (synastry).
//  Port bố cục + quy tắc hiển thị từ `app/utils/drawing/grid.py`.
//  Các ký hiệu ⚹ ⚺ ⚻ □ △ được VẼ TAY y như web (`grid.py:12-46`, `grid.py:88-102`)
//  vì nhiều font không có glyph, hoặc có nhưng lệch tâm ô.

import SwiftUI

public enum GridGlyph {
    /// Vẽ ký hiệu 1 góc chiếu vào tâm ô — dùng bộ glyph của W17
    /// (`Src/Design/Glyphs.swift`: SextileGlyph / SemisextileGlyph / QuincunxGlyph),
    /// □ và △ nằm sẵn trong font hệ thống nên vẽ bằng chữ.
    public static func draw(_ ctx: inout GraphicsContext, cell: GridAspectCell,
                            center: CGPoint, size: CGFloat, color: Color) {
        ChartGlyphDraw.draw(&ctx, symbol: cell.symbol, center: center,
                            size: size * 0.62, color: color)
    }
}

// MARK: - Bảng natal (tam giác)

public struct NatalAspectGridView: View {
    @Environment(\.colorScheme) private var scheme
    @State private var zoom: CGFloat = 1
    @GestureState private var pinch: CGFloat = 1
    @State private var picked: GridAspectCell? = nil

    public let model: NatalAspectGridModel
    public let title: String
    public init(model: NatalAspectGridModel, title: String = "Bảng góc chiếu") {
        self.model = model; self.title = title
    }

    private let baseCell: CGFloat = 40
    /// grid.py:257 — 2 cột header + khe 0.5 ô.
    private let leftCols: CGFloat = 2.5

    public var body: some View {
        let palette = ChartPalette(scheme)
        let cell = baseCell * min(max(zoom * pinch, 0.6), 2.4)
        let n = CGFloat(model.objects.count)
        let w = (n + leftCols) * cell
        let h = n * cell

        ZStack(alignment: .bottom) {
            LinearGradient(colors: [palette.backgroundTop, palette.backgroundBottom],
                           startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            ScrollView([.horizontal, .vertical], showsIndicators: true) {
                Canvas(rendersAsynchronously: false) { ctx, _ in
                    draw(&ctx, cell: cell, palette: palette)
                }
                .frame(width: w, height: h)
                .contentShape(Rectangle())
                .onTapGesture { p in
                    picked = cellAt(p, cell: cell)
                }
                .padding(12)
            }
            .gesture(MagnificationGesture().updating($pinch) { v, s, _ in s = v }
                .onEnded { v in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        zoom = min(max(zoom * v, 0.6), 2.4)
                    }
                })

            if let c = picked {
                gridDetail(c, palette: palette)
                    .padding(.horizontal, 12).padding(.bottom, 12)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func origin(row: Int, col: Int, cell: CGFloat) -> CGRect {
        CGRect(x: (CGFloat(col) + leftCols) * cell, y: CGFloat(row) * cell, width: cell, height: cell)
    }

    private func cellAt(_ p: CGPoint, cell: CGFloat) -> GridAspectCell? {
        let row = Int(p.y / cell)
        let col = Int(p.x / cell - leftCols)
        guard row >= 0, row < model.rows.count, col >= 0, col < model.rows[row].count else { return nil }
        if case .aspect(let c) = model.rows[row][col] { return c }
        return nil
    }

    private func draw(_ ctx: inout GraphicsContext, cell: CGFloat, palette: ChartPalette) {
        let gap = cell * 0.04                                     // grid.py:52-53
        func box(_ r: CGRect) -> Path {
            Path(roundedRect: r.insetBy(dx: gap, dy: gap), cornerRadius: cell * 0.14)
        }
        for (r, line) in model.rows.enumerated() {
            // Cột header trái: số lượng góc + ký hiệu hành tinh — grid.py:278-286
            let name = model.objects[r]
            let cnt = model.counts[name]
            let isTop = (cnt != nil && cnt! == model.maxCount && model.maxCount > 0)
            let c0 = CGRect(x: 0, y: CGFloat(r) * cell, width: cell, height: cell)
            let c1 = CGRect(x: cell, y: CGFloat(r) * cell, width: cell, height: cell)
            ctx.fill(box(c0), with: .color(palette.gridHeader))
            ctx.fill(box(c1), with: .color(palette.gridHeader))
            if let cnt {
                ctx.draw(Text("\(cnt)").font(.system(size: cell * 0.34, weight: isTop ? .bold : .regular))
                            .foregroundColor(isTop ? palette.aspect(.hard) : palette.glyphSecondary),
                         at: CGPoint(x: c0.midX, y: c0.midY), anchor: .center)
            }
            ctx.draw(Text(AstroConst.planetSymbols[name] ?? name)
                        .font(.system(size: cell * 0.5, weight: .bold))
                        .foregroundColor(isTop ? palette.aspect(.hard) : palette.glyph),
                     at: CGPoint(x: c1.midX, y: c1.midY), anchor: .center)

            for (c, slot) in line.enumerated() {
                let rect = origin(row: r, col: c, cell: cell)
                switch slot {
                case .empty:
                    ctx.fill(box(rect), with: .color(palette.gridEmpty))
                    ctx.stroke(box(rect), with: .color(palette.gridBorder), lineWidth: 0.5)
                case .header(let nm, let sym):
                    ctx.fill(box(rect), with: .color(palette.gridHeader))
                    ctx.stroke(box(rect), with: .color(palette.accent.opacity(0.5)), lineWidth: 1)
                    ctx.draw(Text(sym).font(.system(size: cell * 0.5, weight: .bold))
                                .foregroundColor(nm == "Asc" || nm == "MC" ? palette.strongLine : palette.glyph),
                             at: CGPoint(x: rect.midX, y: rect.midY), anchor: .center)
                case .aspect(let a):
                    let selected = (picked?.rowName == a.rowName && picked?.colName == a.colName)
                    ctx.fill(box(rect), with: .color(selected ? palette.accent.opacity(0.22) : palette.gridFilled))
                    ctx.stroke(box(rect), with: .color(selected ? palette.accent : palette.gridBorder),
                               lineWidth: selected ? 1.6 : 0.5)
                    GridGlyph.draw(&ctx, cell: a, center: CGPoint(x: rect.midX, y: rect.midY),
                                   size: cell, color: palette.aspect(a.visual))
                    // grid.py:349 — số độ lệch làm tròn, góc trên-phải
                    ctx.draw(Text("\(a.orbRounded)").font(.system(size: cell * 0.24))
                                .foregroundColor(palette.glyphSecondary),
                             at: CGPoint(x: rect.maxX - gap - cell * 0.10, y: rect.minY + gap + cell * 0.13),
                             anchor: .center)
                }
            }
        }
    }

    private func gridDetail(_ c: GridAspectCell, palette: ChartPalette) -> some View {
        HStack(spacing: 12) {
            Text(c.symbol).font(.system(size: 26, weight: .bold))
                .foregroundColor(palette.aspect(c.visual)).frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(ChartText.name(c.rowName)) \(ChartText.aspectVN[c.aspect] ?? c.aspect) \(ChartText.name(c.colName))")
                    .font(.subheadline.bold()).foregroundColor(palette.glyph)
                Text("Độ lệch \(c.orbText) · \(c.type)")
                    .font(.caption).foregroundColor(palette.glyphSecondary)
            }
            Spacer()
            Button { picked = nil } label: {
                Image(systemName: "xmark.circle.fill").font(.title2)
                    .foregroundColor(palette.glyphSecondary)
            }.frame(width: 44, height: 44)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(palette.cardBackground)
            .shadow(color: .black.opacity(0.25), radius: 10, y: 3))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .stroke(palette.accent.opacity(0.35), lineWidth: 1))
    }
}

// MARK: - Bảng synastry (chữ nhật A × B)

public struct SynastryAspectGridView: View {
    @Environment(\.colorScheme) private var scheme
    @State private var zoom: CGFloat = 1
    @GestureState private var pinch: CGFloat = 1

    public let model: SynastryAspectGridModel
    public let nameA: String
    public let nameB: String
    public init(model: SynastryAspectGridModel, nameA: String, nameB: String) {
        self.model = model; self.nameA = nameA; self.nameB = nameB
    }

    private let baseCell: CGFloat = 38

    public var body: some View {
        let palette = ChartPalette(scheme)
        let cell = baseCell * min(max(zoom * pinch, 0.6), 2.4)
        let w = CGFloat(model.colsObjects.count + 1) * cell
        let h = CGFloat(model.rowsObjects.count + 1) * cell

        ZStack {
            LinearGradient(colors: [palette.backgroundTop, palette.backgroundBottom],
                           startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            ScrollView([.horizontal, .vertical]) {
                Canvas(rendersAsynchronously: false) { ctx, _ in
                    draw(&ctx, cell: cell, palette: palette)
                }
                .frame(width: w, height: h)
                .padding(12)
            }
            .gesture(MagnificationGesture().updating($pinch) { v, s, _ in s = v }
                .onEnded { v in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        zoom = min(max(zoom * v, 0.6), 2.4)
                    }
                })
        }
        .navigationTitle("Góc chiếu \(nameA) × \(nameB)")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func draw(_ ctx: inout GraphicsContext, cell: CGFloat, palette: ChartPalette) {
        let gap = cell * 0.04
        func box(_ r: CGRect) -> Path {
            Path(roundedRect: r.insetBy(dx: gap, dy: gap), cornerRadius: cell * 0.14)
        }
        // Hàng tiêu đề: hành tinh người B (đỏ) — grid.py:150-200
        for (c, nb) in model.colsObjects.enumerated() {
            let rect = CGRect(x: CGFloat(c + 1) * cell, y: 0, width: cell, height: cell)
            ctx.fill(box(rect), with: .color(palette.gridHeader))
            ctx.draw(Text(AstroConst.planetSymbols[nb] ?? nb)
                        .font(.system(size: cell * 0.5, weight: .bold))
                        .foregroundColor(palette.person(.b)),
                     at: CGPoint(x: rect.midX, y: rect.midY), anchor: .center)
        }
        for (r, na) in model.rowsObjects.enumerated() {
            let head = CGRect(x: 0, y: CGFloat(r + 1) * cell, width: cell, height: cell)
            ctx.fill(box(head), with: .color(palette.gridHeader))
            ctx.draw(Text(AstroConst.planetSymbols[na] ?? na)
                        .font(.system(size: cell * 0.5, weight: .bold))
                        .foregroundColor(palette.person(.a)),
                     at: CGPoint(x: head.midX, y: head.midY), anchor: .center)

            for (c, slot) in model.cells[r].enumerated() {
                let rect = CGRect(x: CGFloat(c + 1) * cell, y: CGFloat(r + 1) * cell,
                                  width: cell, height: cell)
                switch slot {
                case .empty(let ext):
                    ctx.fill(box(rect), with: .color(ext ? palette.gridEmpty.opacity(0.6) : palette.gridEmpty))
                    ctx.stroke(box(rect), with: .color(palette.gridBorder), lineWidth: 0.5)
                case .header: break
                case .aspect(let a):
                    ctx.fill(box(rect), with: .color(a.isExtended ? palette.gridFilled.opacity(0.7)
                                                                  : palette.gridFilled))
                    // grid.py:224 — viền đậm khi orb < 1°, viền đứt khi orb > 6.5°
                    switch a.border {
                    case .bold:
                        ctx.stroke(box(rect), with: .color(palette.accent), lineWidth: 2)
                    case .dashed:
                        ctx.stroke(box(rect), with: .color(palette.gridBorder),
                                   style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    case .normal:
                        ctx.stroke(box(rect), with: .color(palette.gridBorder), lineWidth: 0.5)
                    }
                    GridGlyph.draw(&ctx, cell: a, center: CGPoint(x: rect.midX, y: rect.midY),
                                   size: cell, color: palette.aspect(a.visual))
                }
            }
        }
    }
}
