"""Exercise the public PR-event checker with real JSON files and exit codes."""
from copy import deepcopy
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[3]
CHECKER = ROOT / "tool/ci/check_pr_conventions.py"
REPOSITORY = "x1a0Y4NGren/hoopito"


def event(branch="fix/scoring-undo", title="fix(scoring): 修复撤回后的比分", number=42):
    repository = {"id": 1235753309, "full_name": REPOSITORY}
    return {"number": number, "pull_request": {
        "number": number, "title": title,
        "user": {"login": "contributor", "type": "User"},
        "head": {"ref": branch, "repo": deepcopy(repository)},
        "base": {"ref": "main", "repo": deepcopy(repository)},
    }}


def dependabot(branch="deps/npm_and_yarn/website/zod-4.6.7", number=43):
    payload = event(branch, "chore(deps): bump zod to 4.6.7", number)
    payload["pull_request"]["user"] = {"login": "dependabot[bot]", "type": "Bot"}
    return payload


class PRConventionsTests(unittest.TestCase):
    def check(self, payload, successful=True, event_name="pull_request"):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "event.json"
            path.write_text(json.dumps(payload), encoding="utf-8")
            environment = {**os.environ, "GITHUB_EVENT_NAME": event_name,
                           "GITHUB_EVENT_PATH": str(path), "GITHUB_REPOSITORY": REPOSITORY}
            result = subprocess.run([sys.executable, str(CHECKER)], env=environment,
                                    capture_output=True, text=True, encoding="utf-8")
        self.assertEqual(result.returncode, 0 if successful else 1, result.stdout + result.stderr)
        if event_name == "pull_request":
            self.assertIn("PR conventions passed" if successful else "PR conventions failed",
                          result.stdout + result.stderr)
        return result

    def test_each_purpose_type_and_optional_issue_number(self):
        for kind in ["feat", "fix", "refactor", "perf", "docs", "test", "build", "ci", "chore", "revert"]:
            with self.subTest(kind=kind):
                self.check(event(f"{kind}/42-match-history", f"{kind}: improve match history"))

    def test_invalid_or_platform_branch_prefixes(self):
        for branch in ["codex/scoring-undo", "claude/scoring-undo", "contributor/scoring-undo",
                       "fix/Scoring-undo", "fix/scoring_undo", "fix/scoring--undo", "fix/-undo",
                       "fix/undo-", "fix/", "fix/a/b", "fix/撤回", "scoring-undo", "main"]:
            with self.subTest(branch=branch):
                self.check(event(branch), False)

    def test_titles_allow_chinese_english_scope_and_breaking_marker(self):
        for title in ["fix: 修复撤回", "fix(scoring): correct the score", "feat!: change export format",
                      "feat(backup-format)!: 更换备份格式"]:
            with self.subTest(title=title):
                self.check(event(title=title))

    def test_empty_or_malformed_titles(self):
        for title in ["", "fix:", "fix: ", "fix:  ", "Fix: undo", "fix:undo", "undo scoring",
                      "fix(): undo", "fix(BACKUP): undo", "fix(a/b): undo", "fix(--): undo",
                      " fix: undo", "fix: undo ", "fix: undo\nmore", "fix: undo\rmore"]:
            with self.subTest(title=title):
                self.check(event(title=title), False)

    def test_human_fork_is_valid_but_reserved_preview_is_same_repository_only(self):
        payload = event()
        payload["pull_request"]["head"]["repo"] = {"id": 9, "full_name": "contributor/hoopito"}
        self.check(payload)
        self.check(event("preview/website"))
        payload["pull_request"]["head"]["ref"] = "preview/website"
        self.check(payload, False)

    def test_dependency_namespace_requires_authentic_same_repository_bot(self):
        self.check(dependabot())
        self.check(dependabot("deps/github_actions/actions/setup-node-7.1.0"))
        self.check(event("deps/update-zod"), False)
        for change in ["login", "type", "repository_id", "repository_name"]:
            payload = dependabot()
            pr = payload["pull_request"]
            if change == "login": pr["user"]["login"] = "renovate[bot]"
            elif change == "type": pr["user"]["type"] = "User"
            elif change == "repository_id": pr["head"]["repo"]["id"] = 9
            else: pr["head"]["repo"]["full_name"] = "other/hoopito"
            with self.subTest(change=change):
                self.check(payload, False)
        self.check(dependabot("deps/"), False)

    def test_legacy_bot_exception_binds_number_head_and_identity(self):
        branch = "dependabot/npm_and_yarn/website/fast-uri-3.1.9"
        self.check(dependabot(branch, 17))
        self.check(dependabot(branch, 43), False)
        self.check(dependabot(branch + "-other", 17), False)
        self.check(event(branch, "chore: update fast-uri", 17), False)
        payload = dependabot(branch, 17)
        payload["pull_request"]["head"]["repo"]["id"] = 9
        self.check(payload, False)

    def test_missing_or_inconsistent_metadata_fails_closed(self):
        samples = [None, [], {}, {"number": 42}, event()]
        samples[-1]["pull_request"]["number"] = 43
        for key in ["title", "user", "head", "base"]:
            payload = event()
            del payload["pull_request"][key]
            samples.append(payload)
        for key in ["id", "full_name"]:
            payload = event()
            del payload["pull_request"]["base"]["repo"][key]
            samples.append(payload)
        payload = event()
        payload["pull_request"]["head"]["repo"] = None
        samples.append(payload)
        payload = event()
        payload["pull_request"]["base"]["repo"]["id"] = True
        samples.append(payload)
        payload = event()
        payload["pull_request"]["base"]["repo"]["full_name"] = "other/hoopito"
        samples.append(payload)
        for payload in samples:
            with self.subTest(payload=payload):
                self.check(payload, False)

    def test_non_pr_events_skip_metadata_but_unknown_events_fail(self):
        for name in ["push", "workflow_dispatch"]:
            self.check(None, event_name=name)
        self.check(None, False, event_name="pull_request_target")

    def test_missing_or_invalid_event_file_fails(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "event.json"
            environment = {**os.environ, "GITHUB_EVENT_NAME": "pull_request",
                           "GITHUB_EVENT_PATH": str(path), "GITHUB_REPOSITORY": REPOSITORY}
            for content in [None, "{not-json"]:
                if content is not None: path.write_text(content, encoding="utf-8")
                result = subprocess.run([sys.executable, str(CHECKER)], env=environment,
                                        capture_output=True, text=True, encoding="utf-8")
                self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
                self.assertIn("PR conventions failed", result.stdout + result.stderr)

    def test_title_is_data_and_never_executed(self):
        with tempfile.TemporaryDirectory() as directory:
            sentinel = Path(directory) / "must-not-exist"
            self.check(event(title=f"fix: $(New-Item '{sentinel}') `touch '{sentinel}'`"))
            self.assertFalse(sentinel.exists())


if __name__ == "__main__":
    unittest.main()
