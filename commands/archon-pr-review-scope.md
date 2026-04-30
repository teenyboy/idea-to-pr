---
description: Determine review scope, gather diff context, and prepare artifacts directory for review
argument-hint: [base-branch]
---

# Review Scope (Local)

**Input**: $ARGUMENTS (optional: base branch, default: main)

---

## Your Mission

Determine the scope of changes to review, gather diff context needed for the parallel review agents, and prepare the artifacts directory structure.

---

## Phase 1: IDENTIFY - Determine Scope

### 1.1 Determine Base and Head Branches

```bash
# Base branch (from argument or default)
REVIEW_BASE="${ARGUMENTS:-main}"
REVIEW_HEAD=$(git branch --show-current)

echo "Review scope: $REVIEW_BASE...$REVIEW_HEAD"
```

**If on base branch itself** (no feature branch), use unstaged/staged changes:
```bash
if [ "$REVIEW_HEAD" = "$REVIEW_BASE" ]; then
  echo "On base branch — reviewing working tree changes"
  REVIEW_MODE="working-tree"
else
  REVIEW_MODE="branch"
fi
```

### 1.2 Get Diff

```bash
if [ "$REVIEW_MODE" = "branch" ]; then
  git fetch origin $REVIEW_BASE --quiet 2>/dev/null || true
  git diff origin/$REVIEW_BASE...HEAD --stat
else
  git diff --stat
fi
```

### 1.3 List Changed Files

```bash
if [ "$REVIEW_MODE" = "branch" ]; then
  git diff origin/$REVIEW_BASE...HEAD --name-only
else
  git diff --name-only
fi
```

**PHASE_1_CHECKPOINT:**
- [ ] Review scope determined
- [ ] Diff available
- [ ] Changed files listed

---

## Phase 2: CONTEXT - Gather Review Context

### 2.1 Categorize Changed Files

Categorize files from the diff output:
- Source code (`.ts`, `.js`, `.py`, etc.)
- Test files (`*.test.ts`, `*.spec.ts`, `test_*.py`)
- Documentation (`*.md`, `docs/`)
- Configuration (`.json`, `.yaml`, `.toml`)
- Types/interfaces

### 2.2 Check for CLAUDE.md

```bash
cat CLAUDE.md 2>/dev/null | head -100
```

Note key rules that reviewers should check against.

### 2.3 Check for Workflow Artifacts

```bash
# Check for plan context artifact
if [ -f ".claude/skills/idea-to-pr/artifacts/plan-context.md" ]; then
  echo "Plan context found"
  grep -A 20 "## NOT Building" .claude/skills/idea-to-pr/artifacts/plan-context.md 2>/dev/null || true
fi
```

**PHASE_2_CHECKPOINT:**
- [ ] Files categorized
- [ ] CLAUDE.md rules noted
- [ ] Plan context checked

---

## Phase 3: PREPARE - Create Artifacts Directory

### 3.1 Create Directory Structure

```bash
mkdir -p .claude/skills/idea-to-pr/artifacts/review
```

### 3.2 Clean Stale Artifacts

```bash
# Remove review directories older than 7 days
find .claude/skills/idea-to-pr/artifacts/../reviews/* -maxdepth 0 -mtime +7 -exec rm -rf {} \; 2>/dev/null || true
```

### 3.3 Create Scope Manifest

Write `.claude/skills/idea-to-pr/artifacts/review/scope.md`:

```markdown
# Review Scope

**Mode**: Local (git-only)
**Base**: `{base}`
**Head**: `{head}`
**Date**: {ISO timestamp}

---

## Changed Files

{File list from git diff}

| File | Category |
|------|----------|
| `src/file.ts` | source |
| `src/file.test.ts` | test |
| ... | ... |

---

## File Categories

### Source Files ({count})
- `src/...`

### Test Files ({count})
- `src/...test.ts`

### Documentation ({count})
- `README.md`

### Configuration ({count})
- `package.json`

---

## Review Focus Areas

1. **Code Quality**: {list key source files}
2. **Error Handling**: {files with try/catch, error handling}
3. **Test Coverage**: {new functionality needing tests}
4. **Comments/Docs**: {files with documentation changes}

---

## CLAUDE.md Rules to Check

{Extract key rules from CLAUDE.md that apply to this change}

---

## Workflow Context

{If plan-context.md was found:}

### Scope Limits (NOT Building)

**CRITICAL FOR REVIEWERS**: These items are **intentionally excluded** from scope.

{Copy NOT Building section from plan-context.md}

{If no workflow artifacts found:}

_No workflow artifacts found — manual review._

---

## Metadata

- **Scope created**: {ISO timestamp}
- **Artifact path**: `.claude/skills/idea-to-pr/artifacts/review/`
```

**PHASE_3_CHECKPOINT:**
- [ ] Directory created
- [ ] Stale artifacts cleaned
- [ ] Scope manifest written

---

## Phase 4: OUTPUT - Report to User

```markdown
## Review Scope Complete

**Files**: {count} changed
**Mode**: {branch-mode / working-tree}

### File Categories
- Source: {count} files
- Tests: {count} files
- Docs: {count} files
- Config: {count} files

### Artifacts Directory
`.claude/skills/idea-to-pr/artifacts/review/`

### Next Step
Launching 5 parallel review agents...
```

---

## Success Criteria

- **SCOPE_DETERMINED**: Base and head branches identified
- **DIFF_AVAILABLE**: Diff and file list ready
- **ARTIFACTS_DIR_CREATED**: Directory structure exists
- **SCOPE_MANIFEST_WRITTEN**: `scope.md` file created
