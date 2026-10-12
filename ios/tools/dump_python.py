#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
HARNESS ĐỐI CHIẾU — PHÍA PYTHON.

Chạy HÀM GỐC `calculate_chart` trong repo `git@github.com:hentaiikidd/chiemtinh.git`
(HEAD 73e2e63) tại `app/astro00_lib/core.py`, với danh sách ca kiểm trong `cases.json`,
rồi xuất JSON để so với bản Swift.

KHÔNG sửa bất kỳ file nào của repo — chỉ nạp module bằng importlib.
Chạy:  <venv>/bin/python dump_python.py <repo_root> <cases.json> <output.json>
"""
import sys, os, json, types, importlib.util

def load_astro_lib(repo_root):
    """Nạp `app/astro00_lib` như một package độc lập, KHÔNG kéo theo Flask app."""
    pkg_dir = os.path.join(repo_root, "app", "astro00_lib")
    if not os.path.isdir(pkg_dir):
        raise SystemExit(f"Không thấy {pkg_dir}")
    pkg = types.ModuleType("astro00_lib")
    pkg.__path__ = [pkg_dir]
    sys.modules["astro00_lib"] = pkg

    def _load(name):
        path = os.path.join(pkg_dir, name + ".py")
        spec = importlib.util.spec_from_file_location("astro00_lib." + name, path)
        mod = importlib.util.module_from_spec(spec)
        sys.modules["astro00_lib." + name] = mod
        spec.loader.exec_module(mod)
        return mod

    _load("const")
    return _load("core")


def main():
    repo_root = sys.argv[1]
    cases_path = sys.argv[2]
    out_path = sys.argv[3]

    core = load_astro_lib(repo_root)
    import swisseph as swe

    # core.py tự set_ephe_path theo BASE_DIR của repo; in ra để chứng minh
    ephe_dir = core.EPHE_PATH
    meta = {
        "python": sys.version.split()[0],
        "pyswisseph_version": getattr(swe, "version", "?"),
        "swe_version_c": swe.version,
        "ephe_path": ephe_dir,
        "ephe_files": sorted(os.listdir(ephe_dir)) if os.path.isdir(ephe_dir) else [],
        "core_py": os.path.join(repo_root, "app", "astro00_lib", "core.py"),
    }

    cases = json.load(open(cases_path, encoding="utf-8"))
    out = {"meta": meta, "results": []}

    for c in cases:
        ch = core.calculate_chart(
            c["dob"], c["tob"], c["lat"], c["lon"],
            tz_str=c.get("tz"), manual_offset=c.get("manual_offset")
        )
        if ch is None:
            out["results"].append({"id": c["id"], "error": "calculate_chart trả về None"})
            continue
        cusps = list(ch["cusps"])
        planets = {k: {"lon": v["lon"], "lat": v["lat"], "speed": v["speed"]}
                   for k, v in ch["planets"].items()}
        out["results"].append({
            "id": c["id"],
            "input": c,
            "jd": ch["jd"],
            "cusps_len": len(cusps),
            "cusps": cusps,
            "angles": ch["angles"],
            "planet_order": list(ch["planets"].keys()),
            "planets": planets,
            "info": ch["info"],
            "meta": ch["meta"],
        })

    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, indent=1, sort_keys=True)
    print(f"Đã ghi {out_path} — {len(out['results'])} ca")
    print(json.dumps(meta, ensure_ascii=False, indent=1))


if __name__ == "__main__":
    main()
