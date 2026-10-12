# DESIGN — Hệ thiết kế ChiemTinh (iOS SwiftUI native)

> Nguồn sự thật UI-UX của app iOS `ios/ChiemTinh`. **ĐỌC TRƯỚC khi đụng bất kỳ file `Src/**/*.swift` có View.**
> Mọi token dưới đây có **một cặp tên cố định**: tên trong bảng này = tên hằng trong `Src/Design/Theme.swift`.
> Đổi nguyên tắc/palette ở đây = `Constitution change` → ghi `docs/CHANGELOG.md`.
>
> Lượt lập: 2026-09-09 · W17 (nền UI). Ba worker song song (bánh xe lá số, synastry/composite,
> transit/dữ liệu) **phải gọi đúng tên token trong file này**, cấm hardcode màu/size rời.

---

## 0. Nguồn thiết kế & khuôn khổ

- **File gốc**: không có Figma — **tự thiết kế**, hướng do founder chốt.
- **Phương pháp khớp**: **tự do** (không pixel-exact). Bắt buộc bám token + thang spacing.
- **Design system nền**: **tự build trên SwiftUI thuần** (`Src/Design/Theme.swift` + `Components.swift` + `Glyphs.swift`).
  KHÔNG dùng thư viện UI ngoài, KHÔNG WKWebView, KHÔNG copy bố cục web.
- **Nền tảng**: iOS 17.0+ (`ios/project.yml:3`), iPhone only (`TARGETED_DEVICE_FAMILY: "1"`, `ios/project.yml:29`).

### Hướng thẩm mỹ (founder chốt — cấm tự đổi)
1. **Dark-first**: nền xanh đêm sâu (bầu trời đêm), accent **vàng kim/đồng**.
2. **Tiêu đề = New York** (serif hệ thống Apple, lấy qua `UIFontDescriptor.withDesign(.serif)`),
   **thân chữ = SF Pro** (`UIFont.systemFont`).
3. Cảm giác: **thiên văn cổ điển, sang**. ❌ CẤM gradient tím-hồng kiểu app tử vi rẻ tiền.
   ❌ CẤM neon, CẤM glow màu tím/magenta, CẤM emoji làm icon chức năng.
4. Light mode **có hỗ trợ** (giấy da/parchment ấm) nhưng **dark là mặc định**.

---

## 1. Design Tokens — Màu (palette)

Tên token = `Theme.Colors.<tên>` trong Swift. Mọi màu là **dynamic color**: tự đổi theo `light`/`dark`.

### 1.1 Nền
| Token | Dark | Light | Dùng cho |
|---|---|---|---|
| `bgBase` | `#0B1020` | `#FBF7EF` | nền màn hình gốc (`ScreenBackground`) |
| `bgSunken` | `#070B18` | `#F1EADC` | nền chìm: rãnh, vùng sau bảng, ô nhập |
| `bgSurface` | `#141B33` | `#FFFFFF` | mặt thẻ (`AstroCard`), hàng danh sách |
| `bgSurfaceRaised` | `#1B2444` | `#FFFFFF` | thẻ nổi lớp 2: sheet, popover, hàng được chọn |
| `bgChip` | `#1F2A4C` | `#F2ECDD` | nền chip / badge |

### 1.2 Chữ
| Token | Dark | Light | Dùng cho |
|---|---|---|---|
| `textPrimary` | `#F2EEE4` | `#16182A` | chữ chính, số liệu |
| `textSecondary` | `#A7B0C8` | `#4A5270` | nhãn, mô tả, phụ đề |
| `textMuted` | `#8791AE` | `#676E8C` | chú thích, đơn vị, footer |
| `textOnAccent` | `#0B1020` | `#FFFFFF` | chữ nằm TRÊN nền `accent` |

### 1.3 Nhấn (accent vàng kim/đồng)
| Token | Dark | Light | Dùng cho |
|---|---|---|---|
| `accent` | `#D9A94A` | `#8A6110` | nút chính, tiêu đề mục, chỉ báo tab đang chọn, viền nhấn |
| `accentDim` | `#8A6A2A` | `#C8A968` | trạng thái disabled/press của accent, viền mờ |
| `accentWash` | `#D9A94A` @ 14% | `#8A6110` @ 10% | nền phủ nhẹ sau icon/chip accent |

### 1.4 Viền & phân cách
| Token | Dark | Light | Dùng cho |
|---|---|---|---|
| `border` | `#26314F` | `#E2DACA` | viền thẻ, đường kẻ bảng (**trang trí**) |
| `borderStrong` | `#5B6484` | `#8F856E` | viền UI **mang nghĩa** (ô nhập, nút viền) — đạt ≥3:1 |
| `separator` | `#1E2842` | `#EAE2D2` | kẻ giữa các hàng trong 1 thẻ |

### 1.5 Trạng thái
| Token | Dark | Light | Dùng cho |
|---|---|---|---|
| `success` | `#57C08A` | `#1F7A4D` | hợp lệ, đã lưu, góc Soft |
| `warning` | `#E0A33A` | `#8A5A05` | cảnh báo, giờ sinh không rõ |
| `danger` | `#E5645E` | `#B3322C` | lỗi, xoá, góc Hard |

### 1.6 Màu ngữ nghĩa chiêm tinh (4 nguyên tố — theo `const.py:51 ELEMENT_NAMES`)
| Token | Dark | Light | Nguyên tố |
|---|---|---|---|
| `elementFire` | `#E0764A` | `#B4501F` | Fire (Bạch Dương, Sư Tử, Nhân Mã) |
| `elementEarth` | `#8FA870` | `#4C6B2E` | Earth (Kim Ngưu, Xử Nữ, Ma Kết) |
| `elementAir` | `#7FB6D9` | `#1F6A94` | Air (Song Tử, Thiên Bình, Bảo Bình) |
| `elementWater` | `#9B96E0` | `#5B4FB0` | Water (Cự Giải, Bọ Cạp, Song Ngư) |

Truy cập: `Theme.Colors.element(index)` với `index` = 0..3 theo `AstroConst.elementNames`,
hoặc `Theme.Colors.elementForSign(signIndex)` (dùng `AstroConst.zodiacMatrix`, `const.py:46-50`).

### 1.7 Màu loại góc hợp (theo `ASPECTS_DEF.type`, `const.py:53-61`)
Bảng màu web (`#000000/#ff0000/#0033ff/#00cc00`) là màu **vẽ trên nền trắng matplotlib** — KHÔNG dùng lại
nguyên trạng cho UI dark. Dùng ánh xạ theo `type`:

| Token | Dark | Light | Áp cho `type` |
|---|---|---|---|
| `aspectHard` | `#E5645E` | `#B3322C` | `Hard` (Conjunction, Square, Opposition) |
| `aspectSoft` | `#7FB6D9` | `#1F6A94` | `Soft` (Sextile, Trine) |
| `aspectMinor` | `#8FA870` | `#4C6B2E` | `Minor` (Semisextile, Quincunx) |

Truy cập: `Theme.Colors.aspect(type:)` — nhận đúng chuỗi `"Hard"/"Soft"/"Minor"` của `AstroConst.AspectDef.type`.
> ⚠️ Bánh xe lá số (`Src/Chart/`) vẽ trên nền tối → dùng 3 token này, **cấm** dùng `#000000` của `const.py`.

### 1.8 Kiểm tra tương phản (WCAG) — đã tính bằng script, xem mục 8

---

## 2. Design Tokens — Typography

Hai họ chữ:
- **Serif = New York** (hệ thống Apple): `UIFont.systemFont(ofSize:weight:).fontDescriptor.withDesign(.serif)`.
- **Sans = SF Pro** (`UIFont.systemFont`), mặc định của iOS.
- **Số liệu**: SF Pro + `.monospacedDigit()` để cột số không nhảy.

Mọi bậc đều đi qua `UIFontMetrics(forTextStyle:).scaledFont(for:)` → **hỗ trợ Dynamic Type**.

| Token | Họ | Size / Weight / Style gốc | Dùng cho |
|---|---|---|---|
| `Theme.Fonts.display` | **serif** | 34 / semibold / `.largeTitle` | tên app, tiêu đề màn Dashboard |
| `Theme.Fonts.title1` | **serif** | 28 / semibold / `.title` | tiêu đề màn con |
| `Theme.Fonts.title2` | **serif** | 22 / semibold / `.title2` | tiêu đề thẻ lớn |
| `Theme.Fonts.sectionTitle` | **serif** | 17 / semibold / `.headline` | tiêu đề mục (`SectionHeader`) |
| `Theme.Fonts.headline` | sans | 17 / semibold / `.headline` | nhãn nhấn trong hàng, tên hành tinh |
| `Theme.Fonts.body` | sans | 17 / regular / `.body` | nội dung (≥16pt) |
| `Theme.Fonts.callout` | sans | 16 / regular / `.callout` | nội dung phụ, mô tả tile |
| `Theme.Fonts.subheadline` | sans | 15 / regular / `.subheadline` | nhãn hàng dữ liệu |
| `Theme.Fonts.footnote` | sans | 13 / regular / `.footnote` | chú thích |
| `Theme.Fonts.caption` | sans | 12 / regular / `.caption` | đơn vị, ghi chú nhỏ |
| `Theme.Fonts.numeric` | sans | 15 / medium / `.subheadline` + monospacedDigit | cột độ, orb, ngày giờ |
| `Theme.Fonts.numericSmall` | sans | 12 / regular / `.caption` + monospacedDigit | số trong bảng dày |
| `Theme.Fonts.glyph(size:)` | glyph | size tuỳ ý (mặc định 20) | ký hiệu cung/hành tinh (xem mục 5) |

Hai hàm dựng nền (3 worker kia dùng khi cần size lạ, **không** tự gọi `Font.system` trần):
| Hàm | Ý nghĩa |
|---|---|
| `Theme.Fonts.serif(_:weight:relativeTo:)` | New York, đã scale Dynamic Type |
| `Theme.Fonts.sans(_:weight:relativeTo:)` | SF Pro, đã scale Dynamic Type |
| `Theme.Fonts.caps` | 11 / semibold — nhãn viết hoa nhỏ của `SectionHeader` kiểu `.caps` |

**Tracking**: tiêu đề serif dùng `.tracking(0.2)`; nhãn viết hoa nhỏ (`SectionHeader` kiểu `.caps`) dùng `.tracking(1.2)`.

---

## 3. Spacing / Radius / Shadow / Motion / Layout

### 3.1 Spacing scale (`Theme.Space`) — chỉ dùng các bậc này

| Token | pt | Dùng cho |
|---|---|---|
| `xxs` | 2 | khe giữa 2 dòng chữ dính nhau |
| `xs` | 4 | khe nhỏ nhất giữa 2 phần tử |
| `sm` | 8 | khe trong 1 cụm (icon–chữ) |
| `md` | 12 | khe giữa các hàng / giữa 2 thẻ |
| `lg` | 16 | padding trong thẻ, lề ngang màn |
| `xl` | 24 | khe giữa 2 khối lớn |
| `xxl` | 32 | đệm cuối màn |
| `xxxl` | 48 | khoảng trống lớn (hiếm dùng) |
| `screenH` | 16 | lề ngang chuẩn của MỌI màn |

- Lề ngang màn hình: `Theme.Space.lg` (16).
- Khoảng giữa 2 thẻ: `Theme.Space.md` (12).
- Padding trong thẻ: `Theme.Space.lg` (16).
- Khoảng giữa nhãn và giá trị trong `DataRow`: tối thiểu `Theme.Space.md` (12).

### 3.2 Radius (`Theme.Radius`)

| Token | pt | Dùng cho |
|---|---|---|
| `sm` | 8 | ô nhỏ trong bảng, badge vuông |
| `md` | 12 | nút, ô nhập, `StatTable` |
| `lg` | 16 | thẻ `AstroCard` |
| `xl` | 22 | tile điều hướng, sheet |
| `pill` | 999 | chip, huy hiệu tròn |

### 3.3 Shadow (`Theme.Shadow`)
| Token | Dark | Light |
|---|---|---|
| `card` | `#000000` @ 45%, blur 14, y 6 | `#3A2E14` @ 10%, blur 12, y 4 |
| `raised` | `#000000` @ 55%, blur 24, y 10 | `#3A2E14` @ 14%, blur 20, y 8 |
| `accentGlow` | `accent` @ 28%, blur 18, y 0 | `accent` @ 18%, blur 12, y 0 |

> Dark mode **ưu tiên phân tầng bằng độ sáng nền + viền `border`**, shadow chỉ là phụ.

### 3.4 Motion (`Theme.Motion`)
- `quick` = 0.18s `easeOut` — press/highlight.
- `standard` = 0.28s `easeInOut` — hiện/ẩn khối, đổi tab nội dung.
- `slow` = 0.45s `spring(response:0.45, dampingFraction:0.85)` — bánh xe lá số, chuyển màn lớn.
- CẤM animation gây layout shift khi đang cuộn bảng.

### 3.5 Layout (`Theme.Layout`)

| Token | Giá trị | Dùng cho |
|---|---|---|
| `touchTarget` | 44 | chiều cao tối thiểu vùng chạm (HIG) |
| `buttonHeight` | 50 | nút chính / nút phụ |
| `rowMinHeight` | 36 | chiều cao tối thiểu 1 `DataRow` |
| `tileColumns` | 2 | số cột lưới tile Dashboard |
| `tileMinHeight` | 108 | chiều cao tối thiểu 1 `NavTile` |

- **1 cột**, chiều rộng nội dung = full trừ lề 16.
- Lưới tile Dashboard: **2 cột**, gutter 12 (`Theme.Space.md`).
- Bảng số liệu rộng → cuộn ngang **trong thẻ** (`StatTable`), thân màn **cấm** cuộn ngang.
- Safe area: dùng `.safeAreaInset` / `ignoresSafeArea` đúng chỗ; TabBar native tự lo.
- Touch target ≥ **44×44 pt**.

---

## 4. Components (spec) — `Src/Design/Components.swift`

| Component | Spec |
|---|---|
| `ScreenBackground` | Nền `bgBase` + lớp sao mờ (chấm tĩnh, opacity ≤ 6%) + quầng sáng radial `accentWash` rất nhẹ ở đỉnh. `ignoresSafeArea()`. **Không gradient tím-hồng.** |
| `AstroCard { content }` | padding `lg`(16), nền `bgSurface`, radius `lg`(16), viền 1pt `border`, shadow `card`. Biến thể `.raised` dùng `bgSurfaceRaised` + shadow `raised`. |
| `SectionHeader(title:subtitle:accessory:)` | title `Theme.Fonts.sectionTitle` màu `accent`; subtitle `footnote` màu `textMuted`; accessory bên phải (nút/chip). Kiểu `.caps` cho nhãn nhỏ viết hoa `tracking 1.2`. |
| `DataRow(label:value:)` | 1 hàng nhãn–giá trị. Nhãn `subheadline`/`textSecondary` trái; giá trị `numeric`/`textPrimary` phải; min-height 36; `separator` 1px dưới (trừ hàng cuối). Có biến thể `leading:` (glyph) và `tone:` (đổi màu giá trị theo `success/warning/danger`). |
| `Chip(text:tone:)` | height 26, padding ngang 10, radius `pill`, nền `bgChip` (hoặc `tone` @14%), chữ `caption` màu theo tone. Có `Chip(glyph:text:)`. |
| `PrimaryButton` (`.buttonStyle(.astroPrimary)`) | height 50, radius `md`, nền `accent`, chữ `headline` màu `textOnAccent`, press → `accentDim` + scale 0.98 (`Motion.quick`), disabled → `accentDim` + opacity 0.5. |
| `SecondaryButton` (`.astroSecondary`) | height 50, radius `md`, nền trong suốt, viền 1pt `borderStrong`, chữ `headline` màu `textPrimary`. |
| `GhostButton` (`.astroGhost`) | height 44, không viền, chữ `subheadline` màu `accent`. |
| `NavTile(icon:title:subtitle:tint:)` | thẻ điều hướng Dashboard: 2 cột, min-height 108, radius `xl`, nền `bgSurface`, viền `border`, huy hiệu icon 40×40 radius `pill` nền `tint`@16% chữ `tint`; title `headline`, subtitle `caption`/`textMuted` (2 dòng). |
| `StatTable(columns:rows:)` | bảng số liệu: header dính trái (cột đầu ghim), các cột còn lại **cuộn ngang**; header `caption`/`textMuted` viết hoa; ô `numericSmall`; kẻ `separator`; sọc chẵn-lẻ `bgSunken` @40%. |
| `EmptyState(icon:title:message:actionTitle:action:)` | icon 44 màu `accentDim`, title `title2`, message `callout`/`textSecondary`, nút `.astroSecondary`. |
| `LoadingBlock(text:)` | `ProgressView` + nhãn `footnote`/`textMuted`, giữa thẻ, min-height 120. |
| `PlaceholderScreen(title:owner:note:)` | **chỗ cắm** cho màn của worker khác: nêu rõ màn nào, ai làm. Chỉ tồn tại tới khi worker kia thay bằng view thật. |
| `GlyphBadge(text:tint:size:)` | huy hiệu tròn chứa ký hiệu chiêm tinh; nền `tint`@16%, chữ `tint`. |
| TabBar | **`TabView` native**, 5 tab, `.tint(Theme.Colors.accent)`, nền `bgSurface` (qua `UITabBarAppearance`), nhãn tiếng Việt có dấu. |
| NavigationBar | Tiêu đề dùng **New York** — cấu hình một lần bằng `Theme.applyGlobalAppearance()` gọi trong `init()` của `ChiemTinhApp`. |
| Ô nhập (`Form`/`TextField`) | height ≥44, font `body` (≥16pt chống auto-zoom), nền `bgSunken`, viền `borderStrong` 1pt, focus → viền `accent` 1.5pt. |

---

## 5. Iconography & Glyph chiêm tinh — `Src/Design/Glyphs.swift`

- **Icon chức năng**: **SF Symbols** duy nhất, weight `.regular`, size mặc định 17 (tab bar để iOS tự lo).
- **Ký hiệu chiêm tinh**: nguồn danh sách = `app/astro00_lib/const.py:31-36` (`PLANET_SYMBOLS`) và `const.py:42` (`ZODIAC_SYMBOLS`),
  đã port sang `AstroConst.planetSymbols` / `AstroConst.zodiacSymbols`.

### 5.1 Kết quả kiểm hiển thị trên font hệ thống (đo thật bằng CoreText, không đoán)
Font `AppleSymbols` (ship cùng iOS) **CÓ** glyph cho: 12 cung `♈♉♊♋♌♍♎♏♐♑♒♓`, 10 hành tinh
`☉☽☿♀♂♃♄♅♆♇`, `☊` True Node, `☋` South Node, `☌` `☍` `□` `△`.

Font hệ thống **KHÔNG CÓ** (trên macOS chỉ `STIXTwoMath` có, font này **không chắc có trên iOS**):
`⚷` Chiron (U+26B7) · `⚸` Lilith (U+26B8) · `⚹` Sextile (U+26B9) · `⚺` Semisextile (U+26BA) · `⚻` Quincunx (U+26BB).

### 5.2 Quy tắc bắt buộc
1. Glyph **có trong font** → render bằng ký tự Unicode, font serif (New York) size theo `Theme.Fonts.glyph(size:)`.
2. Glyph **không có trong font** (5 ký tự trên) → **vẽ vector `Shape`** trong `Glyphs.swift`
   (`ChironGlyph`, `LilithGlyph`, `SextileGlyph`, `SemisextileGlyph`, `QuincunxGlyph`).
3. `Asc`→`AC`, `MC`→`MC`, `Vertex`→`Vx` là **chữ cái**, render bằng serif semibold, `lineLimit(1)` + `minimumScaleFactor(0.6)`.
4. API dùng chung: `AstroGlyph(planet:)`, `AstroGlyph(signIndex:)`, `AstroGlyph(aspectType:name:)` —
   3 worker kia **gọi cái này**, cấm tự viết bảng ký hiệu riêng.
5. Có `Glyphs.hasSystemGlyph(_:)` (CoreText) để tự kiểm lúc chạy; thiếu → tự rơi về `Shape`.

---

## 6. Điều hướng & bản đồ màn (đối chiếu web)

Web có 30 route / 19 template (`/tmp/w06-ban-do-tinh-nang.md` mục 1). App gom về **5 tab native**:

| Tab | Nhãn | Route web tương ứng | Ai làm |
|---|---|---|---|
| 1 | **Lá số** | `/dashboard`, `/natal`, `/input` | W17 (shell + dashboard), bánh xe: worker Chart |
| 2 | **Hợp đôi** | `/synastry`, `/composite` | worker Relationship |
| 3 | **Vận hạn** | `/vanhan`, `/vanhan/chung`, `/vanhan/rieng`, `/vanhan/chitiet` | worker Transit |
| 4 | **Tra cứu** | `/planet-connect` + 15 JSON nội dung | worker Data |
| 5 | **Hồ sơ** | `/user`, `/edit_profile`, `/nuoitool` | W17 |

**Bỏ khỏi app** (có lý do, ghi rõ): `/login`, `/register`, `/forgot-password`, `/logout`, `/admin`
— app chạy **offline 100%**, dữ liệu nằm trên máy, không có tài khoản/máy chủ nên không có màn đăng nhập.
(`/forgot-password` của web còn là lỗ hổng — `/tmp/w06-ban-do-tinh-nang.md:146`.)

---

## 7. Accessibility

- Tương phản chữ ≥ **4.5:1** (AA normal). Viền UI mang nghĩa ≥ **3:1**.
- Touch target ≥ **44×44 pt**.
- Dynamic Type: mọi bậc chữ đi qua `UIFontMetrics` → **cấm** `Font.system(size:)` trần trong View.
- `accessibilityLabel` tiếng Việt cho mọi glyph chiêm tinh (ví dụ `♌` → "Sư Tử").
- Không truyền thông tin **chỉ** bằng màu: góc Hard/Soft/Minor luôn kèm ký hiệu + chữ.
- Hỗ trợ `.dynamicTypeSize(...DynamicTypeSize.accessibility2)` — bảng số liệu cuộn ngang khi chữ to.

---

## 8. Bảng tương phản đã tính (WCAG 2.1, script `contrast.py`)

### Dark (mặc định)
| Cặp | Tỉ lệ | Kết luận |
|---|---|---|
| `textPrimary` `#F2EEE4` / `bgBase` `#0B1020` | **16.34:1** | AA + AAA |
| `textPrimary` / `bgSurface` `#141B33` | **14.68:1** | AA + AAA |
| `textPrimary` / `bgSurfaceRaised` `#1B2444` | **13.11:1** | AA + AAA |
| `textSecondary` `#A7B0C8` / `bgSurface` | **7.85:1** | AA + AAA |
| `textMuted` `#8791AE` / `bgBase` | **6.03:1** | AA |
| `textMuted` / `bgSurface` | **5.42:1** | AA |
| `textMuted` / `bgSurfaceRaised` | **4.84:1** | AA |
| `accent` `#D9A94A` / `bgBase` | **8.77:1** | AA + AAA |
| `accent` / `bgSurface` | **7.88:1** | AA + AAA |
| `textOnAccent` `#0B1020` / `accent` | **8.77:1** | AA + AAA |
| `success` `#57C08A` / `bgSurface` | **7.54:1** | AA |
| `warning` `#E0A33A` / `bgSurface` | **7.67:1** | AA |
| `danger` `#E5645E` / `bgSurface` | **5.12:1** | AA |
| `elementFire` `#E0764A` / `bgSurface` | **5.56:1** | AA |
| `elementEarth` `#8FA870` / `bgSurface` | **6.48:1** | AA |
| `elementAir` `#7FB6D9` / `bgSurface` | **7.77:1** | AA |
| `elementWater` `#9B96E0` / `bgSurface` | **6.35:1** | AA |
| `borderStrong` `#5B6484` / `bgBase` | **3.25:1** | đạt ngưỡng UI 3:1 |
| `border` `#26314F` / `bgBase` | 1.47:1 | **trang trí** — không mang nghĩa, không áp ngưỡng |

### Light
| Cặp | Tỉ lệ | Kết luận |
|---|---|---|
| `textPrimary` `#16182A` / `bgBase` `#FBF7EF` | **16.40:1** | AA + AAA |
| `textPrimary` / `bgSurface` `#FFFFFF` | **17.53:1** | AA + AAA |
| `textSecondary` `#4A5270` / `bgSurface` | **7.69:1** | AA + AAA |
| `textMuted` `#676E8C` / `bgSurface` | **5.02:1** | AA |
| `textMuted` / `bgBase` | **4.70:1** | AA |
| `accent` `#8A6110` / `bgBase` | **5.17:1** | AA |
| `textOnAccent` `#FFFFFF` / `accent` | **5.53:1** | AA |
| `success` `#1F7A4D` / `bgSurface` | **5.32:1** | AA |
| `warning` `#8A5A05` / `bgSurface` | **5.92:1** | AA |
| `danger` `#B3322C` / `bgSurface` | **6.16:1** | AA |
| `elementFire` `#B4501F` / `bgSurface` | **5.11:1** | AA |
| `elementEarth` `#4C6B2E` / `bgSurface` | **6.09:1** | AA |
| `elementAir` `#1F6A94` / `bgSurface` | **5.92:1** | AA |
| `elementWater` `#5B4FB0` / `bgSurface` | **6.58:1** | AA |
| `borderStrong` `#8F856E` / `bgBase` | **3.42:1** | đạt ngưỡng UI 3:1 |
| `border` `#E2DACA` / `bgBase` | 1.45:1 | **trang trí** |

---

## 9. Do / Don't

- ✅ Gọi token: `Theme.Colors.accent`, `Theme.Fonts.body`, `Theme.Space.lg`, `Theme.Radius.md`.
- ✅ Chữ tiếng Việt **có dấu** ở mọi nhãn hiển thị.
- ✅ Ô nhập ≥16pt; nút ≥44pt.
- ✅ Bảng rộng → `StatTable` cuộn ngang trong thẻ.
- ✅ Glyph chiêm tinh → luôn qua `AstroGlyph`.
- ❌ Hardcode `Color(hex:)` / `.padding(15)` / `Font.system(size: 18)` rời trong View.
- ❌ Gradient tím-hồng, neon, emoji làm icon chức năng.
- ❌ Dùng màu `ASPECTS_DEF.color` của `const.py` cho UI (đó là màu vẽ trên nền trắng matplotlib).
- ❌ Đổi palette mà không cập nhật file này + `docs/CHANGELOG.md`.
