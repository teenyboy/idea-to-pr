---
name: idea-to-pr
description: |
  End-to-end feature development workflow (local/git-only). Transforms a feature
  idea into production-ready code with automated implementation, validation, review,
  and auto-fix. Uses local git workflow — no GitHub/GitLab dependency.

  Use when: You have a feature idea and want end-to-end development without a PR platform.
  Input: Feature description in natural language, or path to a PRD file.

  Full workflow:
  1. CREATE PLAN — Codebase analysis + structured plan with pattern mirroring
  2. SETUP — Branch creation, scope extraction
  3. CONFIRM — Verify plan research is still valid
  4. IMPLEMENT — Tasks with type-check-after-every-change
  5. VALIDATE — Full validation suite (type → lint → format → test → build)
  6. FINALIZE — Commit and push changes to branch
  7. REVIEW — 5 parallel review agents (code, errors, tests, comments, docs)
  8. SYNTHESIZE — Combine findings, prioritize
  9. FIX — Auto-fix all CRITICAL/HIGH issues
  10. SUMMARY — Final report with decision matrix

  NOT for: Quick fixes, standalone reviews, existing plans (use plan-to-pr).
  For GitHub workflow: use idea-to-pr-github instead.
argument-hint: "[plan <description> | implement | review | continue]"
---

# idea-to-pr (local)

**Source**: Archon workflow `archon-idea-to-pr`
**Workflow**: `workflow.yaml`
**Commands**: `commands/` (16 commands)
**Agents**: `agents/` (5 agents)

**Git-only mode**: This skill uses local git commands only. No GitHub/GitLab CLI needed.
Review is based on `git diff main...HEAD`.

## How to Use

- `/idea-to-pr plan <description>` — Start from scratch: create a plan for a feature idea
- `/idea-to-pr implement` — If plan already exists, start implementing
- `/idea-to-pr validate` — Run validation suite
- `/idea-to-pr review` — Run review (based on local diff)
- `/idea-to-pr` — Show full workflow menu

## Setup

Set artifacts directory:

```bash
export SKILL_DIR=".claude/skills/idea-to-pr"
export ARTIFACTS_DIR="$SKILL_DIR/artifacts"
mkdir -p "$ARTIFACTS_DIR"
```

Review diff base (default: `main`):
```bash
export REVIEW_BASE="main"
```

---

## Phase 0: CREATE PLAN

Read `commands/archon-create-plan.md` and follow its instructions.

**Input**: User's feature description (from `$ARGUMENTS`)
**Output**: `$ARTIFACTS_DIR/plan.md`

**Next**: `/idea-to-pr setup`

---

## Phase 1: SETUP

Read `commands/archon-plan-setup.md` and follow its instructions.

**Input**: `$ARTIFACTS_DIR/plan.md`
**Output**: `$ARTIFACTS_DIR/plan-context.md`

**Next**: `/idea-to-pr confirm`

---

## Phase 2: CONFIRM PLAN

Read `commands/archon-confirm-plan.md` and follow its instructions.

**Input**: `$ARTIFACTS_DIR/plan-context.md`
**Output**: `$ARTIFACTS_DIR/plan-confirmation.md`

**Next**: `/idea-to-pr implement`

---

## Phase 3: IMPLEMENT

Read `commands/archon-implement-tasks.md` and follow its instructions.

**Core rule**: Type-check after EVERY file change before proceeding.

**Input**: `$ARTIFACTS_DIR/plan.md` + `$ARTIFACTS_DIR/plan-context.md` + `$ARTIFACTS_DIR/plan-confirmation.md`
**Output**: `$ARTIFACTS_DIR/implementation.md`

**Next**: `/idea-to-pr validate`

---

## Phase 4: VALIDATE

Read `commands/archon-validate.md` and follow its instructions.

**Input**: Validation commands from plan
**Output**: `$ARTIFACTS_DIR/validation.md`

**Next**: `/idea-to-pr finalize-pr`

---

## Phase 5: FINALIZE PR

Read `commands/archon-finalize-pr.md` and follow its instructions.

**Output**: Changes committed and pushed

**Next**: `/idea-to-pr review` (or just run `/idea-to-pr` to continue)

---

## Phase 6: CODE REVIEW

### 6.1 Review Scope

Read `commands/archon-pr-review-scope.md` and follow its instructions.

**Output**: `$ARTIFACTS_DIR/review/scope.md`

### 6.2 Sync with Main

Read `commands/archon-sync-pr-with-main.md` and follow its instructions.

### 6.3 Parallel Review Agents

Launch 5 sub-agents in parallel using the Agent tool. Each reads the corresponding
command file for its full instructions:

| Agent | Command File | Agent Definition | Focus |
|-------|-------------|-----------------|-------|
| Code Review | `commands/archon-code-review-agent.md` | `agents/code-reviewer.md` | Bugs, patterns, CLAUDE.md compliance |
| Error Handling | `commands/archon-error-handling-agent.md` | `agents/silent-failure-hunter.md` | Silent failures, error handling |
| Test Coverage | `commands/archon-test-coverage-agent.md` | `agents/pr-test-analyzer.md` | Test gaps, edge cases |
| Comment Quality | `commands/archon-comment-quality-agent.md` | `agents/comment-analyzer.md` | Comment accuracy, completeness |
| Docs Impact | `commands/archon-docs-impact-agent.md` | `agents/docs-impact.md` | Stale docs, missing updates |

**Launch pattern**:
1. Read each agent's command file to get the instructions
2. Use the Agent tool to launch each as a sub-agent with `$ARTIFACTS_DIR/review/scope.md` context
3. Each writes findings to `$ARTIFACTS_DIR/review/{agent}-findings.md`

---

## Phase 7: SYNTHESIZE REVIEW

Read `commands/archon-synthesize-review.md` and follow its instructions.

**Input**: All 5 agent findings from `$ARTIFACTS_DIR/review/`
**Output**: `$ARTIFACTS_DIR/review/consolidated-review.md`

**Next**: `/idea-to-pr fix`

---

## Phase 8: FIX REVIEW ISSUES

Read `commands/archon-implement-review-fixes.md` and follow its instructions.

**Input**: `$ARTIFACTS_DIR/review/consolidated-review.md`
**Output**: `$ARTIFACTS_DIR/review/fix-report.md`

**Next**: `/idea-to-pr summary`

---

## Phase 9: WORKFLOW SUMMARY

Read `commands/archon-workflow-summary.md` and follow its instructions.

**Input**: All artifacts from previous phases
**Output**: Decision matrix + follow-up recommendations
