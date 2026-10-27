#!/usr/bin/env python3
"""
Build WKU Mac Health Check from an upstream Mac-Health-Check.zsh.

    python3 tools/build.py --source path/to/Mac-Health-Check.zsh \
        --upstream-ref v5.0.1 --upstream-sha 3951166 --out dist

For each variant in wku/variants/*.conf this writes:
    dist/<name>.zsh          the WKU script (copy this one for local testing)
    dist/<name>.mosyle.sh    the base64 wrapper to paste into the Mosyle custom command
and once per build: dist/SHA256SUMS and dist/build-info.json.

Exit codes:
    0  built
    1  build error (a setting, replacement, or override target no longer matches upstream)
    2  upstream changed a function WKU fully replaces; review wku/baselines and wku/overrides.zsh

    python3 tools/build.py --source ... --update-baselines
refreshes wku/baselines/ from the given upstream file once the overrides have been reviewed.
Standard library only.
"""

import argparse
import base64
import datetime
import difflib
import gzip
import hashlib
import json
import re
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
WKU = ROOT / "wku"
PROGRAM_ANCHOR = re.compile(r"^# Program\s*$")
FUNCTION_START = "function {name}() {{"


class BuildError(Exception):
    pass


class BaselineDrift(Exception):
    pass


def fail(message):
    raise BuildError(message)


# ---------------------------------------------------------------------------------------------
# Parsing
# ---------------------------------------------------------------------------------------------

def parse_conf(path):
    """Return (build_keys, settings). build_keys are WKU_* lines; settings are (name, nth, value)."""
    build_keys, settings = {}, []
    for number, raw in enumerate(path.read_text().splitlines(), 1):
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        match = re.match(r"^([A-Za-z_][A-Za-z0-9_]*)(?:@(\d+))?=(.*)$", line)
        if not match:
            fail(f"{path.relative_to(ROOT)}:{number}: can't parse: {raw}")
        name, nth, value = match.group(1), match.group(2), match.group(3)
        if name.startswith("WKU_"):
            build_keys[name] = value
        else:
            settings.append((name, int(nth) if nth else None, value, f"{path.relative_to(ROOT)}:{number}"))
    return build_keys, settings


def extract_function(lines, name):
    """Return the lines of `function name() {` through its closing `}` at column 0."""
    start_text = FUNCTION_START.format(name=name)
    starts = [i for i, line in enumerate(lines) if line.rstrip() == start_text]
    if len(starts) != 1:
        return None
    start = starts[0]
    for end in range(start + 1, len(lines)):
        if lines[end].rstrip() == "}":
            return lines[start:end + 1]
    return None


def overrides_targets(text):
    wrapped = re.findall(r"^wkuWrapFunction\s+(\w+)\s*$", text, re.M)
    defined = re.findall(r"^function\s+(\w+)\(\)\s*\{", text, re.M)
    replaced = [name for name in defined if name not in wrapped and not name.startswith("wku")]
    return wrapped, replaced


# ---------------------------------------------------------------------------------------------
# Steps
# ---------------------------------------------------------------------------------------------

def check_baselines(lines, update):
    """Compare upstream's copy of each fully replaced function against wku/baselines/."""
    overrides = (WKU / "overrides.zsh").read_text()
    _, replaced = overrides_targets(overrides)
    baseline_dir = WKU / "baselines"
    baseline_dir.mkdir(exist_ok=True)
    drift = []
    for name in replaced:
        current = extract_function(lines, name)
        if current is None:
            fail(f"overrides.zsh replaces {name}(), but upstream no longer defines it exactly once")
        baseline_path = baseline_dir / f"{name}.zsh"
        current_text = "\n".join(current) + "\n"
        if not baseline_path.exists() and not update:
            fail(f"no reviewed baseline for {name}(); review it, then run with --update-baselines")
        if update:
            baseline_path.write_text(current_text)
            print(f"  baseline written: wku/baselines/{name}.zsh")
            continue
        baseline_text = baseline_path.read_text()
        if baseline_text != current_text:
            diff = "".join(difflib.unified_diff(
                baseline_text.splitlines(True), current_text.splitlines(True),
                f"wku/baselines/{name}.zsh (reviewed)", f"upstream {name}() (new)"))
            drift.append((name, diff))
    for name in [p.stem for p in baseline_dir.glob("*.zsh") if p.stem not in replaced]:
        print(f"  note: wku/baselines/{name}.zsh is no longer used by overrides.zsh")
    if drift:
        report = "\n".join(f"### {name}()\n```diff\n{diff}```" for name, diff in drift)
        raise BaselineDrift(report)


def apply_settings(lines, settings):
    lines = list(lines)
    for name, nth, value, where in settings:
        prefix = re.compile(rf"^(\s*){re.escape(name)}=")
        if nth is None:
            hits = [i for i, line in enumerate(lines) if re.match(rf"^{re.escape(name)}=", line)]
            if len(hits) != 1:
                fail(f"{where}: expected exactly 1 top-level `{name}=` in upstream, found {len(hits)}"
                     + (" (use name@N= to pick one)" if len(hits) > 1 else ""))
            target = hits[0]
        else:
            hits = [i for i, line in enumerate(lines) if prefix.match(line)]
            if nth < 1 or nth > len(hits):
                fail(f"{where}: `{name}@{nth}` but upstream has {len(hits)} `{name}=` line(s)")
            target = hits[nth - 1]
        indent = prefix.match(lines[target]).group(1)
        lines[target] = f"{indent}{name}={value}"
    return lines


def apply_replacements(text):
    path = WKU / "replacements.json"
    if not path.exists():
        return text
    for item in json.loads(path.read_text()):
        found = text.count(item["find"])
        if found != item["count"]:
            fail(f"replacements.json: expected {item['count']} of {item['find']!r}, found {found} ({item['why']})")
        text = text.replace(item["find"], item["replace"])
    return text


def inject_overrides(lines):
    overrides = (WKU / "overrides.zsh").read_text()
    wrapped, replaced = overrides_targets(overrides)
    for name in wrapped + replaced:
        if extract_function(lines, name) is None:
            fail(f"overrides.zsh targets {name}(), but upstream no longer defines it exactly once")
    anchors = [i for i, line in enumerate(lines) if PROGRAM_ANCHOR.match(line)]
    if len(anchors) != 1:
        fail(f"expected exactly 1 '# Program' section header in upstream, found {len(anchors)}")
    insert_at = anchors[0]
    if insert_at > 0 and set(lines[insert_at - 1].strip()) == {"#"}:
        insert_at -= 1  # keep upstream's banner intact by inserting above its top rule
    return lines[:insert_at] + overrides.rstrip("\n").splitlines() + ["", ""] + lines[insert_at:]


def add_header(lines, info, variant):
    header = [
        "",
        "####################################################################################################",
        f"# WKU build: {variant['WKU_OUTPUT_NAME']} ({info['wku_version']})",
        f"#   upstream: dan-snelson/Mac-Health-Check {info['upstream_ref']} ({info['upstream_sha']})",
        f"#   wku overlay: {info['overlay_sha']}    built: {info['build_date']}",
        "#   source: github.com/bigdoodr/Mac-Health-Check (wku branch); do not edit this file by hand",
        "####################################################################################################",
    ]
    if not lines or not lines[0].startswith("#!"):
        fail("upstream script doesn't start with a shebang line")
    keep = 2 if len(lines) > 1 and lines[1].startswith("# shellcheck ") else 1
    return lines[:keep] + header + lines[keep:]


def verify(text, settings, out_path, require_zsh):
    for name, nth, value, where in settings:
        if f"{name}={value}" not in text:
            fail(f"{where}: `{name}={value}` missing from output")
    zsh = shutil.which("zsh")
    if zsh:
        result = subprocess.run([zsh, "-n", str(out_path)], capture_output=True, text=True)
        if result.returncode != 0:
            fail(f"zsh -n failed for {out_path.name}:\n{result.stderr}")
    elif require_zsh:
        fail("zsh not found and --require-zsh was given")
    else:
        print("  warning: zsh not found; syntax check skipped")


def make_wrapper(script_bytes, variant, info, sha256):
    template = (WKU / "mosyle-wrapper.sh.template").read_text()
    values = {
        "BASE64": base64.b64encode(gzip.compress(script_bytes, 9, mtime=0)).decode("ascii"),
        "OUTPUT_NAME": variant["WKU_OUTPUT_NAME"],
        "MOSYLE_COMMAND": variant.get("WKU_MOSYLE_COMMAND", ""),
        "BUILD_DATE": info["build_date"],
        "UPSTREAM_REF": info["upstream_ref"],
        "UPSTREAM_SHA": info["upstream_sha"],
        "OVERLAY_SHA": info["overlay_sha"],
        "SCRIPT_SHA256": sha256,
    }
    for key, value in values.items():
        template = template.replace("{{" + key + "}}", value)
    leftover = re.findall(r"\{\{[A-Z_]+\}\}", template)
    if leftover:
        fail(f"mosyle-wrapper.sh.template has unknown placeholders: {leftover}")
    return template


def overlay_sha():
    """Git tree hash of the overlay (wku/ + tools/), so any overlay change gives a new build id."""
    try:
        trees = [subprocess.run(["git", "-C", str(ROOT), "rev-parse", f"HEAD:{d}"],
                                capture_output=True, text=True, check=True).stdout.strip()
                 for d in ("wku", "tools")]
        dirty = subprocess.run(["git", "-C", str(ROOT), "status", "--porcelain", "--", "wku", "tools"],
                               capture_output=True, text=True).stdout.strip()
        digest = hashlib.sha1("".join(trees).encode()).hexdigest()[:7]
        return digest + ("-dirty" if dirty else "")
    except (subprocess.CalledProcessError, FileNotFoundError):
        return "local"


# ---------------------------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--source", required=True, type=Path, help="upstream Mac-Health-Check.zsh")
    parser.add_argument("--upstream-ref", default="unknown", help="upstream tag or branch, e.g. v5.0.1")
    parser.add_argument("--upstream-sha", default="unknown", help="upstream commit")
    parser.add_argument("--out", type=Path, default=ROOT / "dist")
    parser.add_argument("--update-baselines", action="store_true")
    parser.add_argument("--require-zsh", action="store_true", help="fail if zsh isn't available (CI)")
    args = parser.parse_args()

    source_text = args.source.read_text()
    source_lines = source_text.splitlines()
    version_match = re.search(r'^scriptVersion="([^"]+)"', source_text, re.M)
    if not version_match:
        fail("couldn't find scriptVersion in upstream script")

    info = {
        "upstream_version": version_match.group(1),
        "upstream_ref": args.upstream_ref,
        "upstream_sha": args.upstream_sha[:7],
        "overlay_sha": overlay_sha(),
        "build_date": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%d %H:%M UTC"),
    }
    info["wku_version"] = f"{info['upstream_version']}-wku.{info['overlay_sha']}"
    print(f"Upstream {info['upstream_version']} ({info['upstream_ref']} {info['upstream_sha']}), overlay {info['overlay_sha']}")

    check_baselines(source_lines, args.update_baselines)
    if args.update_baselines:
        print("Baselines updated; review `git diff wku/baselines` alongside wku/overrides.zsh.")
        return 0

    _, base_settings = parse_conf(WKU / "settings.conf")
    variants = sorted((WKU / "variants").glob("*.conf"))
    if not variants:
        fail("no wku/variants/*.conf found")

    args.out.mkdir(parents=True, exist_ok=True)
    sums, outputs = [], []
    for variant_path in variants:
        variant_keys, variant_settings = parse_conf(variant_path)
        if "WKU_OUTPUT_NAME" not in variant_keys:
            fail(f"{variant_path.relative_to(ROOT)}: WKU_OUTPUT_NAME is required")
        settings = base_settings + variant_settings
        name = variant_keys["WKU_OUTPUT_NAME"]

        lines = apply_settings(source_lines, settings)
        lines = inject_overrides(lines)
        lines = add_header(lines, info, variant_keys)
        text = apply_replacements("\n".join(lines) + "\n")

        script_path = args.out / f"{name}.zsh"
        script_path.write_text(text)
        verify(text, settings, script_path, args.require_zsh)
        script_bytes = script_path.read_bytes()
        sha256 = hashlib.sha256(script_bytes).hexdigest()

        wrapper_path = args.out / f"{name}.mosyle.sh"
        wrapper_path.write_text(make_wrapper(script_bytes, variant_keys, info, sha256))
        if shutil.which("sh"):
            result = subprocess.run(["sh", "-n", str(wrapper_path)], capture_output=True, text=True)
            if result.returncode != 0:
                fail(f"sh -n failed for {wrapper_path.name}:\n{result.stderr}")

        for path in (script_path, wrapper_path):
            sums.append(f"{hashlib.sha256(path.read_bytes()).hexdigest()}  {path.name}")
        outputs.append({"variant": variant_path.stem, "name": name,
                        "mosyle_command": variant_keys.get("WKU_MOSYLE_COMMAND", ""),
                        "script": script_path.name, "script_sha256": sha256,
                        "wrapper": wrapper_path.name})
        print(f"  built {script_path.name} ({len(script_bytes):,} bytes) and {wrapper_path.name}")

    (args.out / "SHA256SUMS").write_text("\n".join(sums) + "\n")
    (args.out / "build-info.json").write_text(json.dumps({**info, "outputs": outputs}, indent=2) + "\n")
    print(f"Done: {info['wku_version']}")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except BaselineDrift as drift:
        print("Upstream changed a function that WKU fully replaces:\n", file=sys.stderr)
        print(drift, file=sys.stderr)
        print("\nPort the upstream change into wku/overrides.zsh, then run with --update-baselines.", file=sys.stderr)
        sys.exit(2)
    except BuildError as error:
        print(f"Build failed: {error}", file=sys.stderr)
        sys.exit(1)
