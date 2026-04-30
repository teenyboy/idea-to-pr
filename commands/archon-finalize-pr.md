---
description: Commit changes, push to remote, report branch status
argument-hint: (no arguments - reads from workflow artifacts)
---

# Finalize Changes

**Workflow ID**: idea-to-pr

---

## Your Mission

Finalize the implementation:
1. Commit all changes
2. Push to remote
3. Report branch status (no PR created — this is the local version)

---

## Phase 1: LOAD - Gather Context

### 1.1 Load Workflow Artifacts

```bash
cat .claude/skills/idea-to-pr/artifacts/plan-context.md
cat .claude/skills/idea-to-pr/artifacts/implementation.md
cat .claude/skills/idea-to-pr/artifacts/validation.md
```

Extract:
- Plan title and summary
- Branch name
- Files changed
- Tests written
- Validation results
- Deviations from plan (if any)

**PHASE_1_CHECKPOINT:**

- [ ] Artifacts loaded

---

## Phase 2: COMMIT - Stage and Commit Changes

### 2.1 Check Git Status

```bash
git status --porcelain
```

### 2.2 Stage Changes

Stage all implementation changes:

```bash
git add -A
```

**Review staged files** - ensure no sensitive files (.env, credentials) are included:

```bash
git diff --cached --name-only
```

### 2.3 Create Commit

Create a descriptive commit message:

```bash
git commit -m "{summary of implementation}

- {key change 1}
- {key change 2}
- {key change 3}
"
```

### 2.4 Push to Remote

```bash
git push origin HEAD
```

**PHASE_2_CHECKPOINT:**

- [ ] All changes staged
- [ ] No sensitive files included
- [ ] Commit created
- [ ] Pushed to remote

---

## Phase 3: ARTIFACT - Write Completion Status

### 3.1 Write Artifact

Write to `.claude/skills/idea-to-pr/artifacts/pr-ready.md`:

```markdown
# Changes Complete

**Generated**: {YYYY-MM-DD HH:MM}
**Workflow ID**: idea-to-pr

---

## Branch

| Field | Value |
|-------|-------|
| **Branch** | `{branch-name}` |
| **Status** | Pushed to remote |

---

## Commit

**Hash**: {commit-sha}
**Message**: {commit-message-first-line}

---

## Files Changed

{From git diff --name-only origin/main}

| File | Status |
|------|--------|
| `src/x.ts` | Added |
| `src/y.ts` | Modified |

---

## Next Step

Continue to code review:
1. Review agents (parallel)
2. `archon-synthesize-review`
3. `archon-implement-review-fixes`
```

**PHASE_3_CHECKPOINT:**

- [ ] Completion artifact written

---

## Phase 4: OUTPUT - Report Status

```markdown
## Changes Complete

**Workflow ID**: `idea-to-pr`

### Branch

| Field | Value |
|-------|-------|
| Branch | `{branch}` |
| Status | Pushed to remote |

### Commit

```
{commit-sha-short} {commit-message-first-line}
```

### Files Changed

- {N} files added
- {M} files modified
- {K} files deleted

### Validation Summary

| Check | Status |
|-------|--------|
| Type check | ✅ |
| Lint | ✅ |
| Tests | ✅ ({N} passed) |
| Build | ✅ |

### Next Step

Proceeding to code review.
```

---

## Error Handling

### Nothing to Commit

If no changes to commit:

```markdown
ℹ️ No changes to commit

All changes were already committed.
```

### Push Fails

```bash
# Try force push if branch was rebased
git push --force-with-lease origin HEAD
```

If still fails:
```
❌ Push failed

Check:
1. Branch protection rules
2. Push access to repository
3. Remote branch status: `git fetch origin && git status`
```

---

## Success Criteria

- **CHANGES_COMMITTED**: All changes in a commit
- **PUSHED**: Branch pushed to remote
- **ARTIFACT_WRITTEN**: Completion artifact created
