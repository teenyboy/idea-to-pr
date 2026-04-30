# GitLab Adapter (placeholder)
# Uses `glab` CLI. Output normalized to match the interface expected by api.sh.
#
# TODO: Implement full adapter when GitLab support is needed.
# Reference: https://docs.gitlab.com/ee/api/merge_requests.html
#
# Mapping:
#   gh pr view    → glab mr view
#   gh pr diff    → glab mr diff
#   gh pr create  → glab mr create
#   gh pr edit    → glab mr update
#   gh pr list    → glab mr list
#   gh pr comment → glab mr note
#   gh pr checks  → glab mr ci

platform_pr_view()    { echo "GitLab adapter not implemented"; exit 1; }
platform_pr_diff()    { echo "GitLab adapter not implemented"; exit 1; }
platform_pr_create()  { echo "GitLab adapter not implemented"; exit 1; }
platform_pr_edit()    { echo "GitLab adapter not implemented"; exit 1; }
platform_pr_ready()   { echo "GitLab adapter not implemented"; exit 1; }
platform_pr_list()    { echo "GitLab adapter not implemented"; exit 1; }
platform_pr_checks()  { echo "GitLab adapter not implemented"; exit 1; }
platform_pr_comment() { echo "GitLab adapter not implemented"; exit 1; }
platform_repo_view()  { echo "GitLab adapter not implemented"; exit 1; }
