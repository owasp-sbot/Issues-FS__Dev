# Issues-FS CLI Assessment: Is It Actually Working?

**Date:** 2026-02-09
**Versions assessed:** `issues-fs-cli` v0.2.2, `issues-fs` v0.4.5
**Scope:** Can the CLI create, publish, list, and view issues across repos?

## Executive Summary

**The Issues-FS CLI is not working for real-world use.** While the CLI loads, displays help, and passes all 92 unit tests, it **cannot read, create, or list a single issue** in any real repository. The root cause is a double-path-prefix bug in how `Graph__Repository__Factory` and `Path__Handler__Graph_Node` interact. Additionally, the CLI has no cross-repo scanning capability, and installation from PyPI is blocked by circular dependencies.

---

## 1. What the CLI Can Currently Do

### Commands Implemented (13 commands)

| Command | Status | Notes |
|---------|--------|-------|
| `issues-fs init` | Broken on real repos | Creates a doubled `.issues/.issues/` directory |
| `issues-fs create <type> <title>` | Broken | Cannot find node types |
| `issues-fs show <label>` | Broken | Cannot locate issue files |
| `issues-fs list` | Broken | Always returns "No issues found" |
| `issues-fs update <label>` | Broken | Cannot find nodes to update |
| `issues-fs delete <label>` | Broken | Cannot find nodes to delete |
| `issues-fs link <src> <verb> <tgt>` | Broken | Depends on nodes existing |
| `issues-fs unlink <src> <tgt>` | Broken | Depends on nodes existing |
| `issues-fs links <label>` | Broken | Depends on nodes existing |
| `issues-fs comment <label> <text>` | Broken | Depends on nodes existing |
| `issues-fs comments <label>` | Broken | Depends on nodes existing |
| `issues-fs types list` | Broken | Returns "No node types defined" despite types on disk |
| `issues-fs link-types list` | Broken | Returns empty despite link types on disk |

### Design Strengths
- Clean three-layer architecture (Command / Service / Repository)
- Multiple output formats: `--output table`, `--output json`, `--output markdown`
- Agent-optimized output with `--for-agent` flag (structured JSON)
- Proper Typer integration with help text, argument/option validation
- Walk-up `.issues/` directory discovery (like how `git` finds `.git/`)

---

## 2. Critical Bug: Double Path Prefix

### Root Cause

**File:** `modules/Issues-FS/issues_fs/issues/storage/Path__Handler__Graph_Node.py`
- Default `base_path = '.issues'` (line 33)

**File:** `modules/Issues-FS/issues_fs/issues/graph_services/Graph__Repository__Factory.py`
- `create_local_disk()` sets `Storage_FS__Local_Disk(root_path=str(root_path))` where `root_path` is already the `.issues/` directory (line 39)

When the CLI discovers `.issues/` at e.g. `/repo/.issues` and creates a repository, the storage backend is rooted at `/repo/.issues`. The path handler then generates paths like `.issues/config/node-types.json`. The storage backend joins these, looking for `/repo/.issues/.issues/config/node-types.json` -- which does not exist.

**Actual file:** `/repo/.issues/config/node-types.json`
**CLI looks for:** `/repo/.issues/.issues/config/node-types.json`

### Why Tests Still Pass (All 92)

The tests create a temp directory, initialize via the same factory, and run CLI commands against it. Since both writes AND reads go through the doubled path, the bug cancels out. The tests are written **around** the bug, not to detect it.

---

## 3. Installation Blockers

### Circular Dependencies
- `issues-fs-cli` depends on `issues-fs`
- `issues-fs` depends on `issues-fs-cli`
- `issues-fs-cli` also lists **itself** as a dependency

### Python Version Constraint
Both packages require Python `^3.12`. Current environment: 3.11.14.

---

## 4. Cross-Repo Issue Visibility

### Current State: Not Implemented

There is no `--repo` flag, no `issues-fs scan` command, no configuration listing multiple repos, and no aggregation.

### What Exists on Disk (Invisible to CLI)

| Repository | Issues on Disk | Visible to CLI |
|-----------|---------------|----------------|
| Issues-FS (core) | 24 | 0 |
| Issues-FS__CLI | 2 | 0 |
| Issues-FS__Service__UI | 49 | 0 |
| **Total** | **75 issues** | **0** |

---

## 5. Gaps to Fill

### P0 -- Blocking Everything
1. **Fix the double path prefix bug.** `Path__Handler__Graph_Node` should use `base_path = ''` when storage is already rooted at `.issues/`.
2. **Fix circular dependency in pyproject.toml.** `issues-fs` should not depend on `issues-fs-cli`.

### P1 -- Required for Stakeholder Goal
3. **Add cross-repo scanning.** `issues-fs scan` to read multiple `.issues/` directories.
4. **Add integration tests against real `.issues/` directories** (not factory-created ones).
5. **Reconcile `_index.json` schema** (hand-written vs code-generated formats differ).

### P2 -- Important for Usability
6. **Support hierarchical `issues/` layout** (Service UI uses nested structure).
7. **Add `--version` flag.**
8. **Add `publish` command.**

---

## 6. Priority Recommendations

| Priority | Action | Effort | Impact |
|----------|--------|--------|--------|
| **P0** | Fix double `.issues` path prefix | Small | Unblocks ALL commands |
| **P0** | Remove circular dependency | Trivial | Unblocks pip install |
| **P1** | Add real-directory integration test | Small | Prevents regression |
| **P1** | Implement cross-repo scan command | Medium | Core stakeholder need |
| **P2** | Support hierarchical layout | Medium | 49 issues in Service UI use this |

### Bottom Line

The CLI is well-structured and thoughtfully designed. But a single catastrophic bug (the double `.issues` path prefix) renders every command non-functional on real repositories. The tests provide false confidence because they compensate for the bug. No cross-repo capability exists. Until the path bug is fixed, the CLI cannot be used for its intended purpose.
