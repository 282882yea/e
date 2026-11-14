"""Builds the distributable scripts.

    python3 build.py

    src/Lunar.lua + assets/*          ->  Lunar.lua       (library, images embedded as base64)
    Lunar.lua + example.lua           ->  standalone.lua  (one paste, no HTTP requests)
"""
import base64, hashlib, json, os, re

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, "..")
ASSETS = os.path.join(ROOT, "assets")
FILES = ["background", "blossoms", "flowers_left", "flowers_right", "petal", "glow", "icons"]
CHUNK = 1600


def lua_string_table(data: str) -> str:
    chunks = [data[i:i + CHUNK] for i in range(0, len(data), CHUNK)]
    return "table.concat({\n" + "".join(f'\t\t\t"{c}",\n' for c in chunks) + "\t\t})"


def lua_points(points) -> str:
    return "{ " + ", ".join("{ %d, %d }" % (p[0], p[1]) for p in points) + " }"


def embedded(extra=None) -> str:
    """extra: {name: png path} added to the embedded files (and to `sizes`)."""
    icons = json.load(open(os.path.join(ASSETS, "icons.json")))
    art = json.load(open(os.path.join(ASSETS, "art.json")))
    digest = hashlib.sha1()
    blobs = {}
    names = list(FILES) + list((extra or {}).keys())
    paths = {name: os.path.join(ASSETS, name + ".png") for name in FILES}
    paths.update(extra or {})
    for name in names:
        raw = open(paths[name], "rb").read()
        digest.update(raw)
        blobs[name] = base64.b64encode(raw).decode()
    if extra:
        from PIL import Image
        for name, path in extra.items():
            art["sizes"][name] = list(Image.open(path).size)

    out = ["{"]
    out.append(f'\tversion = "{digest.hexdigest()[:10]}",')
    out.append(f'\ticonCell = {icons["cell"]},')
    out.append("\ticons = {")
    row = []
    for name, (x, y) in icons["icons"].items():
        row.append('["%s"] = { %d, %d }' % (name, x, y))
        if len(row) == 4:
            out.append("\t\t" + ", ".join(row) + ",")
            row = []
    if row:
        out.append("\t\t" + ", ".join(row) + ",")
    out.append("\t},")
    out.append("\tsizes = {")
    for name, (w, h) in art["sizes"].items():
        out.append("\t\t%s = { %d, %d }," % (name, w, h))
    out.append("\t},")
    out.append("\tsparkles = {")
    for name, points in art["sparkles"].items():
        out.append("\t\t%s = %s," % (name, lua_points(points)))
    out.append("\t},")
    out.append("\tfiles = {")
    for name in names:
        out.append("\t\t%s = %s," % (name, lua_string_table(blobs[name])))
    out.append("\t},")
    out.append("}")
    return "\n".join(out)


def main():
    src = open(os.path.join(ROOT, "src", "Lunar.lua")).read()
    marker = "local EMBEDDED = {} --@EMBED@"
    assert marker in src, "embed marker missing from src/Lunar.lua"
    lib = src.replace(marker, "local EMBEDDED = " + embedded())
    open(os.path.join(ROOT, "Lunar.lua"), "w").write(lib)

    example = open(os.path.join(ROOT, "example.lua")).read()
    pattern = re.compile(r"^local Lunar = loadstring\(.*$", re.M)
    assert pattern.search(example), "example.lua must load the library with a `local Lunar = loadstring(...)` line"
    body = pattern.sub("", example, count=1).lstrip("\n")
    standalone = (
        "-- Lunar UI, standalone: the library and the demo in one file. Paste into your executor.\n"
        "local Lunar = (function()\n" + lib.rstrip("\n") + "\nend)()\n\n" + body
    )
    open(os.path.join(ROOT, "standalone.lua"), "w").write(standalone)

    for name in ("Lunar.lua", "standalone.lua"):
        print(name, os.path.getsize(os.path.join(ROOT, name)), "bytes")


if __name__ == "__main__":
    main()
