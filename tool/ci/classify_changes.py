"""Route changed inputs conservatively without a third-party diff action."""
import json
import os
from pathlib import Path
import re
import subprocess
import sys

ROOT_DOCS = {"AGENTS.md", "CHANGELOG.md", "CONTRIBUTING.md", "HANDOFF.md", "PRIVACY.md", "README.md", "SECURITY.md", "LICENSE"}
APP_ROOT_FILES = {"pubspec.yaml", "pubspec.lock", "analysis_options.yaml", "l10n.yaml", "THIRD_PARTY_NOTICES.md"}
APP_PREFIXES = ("lib/", "test/", "integration_test/", "android/", "ios/", "linux/", "macos/", "windows/", "web/", "third_party/", "tool/release/", "fastlane/", "assets/")
SHARED_PREFIXES = ("assets/brand/", "assets/fonts/", "assets/icons/", "tool/brand/", "docs/design/brand/")
REVISION = re.compile(r"[0-9a-fA-F]{40}")


def classify_paths(paths):
    app = website = False
    for path in paths:
        # Executable/configuration paths take precedence over documentation skips.
        if path.startswith((".github/workflows/", "tool/ci/")):
            app = website = True
        elif path.startswith(SHARED_PREFIXES) and not path.endswith(".md"):
            app = website = True
        elif path == "docs/design/screenshot-presentation.json" or (path.startswith("docs/release/") and path.endswith("-screenshots.json")):
            app = website = True
        elif path.startswith("fastlane/") and "/images/" in path:
            app = website = True
        elif path in ROOT_DOCS or path in {"website/README.md", "website/VERIFICATION.md"} or (path.startswith(("docs/", "assets/brand/")) and path.endswith(".md")):
            continue
        elif path in {".github/pull_request_template.md", ".github/CODEOWNERS"} or path.startswith(".github/ISSUE_TEMPLATE/"):
            continue
        elif path.startswith("website/"):
            website = True
        elif path in APP_ROOT_FILES or path.startswith(APP_PREFIXES):
            app = True
        else:
            # A new build input must never silently become exempt from CI.
            app = website = True
    return app, website


def diff_range(environment):
    event = environment.get("GITHUB_EVENT_NAME")
    if event == "pull_request":
        base, head = environment.get("PR_BASE_SHA", ""), environment.get("PR_HEAD_SHA", "")
        separator = "..."
    elif event == "push":
        base, head = environment.get("PUSH_BEFORE", ""), environment.get("GITHUB_SHA", "")
        separator = ".."
    else:
        return None
    if not all(REVISION.fullmatch(value) and set(value) != {"0"} for value in (base, head)):
        return None
    return f"{base}{separator}{head}"


def detect_changes(environment, repository="."):
    revision_range = diff_range(environment)
    if revision_range is None:
        return True, True
    try:
        paths = subprocess.check_output(
            ["git", "diff", "--name-only", "--no-renames", "-z", revision_range, "--"],
            cwd=repository, stderr=subprocess.PIPE,
        ).decode("utf-8", errors="surrogateescape").split("\0")
    except (OSError, subprocess.CalledProcessError):
        # Missing history or an unavailable base runs both domains, never skips.
        return True, True
    return classify_paths(path for path in paths if path)


def main():
    app, website = detect_changes(os.environ)
    outputs = {"app": str(app).lower(), "website": str(website).lower()}
    print(json.dumps(outputs))
    if output := os.environ.get("GITHUB_OUTPUT"):
        with Path(output).open("a", encoding="utf-8") as handle:
            handle.writelines(f"{key}={value}\n" for key, value in outputs.items())
    if summary := os.environ.get("GITHUB_STEP_SUMMARY"):
        with Path(summary).open("a", encoding="utf-8") as handle:
            handle.write(f"CI routing: app={outputs['app']}, website={outputs['website']}. Unknown or unavailable inputs run both.\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
