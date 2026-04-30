---
name: idea-to-pr
description: |
  Full end-to-end feature development workflow. Transforms a feature idea into a
  production-ready PR with comprehensive review and auto-fix.

  Use when: You have a feature idea or description and want end-to-end development.
  Input: Feature description in natural language, or path to a PRD file.

  Full workflow:
  1. CREATE PLAN — Codebase analysis + structured plan with pattern mirroring
  2. SETUP — Branch creation, scope extraction
  3. CONFIRM — Verify plan research is still valid
  4. IMPLEMENT — Tasks with type-check-after-every-change
  5. VALIDATE — Full validation suite (type → lint → format → test → build)
  6. FINALIZE PR — Commit, push, create PR
  7. REVIEW — 5 parallel review agents (code, errors, tests, comments, docs)
  8. SYNTHESIZE — Combine findings, prioritize
  9. FIX — Auto-fix all CRITICAL/HIGH issues
  10. SUMMARY — Final report with decision matrix

  NOT for: Quick fixes, standalone reviews, existing plans (use plan-to-pr).
argument-hint: "[plan <description> | implement | review | continue]"
---

# idea-to-pr

**Source**: Archon workflow `archon-idea-to-pr`
**Workflow**: `workflow.yaml`
**Commands**: `commands/` (16 commands)
**Agents**: `agents/` (5 agents)

## How to Use

- `/idea-to-pr plan <description>` — Start from scratch: create a plan for a feature idea
- `/idea-to-pr implement` — If plan already exists, start implementing
- `/idea-to-pr validate` — Run validation suite
- `/idea-to-pr review` — Run PR review (if PR exists)
- `/idea-to-pr` — Show full workflow menu

## Setup

Set artifacts directory:

```bash
export SKILL_DIR=".claude/skills/idea-to-pr"
export ARTIFACTS_DIR="$SKILL_DIR/artifacts"
mkdir -p "$ARTIFACTS_DIR"
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

**Output**: PR created, `$ARTIFACTS_DIR/.pr-number` written

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
