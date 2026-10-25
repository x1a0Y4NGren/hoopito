"""Validate PR metadata as data, without privileged events or API credentials."""
import json
import os
from pathlib import Path
import re
import subprocess
import sys

SLUG = r"[a-z0-9]+(?:-[a-z0-9]+)*"
POLICY = Path(__file__).with_name("pr_conventions.json")


def mapping(value, label):
    if not isinstance(value, dict):
        raise ValueError(f"missing or invalid {label}")
    return value


def text(value, label):
    if not isinstance(value, str) or not value or value != value.strip():
        raise ValueError(f"missing or invalid {label}")
    return value


def positive_integer(value, label):
    if type(value) is not int or value <= 0:
        raise ValueError(f"missing or invalid {label}")
    return value


def repository(value, label):
    value = mapping(value, label)
    identity = positive_integer(value.get("id"), label + " ID")
    name = text(value.get("full_name"), label + " name")
    if not re.fullmatch(r"[^/\s]+/[^/\s]+", name):
        raise ValueError(f"invalid {label} name")
    return identity, name


def validate(payload, policy, expected_repository):
    payload = mapping(payload, "event")
    pr = mapping(payload.get("pull_request"), "pull_request")
    number = positive_integer(payload.get("number"), "PR number")
    if positive_integer(pr.get("number"), "nested PR number") != number:
        raise ValueError("inconsistent PR number")
    title = text(pr.get("title"), "PR title")
    user = mapping(pr.get("user"), "PR author")
    login = text(user.get("login"), "PR author login")
    user_type = text(user.get("type"), "PR author type")
    head = mapping(pr.get("head"), "PR head")
    branch = text(head.get("ref"), "head branch")
    head_repository = repository(head.get("repo"), "head repository")
    base = mapping(pr.get("base"), "PR base")
    base_repository = repository(base.get("repo"), "base repository")
    if base_repository[1] != text(expected_repository, "GITHUB_REPOSITORY"):
        raise ValueError("base repository does not match GITHUB_REPOSITORY")
    if base.get("ref") != "main":
        raise ValueError("expected a PR targeting main")

    types = policy["types"]
    if not isinstance(types, list) or not types or not all(isinstance(kind, str) and re.fullmatch("[a-z]+", kind) for kind in types):
        raise ValueError("invalid configured types")
    kinds = "(?:" + "|".join(re.escape(kind) for kind in types) + ")"
    title_match = re.fullmatch(kinds + rf"(?:\({SLUG}\))?!?: (?P<subject>[^\r\n]+)", title)
    if not title_match or title_match["subject"] != title_match["subject"].strip():
        raise ValueError("title must use type(scope)!: subject; scope and ! are optional")

    same_repository = head_repository == base_repository
    trusted_dependabot = same_repository and login == "dependabot[bot]" and user_type == "Bot"
    ordinary_branch = re.fullmatch(kinds + "/" + SLUG, branch)
    preview_branch = same_repository and branch == policy["preview_branch"]
    legacy_branch = trusted_dependabot and policy["legacy_dependabot_prs"].get(str(number)) == branch
    dependency_branch = False
    if trusted_dependabot and branch.startswith("deps/") and len(branch) > len("deps/"):
        # Git's own parser accepts ecosystem/package names without duplicating
        # ref syntax rules. The argument always starts with deps/, never '-'.
        dependency_branch = subprocess.run(
            ["git", "check-ref-format", "--branch", branch], capture_output=True,
        ).returncode == 0
    if not (ordinary_branch or preview_branch or legacy_branch or dependency_branch):
        raise ValueError("branch must use type/kebab-case-purpose; reserved and legacy namespaces require verified identity")


def main():
    event_name = os.environ.get("GITHUB_EVENT_NAME")
    if event_name in {"push", "workflow_dispatch"}:
        print("PR conventions not applicable to " + event_name)
        return 0
    try:
        if event_name != "pull_request":
            raise ValueError("unsupported or missing event name")
        event_path = text(os.environ.get("GITHUB_EVENT_PATH"), "GITHUB_EVENT_PATH")
        payload = json.loads(Path(event_path).read_text(encoding="utf-8"))
        policy = json.loads(POLICY.read_text(encoding="utf-8"))
        validate(payload, policy, os.environ.get("GITHUB_REPOSITORY"))
    except (OSError, ValueError, KeyError, TypeError) as error:
        print("PR conventions failed: " + str(error), file=sys.stderr)
        return 1
    print("PR conventions passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
