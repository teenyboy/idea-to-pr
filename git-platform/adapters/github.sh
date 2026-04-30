# GitHub Adapter
# Delegates to the `gh` CLI. Output format matches GitHub CLI JSON schema.
#
# Functions called by api.sh:
#   platform_pr_view    <number> [--json fields] [--jq filter]
#   platform_pr_diff    <number>
#   platform_pr_create  --title <title> --body-file <path> --base <branch> [--draft]
#   platform_pr_edit    <number> --body-file <path> [--title <title>]
#   platform_pr_ready   <number>
#   platform_pr_list    --head <branch> [--json fields]
#   platform_pr_checks  <number> [--json fields]
#   platform_pr_comment <number> --body <text>
#   platform_repo_view  [--json fields] [--jq filter]

platform_pr_view()    { gh pr view "$@"; }
platform_pr_diff()    { gh pr diff "$@"; }
platform_pr_create()  { gh pr create "$@"; }
platform_pr_edit()    { gh pr edit "$@"; }
platform_pr_ready()   { gh pr ready "$@" 2>/dev/null || true; }
platform_pr_list()    { gh pr list "$@"; }
platform_pr_checks()  { gh pr checks "$@"; }
platform_pr_comment() { gh pr comment "$@"; }
platform_repo_view()  { gh repo view "$@"; }
