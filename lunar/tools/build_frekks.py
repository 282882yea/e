"""Ports Frekks Hail v3 onto Lunar UI.

    python3 tools/build_frekks.py <original script> <output script>

Replaces the script's `linoria_library` shared module with frekks/src/*.lua (the
Lunar renderer behind the same Linoria-style API) and leaves every other module
untouched. Images, including the Frekks Hail wordmark used as the window title,
are embedded in the module.
"""
import glob, os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, "..")
sys.path.insert(0, HERE)
from build import embedded  # noqa: E402

START = "__frekks_hook_shared.linoria_library = function()"
NEXT = "__frekks_hook_shared.config_manager = function()"
FUNC_OPEN = re.compile(r"(^|[=(,{]\s*|\blocal\s+|^\s*)function\b[^()]*\([^()]*\)\s*$")


def luraph_attributes(source):
    """Mark every function VM(NONE), like the rest of the script's UI code."""
    out = []
    lines = source.split("\n")
    for i, line in enumerate(lines):
        out.append(line)
        stripped = line.rstrip()
        if stripped.lstrip().startswith("--"):
            continue
        if FUNC_OPEN.search(stripped) and not stripped.endswith("end"):
            indent = re.match(r"\s*", line).group(0)
            out.append(indent + "\tLPH_ATTRIBUTES(VM(NONE));")
    return "\n".join(out)


def module_source():
    parts = sorted(glob.glob(os.path.join(ROOT, "frekks", "src", "*.lua")))
    source = "\n".join(open(p).read().rstrip("\n") for p in parts) + "\n"
    marker = "local EMBEDDED = {} --@EMBED@"
    assert marker in source, "embed marker missing"
    source = luraph_attributes(source)
    return source.replace(marker, "local EMBEDDED = " + embedded({"logo": os.path.join(ROOT, "frekks", "logo.png")}))


def main():
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    original = open(sys.argv[1], encoding="utf-8").read()
    a = original.index(START)
    b = original.index(NEXT)
    module = module_source()
    replacement = START + "\n    LPH_ATTRIBUTES(VM(NONE), ERROR_HANDLING(false));\n" + module.rstrip("\n") + "\nend\n\n"
    ported = original[:a] + replacement + original[b:]
    with open(sys.argv[2], "w", encoding="utf-8") as f:
        f.write(ported)
    open(os.path.join(ROOT, "frekks", "linoria_library.lua"), "w").write(module)
    print("module", len(module), "bytes;", "script", len(original), "->", len(ported), "bytes")


if __name__ == "__main__":
    main()
