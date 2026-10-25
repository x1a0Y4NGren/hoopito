"""Enforce reviewed external action references and fixed required matrix coverage.

This intentionally small policy scanner uses only Python's standard library. It
requires plain block mapping keys and static action references (values may be
quoted). Explicit, quoted/escaped and flow mapping keys are rejected, rather than
partially interpreting YAML. Scalar lists, comments and literal/folded script
blocks remain supported. GitHub/actionlint validate full YAML syntax.
"""
from pathlib import Path
import re
import sys

APPROVED = {"github/codeql-action", "subosito/flutter-action", "reactivecircus/android-emulator-runner"}
FIELD = re.compile(r"([A-Za-z0-9_.-]+):(?:\s+(.*))?$")
PIN = re.compile(r"([A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+)(?:/[A-Za-z0-9_./-]+)?@([0-9a-fA-F]{40})")
MATRICES = {"flutter-ci.yml": {"integration": ("api-level", ["24", "36"])}, "website-ci.yml": {"ui": ("browser", ["chromium", "firefox", "webkit"]), "webgl": ("shard", ["1", "2"])}}


def check_workflow(text, filename):
    errors = []
    scalar_indent = None
    for number, line in enumerate(text.splitlines(), 1):
        body = line.lstrip()
        if not body or body.startswith("#"):
            continue
        indent = len(line) - len(body)
        if scalar_indent is not None:
            if indent > scalar_indent:
                continue
            scalar_indent = None
        if body.startswith("- "):
            body = body[2:].lstrip()
        if body.startswith(("?", ":", "&", "!", "*", "{", "\"", "'")):
            # Quoted scalar list members are harmless; a colon or an unfinished
            # quote could instead hide a quoted/encoded/multiline mapping key.
            quoted_scalar = body.startswith(("\"", "'")) and body.endswith(body[0]) and ":" not in body
            if not quoted_scalar:
                errors.append(f"{filename}:{number}: use plain block mapping keys; explicit, quoted/escaped and flow keys are unsupported")
            continue
        field = FIELD.fullmatch(body)
        if not field:
            continue
        key, value = field[1], (field[2] or "").strip()
        if key == "uses":
            reference = value.split("#", 1)[0].strip()
            if len(reference) >= 2 and reference[0] in {"\"", "'"} and reference[-1] == reference[0]:
                reference = reference[1:-1]
            pin = PIN.fullmatch(reference)
            if not pin or (not pin[1].lower().startswith("actions/") and pin[1].lower() not in APPROVED):
                errors.append(f"{filename}:{number}: action must use an approved repository and full 40-character SHA: {reference}")
        if key == "continue-on-error" and value.split("#", 1)[0].strip() != "false":
            errors.append(f"{filename}:{number}: continue-on-error can hide a required failure")
        if re.fullmatch(r"[|>][+\-0-9]*(?:\s+#.*)?", value):
            scalar_indent = indent
        elif key != "run" and (value.startswith("{") or (value.startswith("[") and any(character in value for character in "{:?"))):
            errors.append(f"{filename}:{number}: use block mappings and scalar-only flow lists")
    for job, (axis, expected) in MATRICES.get(Path(filename).name, {}).items():
        match = re.search(rf"^  {re.escape(job)}:\s*\n(.*?)(?=^  [A-Za-z0-9_-]+:|\Z)", text, re.M | re.S)
        if not match:
            errors.append(f"{filename}: missing required matrix job {job}")
            continue
        block = match[1]
        members = re.search(rf"^        {re.escape(axis)}:\s*\[([^]\n]*)\]", block, re.M)
        actual = [item.strip().strip("\"'") for item in members[1].split(",")] if members else []
        if actual != expected or not re.search(r"^      fail-fast: false\s*$", block, re.M):
            errors.append(f"{filename}: {job} must retain matrix {axis}={expected} with fail-fast: false")
        if re.search(r"^    if:.*matrix\.", block, re.M) or re.search(r"^        (include|exclude):", block, re.M):
            errors.append(f"{filename}: {job} cannot conditionally omit required matrix members")
    return errors


def main():
    errors = []
    for path in sorted(Path(".github/workflows").glob("*")):
        if path.suffix in {".yml", ".yaml"}:
            errors.extend(check_workflow(path.read_text(encoding="utf-8"), str(path)))
    print("\n".join(errors) if errors else "Workflow action pins and required matrix coverage passed.")
    return int(bool(errors))


if __name__ == "__main__":
    sys.exit(main())
