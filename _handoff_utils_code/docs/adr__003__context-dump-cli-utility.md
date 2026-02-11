# ADR-003: Context-Dump CLI Utility for Issues-FS

**Document Identifier:** `adr__003__context-dump-cli-utility`
**Version:** v0.1.0
**Date:** 2026-02-11
**Status:** Proposed
**Author:** Architect (AI Agent)

---

## Context

The Issues-FS ecosystem spans 17 git submodules, 51+ documentation artifacts, 10 role definitions, and 6 module codebases. When starting a new LLM chat session focused on a specific topic (e.g., "refactoring path resolution"), the user must manually gather relevant source files and documentation -- a tedious, error-prone process that wastes context window tokens on irrelevant material.

Additionally, the Journalist and Historian roles need to understand what changed between versions/tags/dates across the entire ecosystem, but no tooling exists for cross-repo diff aggregation. Each submodule has independent version tags, and the main `Issues-FS__Dev` repo tracks submodule pointers that change with each sync.

**Triggers:**
- Human stakeholder request for a developer productivity tool
- Journalist and Historian roles blocked on cross-repo changelog generation
- Recurring pain of manually assembling LLM context for focused coding sessions

---

## Decision

Create a **Context-Dump CLI utility** within the `Issues-FS__Dev` repository with two capabilities:

### Capability 1: Topic-Based Context Dump

A command that, given a topic keyword or code path, gathers all relevant source files and documentation into a single concatenated output suitable for pasting into an LLM chat session.

### Capability 2: Cross-Repo Diff Dump

A command that, given two version references (tags, commits, or dates), produces an aggregated diff across the main repo and all affected submodules.

---

## Options Considered

### Option A: New commands in Issues-FS__CLI

**Pros:** Follows existing CLI infrastructure; shares Typer framework; discoverable via `issues-fs` command.
**Cons:** Issues-FS__CLI is for issue tracking operations (CRUD); context-dump is a developer workflow tool. Mixing concerns violates single-responsibility. Adds a dependency on git submodule structure that the issue tracker should not know about.

### Option B: Standalone module in Issues-FS__Dev (Recommended)

**Pros:** The Dev repo already owns ecosystem orchestration; it knows about all 17 submodules; the tool is inherently about the Dev workspace. No new repo needed. Lightweight implementation as a Python module with a simple CLI entry point.
**Cons:** Not installable via `pip install issues-fs-dev` in practice (the Dev repo is a workspace, not a library). But this is acceptable -- the tool is used from within the Dev workspace.

### Option C: New standalone repo (Issues-FS__Context_Dump)

**Pros:** Clean separation; own versioning.
**Cons:** Over-engineered for a "small utility"; adds a submodule to manage; the tool inherently needs the Dev repo's submodule structure to function.

---

## Recommendation

**Option B** -- implement within `Issues-FS__Dev` as a Python module under `issues_fs_dev/cli/`.

**Rationale:**
- The tool operates on the Dev workspace structure (submodules, docs, roles)
- It is a developer productivity tool, not an issue tracking feature
- Minimal overhead -- no new repo, no new CI pipeline, no new submodule
- The Dev repo is the natural home for ecosystem-level tooling

---

## Component Boundary

**Scope:**
- `issues_fs_dev/cli/` -- CLI entry points and command handlers
- `issues_fs_dev/context_dump/` -- Core logic for topic-based context gathering
- `issues_fs_dev/diff_dump/` -- Core logic for cross-repo diff aggregation

**Non-scope:**
- Issue tracking operations (that is Issues-FS__CLI)
- Documentation authoring (that is the Librarian)
- CI/CD integration (that is DevOps)

---

## Interface Contract

### CLI Commands

```
# Capability 1: Topic-based context dump
python -m issues_fs_dev.cli.context_dump <topic> [options]

Options:
  --include-code      Include source files matching topic (default: true)
  --include-docs      Include documentation files (default: true)
  --include-roles     Include relevant ROLE.md files (default: false)
  --output            Output mode: stdout | clipboard | file (default: stdout)
  --max-files N       Limit number of files included (default: 50)

# Capability 2: Cross-repo diff dump
python -m issues_fs_dev.cli.diff_dump <from-ref> <to-ref> [options]

Options:
  --include-stats     Include file change statistics (default: true)
  --include-full-diff Include full diff content (default: false)
  --modules-only      Only diff module repos, skip role repos (default: false)
  --output            Output mode: stdout | clipboard | file (default: stdout)
```

### Output Format

Both commands produce concatenated text with clear file-path headers:

```
## File: modules/Issues-FS/issues_fs/path/to/file.py
<file contents or diff>

## File: modules/Issues-FS__Docs/docs/architecture/overview.md
<file contents or diff>
```

---

## Affected Repos

| Repo | Impact |
|------|--------|
| `Issues-FS__Dev` | New module added: `issues_fs_dev/cli/`, `issues_fs_dev/context_dump/`, `issues_fs_dev/diff_dump/` |
| `Issues-FS__Docs` | Librarian to create knowledge topic map (data file consumed by context_dump) |

---

## Testability Criteria

- **Topic dump**: Given topic "path", output includes path-related source files and relevant architecture docs
- **Diff dump**: Given two known tags, output includes the correct commit ranges for each changed submodule
- **Clipboard**: Output can be copied to clipboard (when `xclip`/`pbcopy` available)
- **Boundary**: Tool does not modify any files; read-only operations only

---

## Migration

None required. This is a new capability.

---

## Decisions Log

| # | Decision | Rationale |
|---|----------|-----------|
| 1 | Place in Issues-FS__Dev, not Issues-FS__CLI | Single-responsibility: CLI is for issue tracking; context-dump is for developer workflow |
| 2 | Use `python -m` entry point, not a `pyproject.toml` script | Lightweight; avoids adding CLI framework dependency to Dev repo |
| 3 | Topic-to-docs mapping as a data file | Librarian maintains the map; tool consumes it; separation of knowledge from code |
| 4 | Submodule diff via `git log` ranges | Follows git's native model; no custom diff format needed |
