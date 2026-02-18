# Issues-FS__Dev - Claude Code Session Guide

## Phase 1: Environment Setup

Before doing anything else, initialise the submodule ecosystem.

### Submodule Initialisation (Required)

This repo uses 17 git submodules. In Claude Web sessions, submodule directories start empty.
Follow the runbook to populate them:

- **Runbook**: [`.claude/setup/runbook__claude-web-submodule-setup.md`](.claude/setup/runbook__claude-web-submodule-setup.md)

Quick version (requires `GH_SUBMODULE_TOKEN` secret):

```bash
git config --global url."https://x-access-token:${GH_SUBMODULE_TOKEN}@github.com/".insteadOf "git@github.com:" \
  && git submodule init \
  && git submodule update \
  && git submodule foreach 'git restore --staged . 2>/dev/null; git checkout . 2>/dev/null' \
  && git submodule status
```

All 17 submodules should show a commit hash (no `-` prefix). Confirm before proceeding.

### Verify Setup

```bash
git submodule status   # all 17 should show a commit hash
```

---

## Phase 2: Project Briefing

### What Is Issues-FS?

Issues-FS is a **file-system-based, graph-native issue tracking system** that lives inside Git repositories. Issues are stored as JSON files in `.issues/` directories, versioned by Git, with no external databases or services required.

**Core design principles:**
- **Git-native**: Issues branch and merge with code
- **Graph data model**: Everything is a node; meaning comes from edges (bidirectional links)
- **Pluggable storage**: Memory-FS abstraction with multiple backends (memory, disk, S3, SQLite, ZIP)
- **Type-safe**: All Python uses `osbot-utils` `Type_Safe` with `Safe_*` primitives
- **AI-agent first**: Designed for AI agents to manage without external auth
- **Fractal structure**: Issues nest inside other issues via subdirectories

### What This Repo Is

`Issues-FS__Dev` is the **development orchestration repo** that maps all component repos as git submodules. It is the single checkout point for working across the entire ecosystem.

### Key Documents To Read

Read these in order to build context:

| Priority | Document | Location |
|----------|----------|----------|
| 1 | **Thinking in Graphs** (core philosophy) | `modules/Issues-FS__Docs/docs/to_classify/v0_4_0__issues-fs__thinking-in-graphs.md` |
| 2 | **Architecture Overview** | `modules/Issues-FS__Docs/docs/issues_fs/architecture/v0.4.0__issues-fs__architecture-overview.md` |
| 3 | **Role-Based Agent Coordination** | `modules/Issues-FS__Docs/docs/to_classify/v0.1.0__issues-fs__role-based-agent-coordination.md` |
| 4 | **Agentic Role-Based Workflow Guide** | `modules/Issues-FS__Docs/docs/development/guide__agentic-role-based-workflow.md` |
| 5 | **Memory-FS Abstraction Layer** | `modules/Issues-FS__Docs/docs/issues_fs/architecture/0.41.0__issues-fs__memory-fs-abstraction-layer.md` |
| 6 | **Lexicon Architecture v2** | `modules/Issues-FS__Docs/docs/to_classify/v0_4_0__issues-fs__lexicon-architecture-v2.md` |

**For Type_Safe coding standards** (required before writing any code):

| Document | Location |
|----------|----------|
| Type_Safe guide | `modules/Issues-FS__Docs/docs/issues_fs/llm-briefs/v0.2.14__briefing__graph-based-issue-tracking.md` |
| MGraph-DB briefing | `modules/Issues-FS__Docs/docs/library/mgraph-db/v1_10_6__mGraph-db__llm_briefing.md` |

### The Team

This project uses a **role-based AI agent system**. Each role has a dedicated repo with a `ROLE.md` defining its identity, responsibilities, and workflows:

| Role | Repo Path | Responsibility |
|------|-----------|----------------|
| **Conductor** | `roles/Issues-FS__Dev__Role__Conductor/ROLE.md` | Orchestration, priorities, blockers, workflow routing |
| **Architect** | `roles/Issues-FS__Dev__Role__Architect/ROLE.md` | Technical decisions, API design, ADRs |
| **Dev** | `roles/Issues-FS__Dev__Role__Dev/ROLE.md` | Implementation, bug fixes, tests (Type_Safe discipline) |
| **QA** | `roles/Issues-FS__Dev__Role__QA/ROLE.md` | Adversarial testing, quality gates, defect reporting |
| **DevOps** | `roles/Issues-FS__Dev__Role__DevOps/ROLE.md` | CI/CD, deployment, releases |
| **Librarian** | `roles/Issues-FS__Dev__Role__Librarian/ROLE.md` | Documentation curation, knowledge coherence |
| **Cartographer** | `roles/Issues-FS__Dev__Role__Cartographer/ROLE.md` | Codebase mapping and navigation |
| **AppSec** | `roles/Issues-FS__Dev__Role__AppSec/ROLE.md` | Application security review |
| **Historian** | `roles/Issues-FS__Dev__Role__Historian/ROLE.md` | Historical tracking and change archaeology |
| **Journalist** | `roles/Issues-FS__Dev__Role__Journalist/ROLE.md` | Reporting and communication |

**Human**: Dinis Cruz (`humans/Issues-FS__Dev__Human__Dinis_Cruz/`)

### Component Repos

**Modules (application code):**

| Module | Path | Purpose |
|--------|------|---------|
| Issues-FS | `modules/Issues-FS/` | Core library (graph model, storage, services) |
| Issues-FS__CLI | `modules/Issues-FS__CLI/` | Command-line interface |
| Issues-FS__Docs | `modules/Issues-FS__Docs/` | Documentation hub |
| Issues-FS__Service | `modules/Issues-FS__Service/` | FastAPI REST API server |
| Issues-FS__Service__Client__Python | `modules/Issues-FS__Service__Client__Python/` | Python API client |
| Issues-FS__Service__UI | `modules/Issues-FS__Service__UI/` | Web UI |

### Technology Stack

- **Python 3.12+** with **Poetry** for dependency management
- **osbot-utils / Type_Safe** - Type-safe base classes with `Safe_*` primitives
- **Memory-FS** - Storage abstraction layer
- **MGraph-DB** - Graph database for node/edge operations
- **FastAPI** - REST API framework
- **pytest** - Testing framework

---

## Phase 3: First-Prompt Checklist

Once setup is confirmed, provide the following to orient the session:

1. **Submodule status**: Confirm all 17 submodules initialised (paste `git submodule status` output)
2. **Role assignment**: Which role(s) are you operating as? (Read the relevant `ROLE.md`)
3. **Current task**: What issue, feature, or investigation are you working on?
4. **Branch**: Which branch are you developing on?
5. **Scope**: Which repos will be affected?

---

## Working With Submodules

### Important: Never Update Submodule Pointers in This Repo

**Do NOT commit submodule pointer changes to `Issues-FS__Dev`.** The parent repo's submodule pointers (the commit hashes recorded in the git index for each submodule path) are managed by the human lead and updated during coordinated releases.

When you work on submodules:
- **DO** create branches and push commits directly to the submodule's own repo
- **DO NOT** stage or commit the resulting submodule pointer change in this parent repo (i.e. never `git add modules/Issues-FS` or `git add roles/...` in the parent)

If `git status` in the parent repo shows modified submodule paths, that is expected -- just leave them unstaged.

### Pushing Changes to Submodule Repos

The `GH_SUBMODULE_TOKEN` grants write access. From within a submodule:

```bash
cd roles/Issues-FS__Dev__Role__Dev   # or any submodule
git checkout -b claude/my-feature
# ... make changes ...
git add <files> && git commit -m "Description"
git push -u origin claude/my-feature
```

Branch protection on `main` and `dev` applies - create branches and open PRs.

### Deleting Remote Branches

The git proxy may block `git push --delete`. Use the GitHub API:

```bash
curl -s -X DELETE \
  -H "Authorization: token ${GH_SUBMODULE_TOKEN}" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/owasp-sbot/<REPO_NAME>/git/refs/heads/<BRANCH_NAME>"
```

---

## Key Conventions

- **Naming**: Repos use `Issues-FS__<Component>`; PyPI uses `issues-fs-<component>`; Python uses `issues_fs_<component>`
- **Type Safety**: All classes inherit from `Type_Safe`; use `Safe_*` primitives, never raw `str`/`int`/`bool`
- **Testing**: pytest with `test__` prefix; no `conftest.py`; no `__init__.py` in tests
- **Imports**: Right-aligned to column 70-80
- **Boolean checks**: Always `is True` / `is False`, never truthy/falsy
- **Documents**: Title, identifier, version, date, status header; status = Draft | Active | Superseded | Archived
