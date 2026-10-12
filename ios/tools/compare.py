#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
So khớp JSON Python vs JSON Swift. Dung sai mặc định 0.0001 độ.
Dùng: compare.py <python.json> <swift.json> [--tol 0.0001] [--md <file.md>]
In BẢNG ĐỐI CHIẾU đầy đủ từng hành tinh / từng cusp và thoát mã 1 nếu có lệch.
"""
import json, sys

TOL = 0.0001

def load(p):
    return json.load(open(p, encoding="utf-8"))

def main():
    py = load(sys.argv[1]); sw = load(sys.argv[2])
    tol = TOL
    md_path = None
    a = sys.argv[3:]
    i = 0
    while i < len(a):
        if a[i] == "--tol": tol = float(a[i+1]); i += 2
        elif a[i] == "--md": md_path = a[i+1]; i += 2
        else: i += 1

    pyr = {r["id"]: r for r in py["results"]}
    swr = {r["id"]: r for r in sw["results"]}

    lines = []
    def P(s=""):
        print(s); lines.append(s)

    P(f"# BẢNG ĐỐI CHIẾU SWIFT vs PYTHON — dung sai {tol} độ")
    P()
    P(f"- Python: pyswisseph `{py['meta'].get('pyswisseph_version')}` / libswe C `{py['meta'].get('swe_version_c')}`, ephe `{py['meta'].get('ephe_path')}`")
    P(f"- Swift : libswe C `{sw['meta'].get('swe_version_c')}` biên dịch thẳng vào app, ephe `{sw['meta'].get('ephe_path')}`")
    P()

    total_fields = 0
    bad = 0
    worst = ("-", "-", 0.0)

    for cid in pyr:
        p = pyr[cid]; s = swr.get(cid)
        P(f"## {cid}")
        if s is None:
            P("❌ Swift KHÔNG có ca này"); bad += 1; P(); continue
        if "error" in p or "error" in s:
            same = ("error" in p) and ("error" in s)
            P(f"- Python: `{p.get('error','OK')}` · Swift: `{s.get('error','OK')}` → {'✅ KHỚP (cả hai đều thất bại như nhau)' if same else '❌ LỆCH'}")
            if not same: bad += 1
            P(); continue

        inp = p["input"]
        P(f"- Vào: `{inp['dob']} {inp['tob']}` lat `{inp['lat']}` lon `{inp['lon']}` tz `{inp.get('tz')}` manual `{inp.get('manual_offset')}` — {inp.get('ghi_chu','')}")
        P()
        rows = []
        def cmp(label, vp, vs, unit="độ"):
            nonlocal total_fields, bad, worst
            total_fields += 1
            d = abs(vp - vs)
            ok = d <= tol
            if not ok: bad += 1
            if d > worst[2]: worst = (cid, label, d)
            rows.append((label, vp, vs, d, ok))

        cmp("Julian Day", p["jd"], s["jd"], "ngày")
        cmp("offset dùng", p["meta"]["offset_used"], s["meta"]["offset_used"], "giờ")
        for k in ("Asc", "MC", "Vertex"):
            cmp(f"góc {k}", p["angles"][k], s["angles"][k])
        for i2 in range(len(p["cusps"])):
            cmp(f"cusp nhà {i2+1}", p["cusps"][i2], s["cusps"][i2])
        for name in p["planet_order"]:
            cmp(f"{name} · kinh độ", p["planets"][name]["lon"], s["planets"][name]["lon"])
            cmp(f"{name} · vĩ độ",  p["planets"][name]["lat"], s["planets"][name]["lat"])
            cmp(f"{name} · tốc độ", p["planets"][name]["speed"], s["planets"][name]["speed"])

        P("| Trường | Python | Swift | |Δ| | Kết quả |")
        P("|---|---:|---:|---:|:--:|")
        for label, vp, vs, d, ok in rows:
            P(f"| {label} | {vp:.10f} | {vs:.10f} | {d:.3e} | {'✅' if ok else '❌ LỆCH'} |")
        P()
        P("Chuỗi hiển thị (`info`):")
        P()
        P("| Trường | Python | Swift | Kết quả |")
        P("|---|---|---|:--:|")
        for k in ("local_time", "ut_time", "lst", "lat_lon", "house_sys"):
            same = p["info"][k] == s["info"][k]
            if not same: bad += 1
            total_fields += 1
            P(f"| {k} | `{p['info'][k]}` | `{s['info'][k]}` | {'✅' if same else '❌ LỆCH'} |")
        P()

    P("---")
    P()
    P(f"**TỔNG: {total_fields} trường so sánh · lệch {bad} · sai số lớn nhất {worst[2]:.3e} tại `{worst[0]}` / {worst[1]}**")
    P()
    P("KẾT LUẬN: " + ("✅ **KHỚP HOÀN TOÀN** trong dung sai." if bad == 0 else f"❌ **CÓ {bad} TRƯỜNG LỆCH** — xem dấu ❌ ở trên."))

    if md_path:
        open(md_path, "w", encoding="utf-8").write("\n".join(lines) + "\n")
    sys.exit(0 if bad == 0 else 1)

if __name__ == "__main__":
    main()
