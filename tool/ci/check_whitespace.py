"""Check the submitted commit range rather than a clean checkout's empty diff."""
import os
import subprocess
from classify_changes import diff_range

revision_range = diff_range(os.environ)
command = ["git", "diff", "--check", revision_range, "--"] if revision_range else ["git", "show", "--format=", "--check", "HEAD", "--"]
raise SystemExit(subprocess.call(command))
