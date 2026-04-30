# Local Adapter (placeholder)
# For git-only workflows without a PR platform (e.g., local development).
#
# PR operations are not applicable — they fall back to:
#   - diff:  local git diff
#   - comment: echo to stdout
#   - others: error or no-op

platform_pr_view()    { echo "ERROR: No PR platform configured (local mode)"; exit 1; }
platform_pr_diff()    { echo "ERROR: No PR platform configured (local mode)"; exit 1; }

platform_pr_create() {
  echo "INFO: No PR platform configured. Branch is ready for manual PR creation."
  echo "PR_NUMBER=0"
  echo "PR_URL="
}

platform_pr_edit()    { echo "INFO: No PR platform configured. Skipping PR update."; }
platform_pr_ready()   { echo "INFO: No PR platform configured. Skipping ready check."; }

platform_pr_list() {
  echo "INFO: No PR platform configured. No PR to find."
  exit 1
}

platform_pr_checks()  { echo "[]"; }
platform_pr_comment() { echo "--- Comment would be posted to PR ---"; cat -; echo "---"; }

platform_repo_view() {
  # Extract owner/name from git remote
  local url
  url=$(git remote get-url origin 2>/dev/null || echo "local/repo")
  echo "{\"nameWithOwner\": \"$url\"}"
}
