"""Fail a stable merge gate unless every applicable job succeeded."""
import json
import os
from pathlib import Path
import sys

REQUIRED = {
    "app": ("quality", "reproducible-android", "integration", "ios-no-sign"),
    "website": ("validate", "ui", "webgl"),
}


def evaluate_gate(domain, needs):
    if domain not in REQUIRED or not isinstance(needs, dict):
        return False, "Invalid required-gate input."
    changes = needs.get("changes", {})
    if changes.get("result") != "success":
        return False, "Changed-file classification did not succeed."
    applicable = changes.get("outputs", {}).get(domain)
    if applicable not in ("true", "false"):
        return False, "Changed-file classification is missing a boolean output."
    expected = "success" if applicable == "true" else "skipped"
    unexpected = [f"{job}={needs.get(job, {}).get('result', 'missing')}" for job in REQUIRED[domain] if needs.get(job, {}).get("result") != expected]
    if unexpected:
        return False, "Required job results differ from " + expected + ": " + ", ".join(unexpected)
    if applicable == "false":
        return True, f"{domain} is not applicable to these changed files; runtime jobs intentionally skipped."
    return True, f"All required {domain} jobs succeeded, including every fixed matrix group."


def main():
    try:
        domain = sys.argv[1]
        needs = json.loads(os.environ["NEEDS_JSON"])
        ok, message = evaluate_gate(domain, needs)
    except (IndexError, KeyError, ValueError, TypeError, AttributeError) as error:
        ok, message = False, f"Cannot validate required jobs: {error}"
    print(message)
    if summary := os.environ.get("GITHUB_STEP_SUMMARY"):
        with Path(summary).open("a", encoding="utf-8") as handle:
            handle.write(message + "\n")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
