# Git Platform Abstraction Layer

Decouples this skill from any specific git hosting platform. Switch between GitHub, GitLab, Bitbucket, or local-only mode by changing one config file.

## How It Works

All commands in the skill reference `git-platform/api.sh` instead of calling `gh` directly. The script reads `git-platform/config` to determine which adapter to load, then delegates the operation.

```
api.sh → reads config → sources adapters/{platform}.sh → executes operation
```

## Configuration

Edit `git-platform/config` to switch platforms:

```
github     # Default — uses gh CLI
gitlab     # Uses glab CLI (placeholder)
bitbucket  # Uses bb CLI (placeholder)
local      # Git-only, no PR platform
```

## Available Operations

| Domain | Action | Description |
|--------|--------|-------------|
| `pr` | `view <number>` | Get PR/MR details (JSON output) |
| `pr` | `diff <number>` | Get PR/MR diff |
| `pr` | `create --title --body-file --base` | Create PR/MR |
| `pr` | `edit <number> --body-file` | Update PR/MR body |
| `pr` | `ready <number>` | Mark draft PR/MR as ready |
| `pr` | `list --head <branch>` | Find PR/MR by branch |
| `pr` | `checks <number>` | Get CI status |
| `pr` | `comment <number> --body` | Post comment |
| `repo` | `view` | Get repository info |

## Writing a New Adapter

1. Create `adapters/{name}.sh`
2. Implement all `platform_pr_*` and `platform_repo_view` functions
3. Ensure JSON output matches the `gh` CLI schema (for `--json` / `--jq` compatibility)
4. Set `{name}` in `git-platform/config`

See `adapters/github.sh` for a complete reference implementation.
