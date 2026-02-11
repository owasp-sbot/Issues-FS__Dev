# Issues-FS__Dev

**Development orchestration repo for the Issues-FS ecosystem.** Coordinates 17 submodules spanning core libraries, CLI, services, 10 AI agent roles, and a human stakeholder repo.

[![License: Apache 2.0](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)

---

## What is Issues-FS?

Issues-FS is a **file-system-based, graph-oriented issue tracking library** with hierarchical structure and pluggable storage backends. Issues are stored as JSON files in `.issues/` directories inside git repos, making them version-controllable, branchable, and mergeable alongside code.

Key design principles:

- **Git-native** -- Issues live in the repo, travel with branches, merge with PRs
- **Graph-oriented** -- Issues, types, and links form a traversable graph via MGraph-DB integration
- **Hierarchical** -- Projects contain versions, versions contain tasks, tasks contain subtasks
- **Pluggable storage** -- Memory, local disk, S3, SQLite, or ZIP backends via Memory-FS
- **Human and AI collaboration** -- Designed from the ground up for both human developers and AI agent workflows

## The Role-Based Agent System

Issues-FS__Dev coordinates a team of 10 specialized AI agent roles. Each role has its own repository containing a `ROLE.md` identity document, CI configuration, a Python package, and its own `.issues/` directory. The agents collaborate through Issues-FS itself -- creating issues, tasks, handoffs, and decisions as graph nodes.

### Core Development

| Role | Purpose |
|------|---------|
| **Dev** | Implementation -- writes code, fixes bugs, ships features |
| **Architect** | System design -- ADRs, interface definitions, structural decisions |

### Quality and Security

| Role | Purpose |
|------|---------|
| **QA** | Testing -- test plans, coverage analysis, defect tracking |
| **AppSec** | Security -- threat modeling, vulnerability assessment, secure design review |

### Infrastructure

| Role | Purpose |
|------|---------|
| **DevOps** | CI/CD, deployment, release management, infrastructure health |

### Knowledge and Intelligence

| Role | Purpose |
|------|---------|
| **Librarian** | Knowledge connectivity -- cataloguing, cross-referencing, terminology consistency |
| **Cartographer** | System mapping -- dependency graphs, architecture visualization, codebase navigation |
| **Historian** | Project narrative -- timelines, pivot points, institutional memory |
| **Journalist** | Current reporting -- daily briefs, feature articles, interviews, investigations |

### Orchestration

| Role | Purpose |
|------|---------|
| **Conductor** | Workflow coordination -- priority management, task routing, blockers, cross-role orchestration |

## Repository Map

### Core Libraries

| Repository | Description |
|-----------|-------------|
| [Issues-FS](https://github.com/owasp-sbot/Issues-FS) | Core Python library -- graph-oriented issue model, storage layer, MGraph integration |
| [Issues-FS__CLI](https://github.com/owasp-sbot/Issues-FS__CLI) | Command-line interface for Issues-FS |
| [Issues-FS__Docs](https://github.com/owasp-sbot/Issues-FS__Docs) | Architecture documents, design briefs, specifications |

### Services

| Repository | Description |
|-----------|-------------|
| [Issues-FS__Service](https://github.com/owasp-sbot/Issues-FS__Service) | FastAPI web service exposing Issues-FS operations |
| [Issues-FS__Service__UI](https://github.com/owasp-sbot/Issues-FS__Service__UI) | Web UI for the Issues-FS service |
| [Issues-FS__Service__Client__Python](https://github.com/owasp-sbot/Issues-FS__Service__Client__Python) | Python client library for the Issues-FS service API |

### Development

| Repository | Description |
|-----------|-------------|
| [Issues-FS__Dev](https://github.com/owasp-sbot/Issues-FS__Dev) | This repo -- parent orchestration for all submodules |

### Agent Roles

| Repository | Description |
|-----------|-------------|
| [Issues-FS__Dev__Role__Dev](https://github.com/owasp-sbot/Issues-FS__Dev__Role__Dev) | Dev agent -- implementation, bug fixes, feature development |
| [Issues-FS__Dev__Role__Architect](https://github.com/owasp-sbot/Issues-FS__Dev__Role__Architect) | Architect agent -- ADRs, system design, interface definitions |
| [Issues-FS__Dev__Role__QA](https://github.com/owasp-sbot/Issues-FS__Dev__Role__QA) | QA agent -- test plans, coverage analysis, defect tracking |
| [Issues-FS__Dev__Role__AppSec](https://github.com/owasp-sbot/Issues-FS__Dev__Role__AppSec) | AppSec agent -- security analysis, threat modeling |
| [Issues-FS__Dev__Role__DevOps](https://github.com/owasp-sbot/Issues-FS__Dev__Role__DevOps) | DevOps agent -- CI/CD, releases, infrastructure |
| [Issues-FS__Dev__Role__Librarian](https://github.com/owasp-sbot/Issues-FS__Dev__Role__Librarian) | Librarian agent -- knowledge connectivity, cataloguing |
| [Issues-FS__Dev__Role__Cartographer](https://github.com/owasp-sbot/Issues-FS__Dev__Role__Cartographer) | Cartographer agent -- system mapping, dependency visualization |
| [Issues-FS__Dev__Role__Historian](https://github.com/owasp-sbot/Issues-FS__Dev__Role__Historian) | Historian agent -- project narrative, timelines |
| [Issues-FS__Dev__Role__Journalist](https://github.com/owasp-sbot/Issues-FS__Dev__Role__Journalist) | Journalist agent -- daily briefs, articles, interviews |
| [Issues-FS__Dev__Role__Conductor](https://github.com/owasp-sbot/Issues-FS__Dev__Role__Conductor) | Conductor agent -- workflow orchestration, priority management |

### Human

| Repository | Description |
|-----------|-------------|
| [Issues-FS__Dev__Human__Dinis_Cruz](https://github.com/owasp-sbot/Issues-FS__Dev__Human__Dinis_Cruz) | Stakeholder repo for Dinis Cruz -- vision, priorities, feedback |

## How It Works

The agents collaborate through Issues-FS itself. Each role repo contains a `.issues/` directory where tasks, decisions, handoffs, and knowledge requests are stored as graph nodes. This creates a self-referential system: the issue tracker tracks its own development.

A typical workflow:

1. The **Conductor** reviews open issues across all repos and assigns priorities
2. The **Architect** creates an ADR (Architecture Decision Record) proposing a design change
3. The **Dev** implements the change, creating task issues to track progress
4. The **QA** agent runs test plans and reports defects as issues
5. The **Librarian** ensures the resulting documentation is catalogued and cross-referenced
6. The **Journalist** writes a daily brief summarizing the day's activity
7. The **Historian** weaves completed work into the project narrative

All of this coordination happens through `.issues/` directories -- no external project management tool required. Issues link to each other via graph edges (`blocks`, `depends_on`, `supersedes`), forming a navigable knowledge graph across the entire ecosystem.

## Recent Highlights

- **P0 Double-Path Bug Fix** -- A critical bug was discovered where `Path__Handler__Graph_Node` doubled the `.issues/` prefix, causing the CLI to look in `.issues/.issues/` instead of `.issues/`. All 552+ tests passed because both writes and reads went through the same doubled path, masking the bug. The fix restored real-world CLI functionality across all repositories.

- **ChatGPT Voice Interview Experiment** -- The Journalist agent briefed ChatGPT's voice mode to conduct a stakeholder interview with Dinis Cruz. This demonstrated a novel pattern: an AI agent delegating to another AI system to interact with a human, then processing the transcript back into the knowledge graph. See the [LinkedIn article](https://www.linkedin.com/pulse/i-was-just-interviewed-chatgpt-behalf-one-my-claude-7427021579454230528).

- **Fractal Knowledge Capture** -- The stakeholder's vision for Issues-FS centers on fractal knowledge capture: every interaction, decision, and artifact is stored in the graph at the appropriate level of detail, from high-level project narratives down to individual commit rationales. The system captures not just what was decided, but why, by whom, and what alternatives were considered.

## Getting Started

### Clone with All Submodules

```bash
git clone --recurse-submodules https://github.com/owasp-sbot/Issues-FS__Dev.git
cd Issues-FS__Dev
```

### If Already Cloned Without Submodules

```bash
git submodule update --init --recursive
```

### Install the Core Library

```bash
pip install issues-fs
```

### Install the CLI

```bash
pip install issues-fs-cli
```

### Explore Issues in Any Repo

```bash
cd modules/Issues-FS
issues-fs list
```

## Project Structure

```
Issues-FS__Dev/
├── modules/
│   ├── Issues-FS/                          # Core library
│   ├── Issues-FS__CLI/                     # Command-line interface
│   ├── Issues-FS__Docs/                    # Documentation
│   ├── Issues-FS__Service/                 # Web service
│   ├── Issues-FS__Service__UI/             # Web UI
│   └── Issues-FS__Service__Client__Python/ # Python client
├── roles/
│   ├── Issues-FS__Dev__Role__Dev/          # Dev agent
│   ├── Issues-FS__Dev__Role__Architect/    # Architect agent
│   ├── Issues-FS__Dev__Role__QA/           # QA agent
│   ├── Issues-FS__Dev__Role__AppSec/       # AppSec agent
│   ├── Issues-FS__Dev__Role__DevOps/       # DevOps agent
│   ├── Issues-FS__Dev__Role__Librarian/    # Librarian agent
│   ├── Issues-FS__Dev__Role__Cartographer/ # Cartographer agent
│   ├── Issues-FS__Dev__Role__Historian/    # Historian agent
│   ├── Issues-FS__Dev__Role__Journalist/   # Journalist agent
│   └── Issues-FS__Dev__Role__Conductor/    # Conductor agent
├── humans/
│   └── Issues-FS__Dev__Human__Dinis_Cruz/  # Stakeholder
└── docs/                                   # Dev-level assessments and reports
```

## License

Code is licensed under the [Apache License 2.0](LICENSE). Documentation and knowledge content are published under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).

## Links

- [Issues-FS on PyPI](https://pypi.org/project/issues-fs/)
- [Issues-FS CLI on PyPI](https://pypi.org/project/issues-fs-cli/)
- [OWASP-SBOT GitHub Organization](https://github.com/owasp-sbot)
- [LinkedIn: "I Was Just Interviewed by ChatGPT on Behalf of One of My Claude Code Agents"](https://www.linkedin.com/pulse/i-was-just-interviewed-chatgpt-behalf-one-my-claude-7427021579454230528)
