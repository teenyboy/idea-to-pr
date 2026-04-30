# idea-to-pr

A Claude Code skill for end-to-end feature development. Transforms a feature idea into a production-ready PR with automated implementation, validation, review, and auto-fix.

## Workflow

| Phase | Step | Description |
|-------|------|-------------|
| 0 | **Create Plan** | Codebase analysis + structured plan with pattern mirroring |
| 1 | **Setup** | Branch creation, scope extraction |
| 2 | **Confirm** | Verify plan research is still valid |
| 3 | **Implement** | Task execution with type-check after every change |
| 4 | **Validate** | Full validation suite (type → lint → format → test → build) |
| 5 | **Finalize PR** | Commit, push, create PR |
| 6 | **Review** | 5 parallel review agents (code, errors, tests, comments, docs) |
| 7 | **Synthesize** | Combine findings, deduplicate, prioritize |
| 8 | **Fix** | Auto-fix all critical and high issues |
| 9 | **Summary** | Decision matrix + follow-up recommendations |

## Usage

```
/idea-to-pr plan <feature description>
/idea-to-pr implement
/idea-to-pr validate
/idea-to-pr review
/idea-to-pr
```

## Directory Structure

```
idea-to-pr/
├── SKILL.md              # Skill entry point with phase-by-phase instructions
├── workflow.yaml         # Workflow orchestration definition
├── README.md             # This file
├── commands/             # 16 command files, one per workflow step
│   ├── archon-create-plan.md
│   ├── archon-plan-setup.md
│   ├── archon-confirm-plan.md
│   ├── archon-implement-tasks.md
│   ├── archon-validate.md
│   ├── archon-finalize-pr.md
│   ├── archon-pr-review-scope.md
│   ├── archon-sync-pr-with-main.md
│   ├── archon-code-review-agent.md
│   ├── archon-error-handling-agent.md
│   ├── archon-test-coverage-agent.md
│   ├── archon-comment-quality-agent.md
│   ├── archon-docs-impact-agent.md
│   ├── archon-synthesize-review.md
│   ├── archon-implement-review-fixes.md
│   └── archon-workflow-summary.md
├── agents/               # 5 agent definitions for parallel review
│   ├── code-reviewer.md
│   ├── silent-failure-hunter.md
│   ├── pr-test-analyzer.md
│   ├── comment-analyzer.md
│   └── docs-impact.md
├── artifacts/            # Output directory (generated during workflow)
│   ├── plan.md
│   ├── plan-context.md
│   ├── plan-confirmation.md
│   ├── implementation.md
│   ├── validation.md
│   ├── pr-ready.md
│   └── review/
└── .git/
```

## Requirements

- [Claude Code](https://claude.ai/code) with skill/agent support
- Git (for branch/PR operations)
- GitHub CLI (`gh`) — for PR creation and review

## Setup

The skill is auto-discovered when placed in `.claude/skills/idea-to-pr/`. No additional configuration is needed.

For workflow artifacts:
```bash
export SKILL_DIR=".claude/skills/idea-to-pr"
export ARTIFACTS_DIR="$SKILL_DIR/artifacts"
```

## Phases in Detail

### Create Plan
Analyzes the codebase, researches external context, and produces a structured implementation plan. No code is written during this phase.

### Setup & Confirm
Creates a feature branch, extracts scope limits from the plan, and re-verifies that research assumptions still hold before implementation starts.

### Implement
Executes tasks defined in the plan sequentially with a hard rule: **type-check after every file change**. Produces an implementation report tracking all changes.

### Validate
Runs the project's validation pipeline — type checking, linting, formatting, tests, and build — in that order, failing fast on errors.

### Review
Launches 5 specialized agents in parallel:
1. **Code Review** — Bugs, patterns, conventions compliance
2. **Error Handling** — Silent failures, error propagation gaps
3. **Test Coverage** — Missing tests, edge cases
4. **Comment Quality** — Stale or misleading comments
5. **Docs Impact** — Outdated documentation

### Fix & Summary
Synthesizes all review findings into a prioritized list, auto-fixes critical and high issues, then produces a final decision matrix with ship recommendations.

## Design Principles

- **Pattern mirroring**: Solutions should fit existing codebase patterns before introducing new ones
- **Fail fast**: Validation runs in strict order (type → lint → format → test → build), stopping at first failure
- **Parallel review**: 5 specialized agents run concurrently for comprehensive coverage
- **Scope-aware**: Review agents respect scope limits defined in the plan to avoid unbounded analysis
