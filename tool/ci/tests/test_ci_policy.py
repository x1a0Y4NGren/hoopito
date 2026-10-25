"""Observable routing, gate and workflow-policy regressions (stdlib only)."""
from pathlib import Path
import json
import os
import sys
import subprocess
import tempfile
import unittest
from tool.ci.classify_changes import classify_paths, detect_changes
from tool.ci.required_gate import evaluate_gate
from tool.ci.check_workflows import check_workflow

ROOT = Path(__file__).resolve().parents[3]
SHA = "a" * 40

class ClassificationTests(unittest.TestCase):
    def test_safe_docs_skip_runtime(self):
        self.assertEqual(classify_paths(["README.md", "docs/design/notes.md", "website/README.md"]), (False, False))

    def test_app_inputs(self):
        for path in ["lib/app.dart", "test/a_test.dart", "integration_test/a.dart", "android/app/build.gradle.kts", "ios/Runner/AppDelegate.swift", "pubspec.lock", "third_party/sqlite/sqlite3.c", "tool/release/tool.sh", "assets/audio/cue.wav"]:
            with self.subTest(path=path): self.assertEqual(classify_paths([path]), (True, False))

    def test_website_inputs(self):
        for path in ["website/src/pages/index.astro", "website/tests/site.spec.ts", "website/package-lock.json"]:
            self.assertEqual(classify_paths([path]), (False, True))

    def test_markdown_pages_and_imported_content_require_website(self):
        for path in ["website/src/pages/guide.md", "website/src/pages/guide.mdx", "website/src/content/help.md", "website/custom-content.md"]:
            with self.subTest(path=path):
                self.assertEqual(classify_paths([path]), (False, True))
        self.assertEqual(classify_paths(["website/README.md", "website/VERIFICATION.md"]), (False, False))

    def test_deleted_markdown_page_cannot_become_a_docs_only_rename(self):
        with tempfile.TemporaryDirectory() as directory:
            def git(*args):
                return subprocess.check_output(["git", *args], cwd=directory, text=True).strip()
            git("init", "-q")
            git("config", "user.email", "ci@example.invalid")
            git("config", "user.name", "CI Test")
            root = Path(directory)
            page = root / "website/src/pages/guide.md"
            page.parent.mkdir(parents=True)
            page.write_text("# Published Astro page\n")
            git("add", ".")
            git("commit", "-qm", "markdown page")
            base = git("rev-parse", "HEAD")
            git("mv", "website/src/pages/guide.md", "website/README.md")
            git("commit", "-qm", "remove published page into documentation")
            head = git("rev-parse", "HEAD")
            self.assertEqual(detect_changes({"GITHUB_EVENT_NAME":"push", "PUSH_BEFORE":base, "GITHUB_SHA":head}, directory), (False, True))

    def test_external_shared_assets(self):
        for path in ["assets/icons/icon.png", "assets/fonts/Barlow.ttf", "assets/brand/kit.svg", "docs/design/brand/source.json", "docs/design/screenshot-presentation.json", "docs/release/v2.0.1-screenshots.json", "fastlane/metadata/android/en-US/images/phoneScreenshots/home.png"]:
            with self.subTest(path=path): self.assertEqual(classify_paths([path]), (True, True))

    def test_workflows_ci_and_unknown_inputs_fail_closed(self):
        for path in [".github/workflows/website-ci.yml", "tool/ci/gate.py", "new-build-system.toml", "docs/generated/input.json"]:
            self.assertEqual(classify_paths([path]), (True, True))
        self.assertEqual(classify_paths(["lib/old.dart", "website/src/new.ts"]), (True, True))

    def test_dispatch_and_missing_push_base_run_all(self):
        self.assertEqual(detect_changes({"GITHUB_EVENT_NAME":"workflow_dispatch"}), (True, True))
        self.assertEqual(detect_changes({"GITHUB_EVENT_NAME":"push", "PUSH_BEFORE":"0"*40, "GITHUB_SHA":SHA}), (True, True))

    def test_untrusted_revision_cannot_be_git_option(self):
        self.assertEqual(detect_changes({"GITHUB_EVENT_NAME":"pull_request", "PR_BASE_SHA":"--output=bad", "PR_HEAD_SHA":SHA}), (True, True))

    def test_unavailable_history_runs_everything(self):
        with tempfile.TemporaryDirectory() as directory:
            self.assertEqual(detect_changes({"GITHUB_EVENT_NAME":"push", "PUSH_BEFORE":"b"*40, "GITHUB_SHA":SHA}, directory), (True, True))

    def test_real_git_pr_merge_base_and_push_diff(self):
        with tempfile.TemporaryDirectory() as directory:
            def git(*args): return subprocess.check_output(["git", *args], cwd=directory, text=True).strip()
            git("init", "-q"); git("config", "user.email", "ci@example.invalid"); git("config", "user.name", "CI Test")
            root=Path(directory)
            (root/"README.md").write_text("base\n")
            git("add", "."); git("commit", "-qm", "base")
            base=git("rev-parse", "HEAD"); git("branch", "topic")
            (root/"android").mkdir(); (root/"android/settings.gradle.kts").write_text("main only\n")
            git("add", "."); git("commit", "-qm", "main app")
            advanced=git("rev-parse", "HEAD"); git("checkout", "-q", "topic")
            (root/"website").mkdir(); (root/"website/page.html").write_text("topic\n")
            git("add", "."); git("commit", "-qm", "website")
            head=git("rev-parse", "HEAD")
            self.assertEqual(detect_changes({"GITHUB_EVENT_NAME":"pull_request", "PR_BASE_SHA":advanced, "PR_HEAD_SHA":head}, directory), (False, True))
            self.assertEqual(detect_changes({"GITHUB_EVENT_NAME":"push", "PUSH_BEFORE":base, "GITHUB_SHA":head}, directory), (False, True))
            (root/"docs").mkdir()
            git("mv", "website/page.html", "docs/page.md")
            git("commit", "-qm", "move website input")
            renamed=git("rev-parse", "HEAD")
            self.assertEqual(detect_changes({"GITHUB_EVENT_NAME":"push", "PUSH_BEFORE":head, "GITHUB_SHA":renamed}, directory), (False, True))

class GateTests(unittest.TestCase):
    def needs(self, domain="app", relevant="true", result="success"):
        jobs=["quality", "reproducible-android", "integration", "ios-no-sign"] if domain=="app" else ["validate", "ui", "webgl"]
        return {"changes":{"result":"success", "outputs":{domain:relevant}}, **{job:{"result":result} for job in jobs}}

    def test_success_and_intentional_skip(self):
        for domain in ["app", "website"]:
            self.assertTrue(evaluate_gate(domain, self.needs(domain))[0])
            ok,message=evaluate_gate(domain,self.needs(domain,"false","skipped"))
            self.assertTrue(ok); self.assertIn("not applicable",message)

    def test_fail_cancel_skip_and_missing_matrix_rollups_fail(self):
        for domain in ["app", "website"]:
            needs=self.needs(domain)
            for job in set(needs)-{"changes"}:
                for result in ["failure", "cancelled", "skipped", "neutral"]:
                    changed=self.needs(domain); changed[job]["result"]=result
                    with self.subTest(domain=domain,job=job,result=result): self.assertFalse(evaluate_gate(domain,changed)[0])
                changed=self.needs(domain); del changed[job]
                self.assertFalse(evaluate_gate(domain,changed)[0])

    def test_bad_classifier_or_inconsistent_skip_fails(self):
        for result in ["failure", "cancelled", "skipped"]:
            needs=self.needs(); needs["changes"]["result"]=result
            self.assertFalse(evaluate_gate("app",needs)[0])
        for relevant in ["", "yes", True, None, "false"]:
            self.assertFalse(evaluate_gate("app",self.needs(relevant=relevant))[0])

class ActionPolicyTests(unittest.TestCase):
    def test_approved_full_sha_and_quoted_value(self):
        for repo in ["actions/checkout", "github/codeql-action/analyze", "subosito/flutter-action", "ReactiveCircus/android-emulator-runner"]:
            self.assertEqual(check_workflow(f"  - uses: '{repo}@{SHA}' # v1\n", "example.yml"), [])

    def test_mutable_short_unapproved_dynamic_local_are_rejected(self):
        for ref in ["actions/checkout@v7", "actions/checkout@abc123", f"unknown/action@{SHA}", "dynamic expression", "./local-action"]:
            self.assertTrue(check_workflow(f"  - uses: {ref}\n", "example.yml"))
        self.assertTrue(check_workflow('steps: [{"uses": "actions/checkout@v7"}]', "example.yml"))
        self.assertTrue(check_workflow("continue-on-error: true", "example.yml"))
        self.assertEqual(check_workflow("continue-on-error: false", "example.yml"), [])
        self.assertTrue(check_workflow(f'steps: [{{uses: actions/checkout@{SHA}}}, {{uses: unknown/action@{SHA}}}]', "example.yml"))

    def test_explicit_and_encoded_yaml_mapping_keys_fail_closed(self):
        fixtures = [
            "steps:\n  - ? uses\n    : actions/checkout@v7\n",
            'steps:\n  - "u\\u0073es": actions/checkout@v7\n',
            'steps:\n  - "\\x75ses": actions/checkout@v7\n',
            "steps: [uses: actions/checkout@v7]\n",
            "steps:\n  - uses: |\n      actions/checkout@v7\n",
        ]
        for fixture in fixtures:
            with self.subTest(fixture=fixture):
                self.assertTrue(check_workflow(fixture, "example.yml"))

    def test_script_and_comment_dictionary_text_is_literal_content(self):
        fixture = f"""# ? uses: actions/checkout@v7
steps:
  - uses: actions/checkout@{SHA} # "u\\u0073es": ignored
  - run: |
      const dict = {{"uses": "actions/checkout@v7", "u\\u0073es": "literal"}};
      // ? uses: just a JavaScript string
      const ignored = {{"continue-on-error": true}};
  - run: node -e 'const dict = {{"uses": "actions/checkout@v7"}}'
"""
        self.assertEqual(check_workflow(fixture, "example.yml"), [])

    def test_matrix_members_failfast_and_unconditional_cells(self):
        fixture="""jobs:
  integration:
    strategy:
      fail-fast: false
      matrix:
        api-level: [24, 36]
"""
        self.assertEqual(check_workflow(fixture,"flutter-ci.yml"),[])
        for text in [fixture.replace("24, 36","36"), fixture.replace("fail-fast: false","fail-fast: true"), fixture.replace("    strategy:","    if: matrix.api-level == 36\n    strategy:")]:
            self.assertTrue(check_workflow(text,"flutter-ci.yml"))
        fixture="""jobs:
  ui:
    strategy:
      fail-fast: false
      matrix:
        browser: [chromium, firefox, webkit]
  webgl:
    strategy:
      fail-fast: false
      matrix:
        shard: [1, 2]
"""
        self.assertEqual(check_workflow(fixture,"website-ci.yml"),[])
        self.assertTrue(check_workflow(fixture.replace("chromium, firefox, webkit","chromium"),"website-ci.yml"))
        self.assertTrue(check_workflow(fixture.replace("[1, 2]","[1]"),"website-ci.yml"))

class CommandLineTests(unittest.TestCase):
    def test_classifier_emits_both_github_outputs_on_dispatch(self):
        with tempfile.TemporaryDirectory() as directory:
            output=Path(directory)/"outputs"
            summary=Path(directory)/"summary"
            env={**os.environ,"GITHUB_EVENT_NAME":"workflow_dispatch","GITHUB_OUTPUT":str(output),"GITHUB_STEP_SUMMARY":str(summary)}
            result=subprocess.run([sys.executable,str(ROOT/"tool/ci/classify_changes.py")],env=env,capture_output=True,text=True)
            self.assertEqual(result.returncode,0,result.stderr)
            self.assertEqual(output.read_text().splitlines(),["app=true","website=true"])
            self.assertIn("CI routing",summary.read_text())

    def test_gate_process_exit_code_and_summary_preserve_failures(self):
        for result in ["success","failure","cancelled","skipped"]:
            needs=GateTests().needs()
            needs["integration"]["result"]=result
            with tempfile.TemporaryDirectory() as directory:
                summary=Path(directory)/"summary"
                env={**os.environ,"NEEDS_JSON":json.dumps(needs),"GITHUB_STEP_SUMMARY":str(summary)}
                process=subprocess.run([sys.executable,str(ROOT/"tool/ci/required_gate.py"),"app"],env=env,capture_output=True,text=True)
                self.assertEqual(process.returncode,0 if result=="success" else 1,process.stderr)
                self.assertTrue(summary.read_text().strip())

if __name__=="__main__": unittest.main()
