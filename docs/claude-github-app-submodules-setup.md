# Claude Code GitHub App with Git Submodules: Setup, Security, and Why It Matters

**Issues-FS Ecosystem — February 2026**

---

## Overview

This document explains how the Issues-FS project uses the **Claude Code GitHub App** to give an AI agent controlled access to a multi-repo ecosystem managed through git submodules. It covers the setup, why this approach is important, and how its security model compares to running Claude Desktop or Claude Code locally on a developer's machine.

---

## The Architecture

### Issues-FS__Dev: The Orchestration Repo

`Issues-FS__Dev` is the top-level development repo for the Issues-FS ecosystem. It doesn't contain the main application code itself — instead, it orchestrates **15 submodule repos** that each serve a distinct purpose:

**Modules (application code):**

| Submodule | Purpose |
|-----------|---------|
| `modules/Issues-FS` | Core library |
| `modules/Issues-FS__CLI` | Command-line interface |
| `modules/Issues-FS__Docs` | Documentation |
| `modules/Issues-FS__Service` | Backend service |
| `modules/Issues-FS__Service__Client__Python` | Python client for the service |
| `modules/Issues-FS__Service__UI` | Frontend UI |

**Roles (AI agent role definitions):**

| Submodule | Purpose |
|-----------|---------|
| `roles/Issues-FS__Dev__Role__DevOps` | CI/CD, releases, repo scaffolding |
| `roles/Issues-FS__Dev__Role__Dev` | Feature development |
| `roles/Issues-FS__Dev__Role__Architect` | System architecture |
| `roles/Issues-FS__Dev__Role__Conductor` | Workflow orchestration |
| `roles/Issues-FS__Dev__Role__Librarian` | Documentation and knowledge management |
| `roles/Issues-FS__Dev__Role__Cartographer` | Codebase mapping |
| `roles/Issues-FS__Dev__Role__AppSec` | Application security |
| `roles/Issues-FS__Dev__Role__Historian` | Change history and context |
| `roles/Issues-FS__Dev__Role__Journalist` | Status reporting |

All submodules track the `dev` branch as their primary development branch.

### The Claude Code GitHub App

The [Claude Code GitHub App](https://github.com/apps/claude) (by Anthropic) allows Claude to operate on GitHub repositories directly — responding to issues, creating pull requests, reviewing code, and making changes. It runs in a **server-side sandbox** (a containerized Linux environment) that is provisioned per-session.

The key configuration is **repository access**. The app is installed on the `owasp-sbot` GitHub organisation with "Only select repositories" enabled. This means Claude can only access repos that have been explicitly added to the app's installation.

---

## How Submodule Access Works

### The Problem

When the Claude Code GitHub App is given access to `Issues-FS__Dev` (the parent repo), it clones that repo into its sandbox. However, the 15 submodule directories are **empty** — git submodules are pointers, not embedded code. To read or modify submodule content, the app needs permission to clone those repos too.

Additionally, the `.gitmodules` file uses SSH URLs (`git@github.com:owasp-sbot/...`), but the server-side sandbox authenticates via HTTPS using the GitHub App's installation token. Submodule init fails unless the URLs are rewritten.

### The Solution

1. **Grant the GitHub App access to submodule repos** — In the app's installation settings, add each submodule repo (or select "All repositories" for the organisation).

2. **Rewrite SSH URLs to HTTPS at runtime** — Configure git to translate SSH URLs:
   ```bash
   git config url."https://github.com/".insteadOf "git@github.com:"
   ```

3. **Clone submodules on the `dev` branch** — Since all submodules track `dev`:
   ```bash
   git clone --branch dev https://github.com/owasp-sbot/<RepoName>.git <submodule-path>
   ```

4. **Ensure `.gitmodules` tracks `dev`** — Every submodule entry should have `branch = dev` set so that `git submodule update --remote` checks out the correct branch.

### What This Enables

With submodule access configured, Claude can:

- Read role definitions (like `ROLE.md` in each role repo) to understand its responsibilities
- Review and modify application code across the full ecosystem
- Run cross-repo health audits (as defined by the DevOps role)
- Create commits and pull requests in submodule repos
- Understand the full project structure when responding to issues or PRs

---

## Why This Matters

### 1. Multi-Repo Visibility

Most real-world projects span multiple repositories. Without submodule access, an AI agent can only see the orchestration repo — it's blind to the actual code, tests, CI pipelines, and documentation. Granting submodule access gives Claude the same cross-repo visibility that a human developer has when they run `git submodule update --init --recursive`.

### 2. Role-Based AI Agents

The Issues-FS ecosystem uses a **role-based agent model** where each "role" (DevOps, Dev, Architect, etc.) is defined in its own repo with a `ROLE.md` that describes the agent's identity, responsibilities, workflows, and integration points. Without access to these role repos, Claude cannot adopt these roles or follow their defined workflows.

### 3. Consistent Development Environment

By aligning all submodules to the `dev` branch and granting the app access, every Claude session starts from a consistent, known state. The agent works on the same branch that human developers use, and its changes integrate naturally into the existing development workflow.

### 4. Automated Cross-Repo Operations

Operations like repo health audits (checking that all repos have correct CI pipelines, package skeletons, and tests) require reading files across many repos. The DevOps role's runbooks are designed for exactly this kind of cross-repo automation — but they only work if the agent can actually access all the repos.

---

## Security Model: GitHub App vs Claude Desktop

### The Core Problem with Claude Desktop

When running Claude Desktop (the Electron app) or Claude Code (the CLI) locally on a developer's machine, Claude executes commands **as the developer's user account**. This means it inherits:

- Full filesystem access to the developer's home directory
- SSH keys (`~/.ssh/`)
- AWS, Docker, and other credentials
- Shell history (which may contain secrets)
- Access to every other project on the machine
- Full network access

Even with Claude Code's application-level permission allowlist (`.claude.json`), this is a **single layer of defense** that operates at the application level. A prompt injection, a confused model, or an application bug could bypass it.

The Issues-FS project documented two approaches to mitigate this on macOS:

| Approach | Mechanism | Limitation |
|----------|-----------|------------|
| **`sandbox-exec` profile** | macOS kernel-enforced deny rules on specific paths | Allow-by-default (necessary for Electron apps); can't easily restrict to only one project |
| **Dedicated macOS user** | Separate `claude-code` user with ACL-controlled access | Requires admin setup; ACL inheritance can be flaky; git push/pull needs separate credential setup |

Both approaches are **significant improvements** over running unsandboxed, but they share fundamental limitations:

1. **The agent runs on the developer's machine** — even with sandboxing, the blast radius of a compromise is the local machine.
2. **Difficult to restrict to specific repos** — filesystem sandboxing works on directory paths, not git repository boundaries. Restricting access to "only this repo" is awkward when repos share parent directories.
3. **Credentials are nearby** — even if blocked, SSH keys, AWS credentials, and keychains exist on the same machine. The attack surface is larger by definition.
4. **No audit trail beyond git** — local command execution isn't logged by GitHub. There's no external record of what the agent did outside of git commits.

### The GitHub App Advantage

The Claude Code GitHub App takes a fundamentally different approach: **the agent runs on Anthropic's infrastructure, not the developer's machine**.

| Property | Claude Desktop / Code (Local) | Claude Code GitHub App |
|----------|-------------------------------|----------------------|
| **Execution environment** | Developer's machine | Anthropic's server-side sandbox (containerized Linux) |
| **Filesystem scope** | Entire user home (sandboxing is opt-in, manual) | Only cloned repo content (sandboxed by default) |
| **Credential exposure** | SSH keys, AWS creds, keychains exist on same machine | No local credentials — only GitHub App installation token |
| **Repository access** | Anything the user can `cd` into | Only repos explicitly granted in GitHub App settings |
| **Network access** | Full (unless explicitly restricted) | Controlled by sandbox; no access to developer's internal network |
| **Blast radius of compromise** | Developer's machine + everything they can access | The specific GitHub repos granted to the app |
| **Audit trail** | Local shell history (if not cleared) | GitHub API audit log, commit history, PR activity |
| **Write restrictions** | None by default; requires manual sandbox setup | GitHub branch protection rules apply |
| **Setup effort** | Significant (sandbox profiles, ACLs, PATH restriction) | Click "Install" and select repos |

### Branch Protection as a Safety Net

A critical advantage mentioned by the project maintainer: even though the GitHub App has **write access** to repos (necessary for creating branches and PRs), GitHub's **branch protection rules** constrain what it can actually do:

- **The app can only push to branches** — it cannot push directly to `main` or `dev` if branch protection is enabled.
- **Changes must go through pull requests** — giving the maintainer review control before anything merges.
- **Force pushes can be blocked** — preventing history rewriting.
- **Status checks can be required** — ensuring CI passes before merge.

This means the GitHub App's write access is **scoped write access**, not unrestricted. The app can propose changes (branches, PRs), but the maintainer controls what gets merged. This is a much safer model than local execution where `git push --force origin main` is one confused model response away.

### The Trade-Off

The GitHub App approach isn't universally superior. There are trade-offs:

| Consideration | Local (Desktop/Code) | GitHub App |
|---------------|---------------------|------------|
| **Latency** | Instant file access | Must clone repos per session |
| **Interactive debugging** | Can run servers, open browsers, use debuggers | Limited to CLI tools in the sandbox |
| **Offline access** | Works without internet | Requires internet |
| **Custom tooling** | Full access to local dev tools | Only what's in the sandbox |
| **Cost** | Uses your machine's compute | Uses Anthropic's infrastructure |

For **code review, issue triage, cross-repo audits, documentation, and branch-based development**, the GitHub App is the better fit — it's more secure by default and easier to set up.

For **interactive debugging, running test servers, or tasks requiring local tools**, a sandboxed local setup may still be necessary.

---

## Recommended Configuration

### For the Issues-FS Ecosystem

1. **Grant the Claude Code GitHub App access to all `owasp-sbot` repos** — or at minimum, all repos referenced as submodules. This enables full cross-repo visibility.

2. **Ensure all submodules track `dev`** — every entry in `.gitmodules` should have `branch = dev`. This is now the case.

3. **Enable branch protection on `main` and `dev`** for all repos:
   - Require pull request reviews before merging
   - Require status checks (CI) to pass
   - Block force pushes
   - Optionally restrict who can push to `dev` directly

4. **Use the GitHub App for routine development tasks** — issue responses, code reviews, documentation, repo health audits, and role-based agent operations.

5. **Reserve local sandboxed execution for interactive tasks** — debugging, running test servers, performance profiling, and tasks that need the full local development environment.

---

## Summary

The Claude Code GitHub App with submodule access provides a **secure-by-default** way to give an AI agent visibility and write access across a multi-repo ecosystem. Compared to running Claude locally (even with careful sandboxing), the GitHub App model offers:

- **Stronger isolation** — the agent never touches the developer's machine
- **Granular access control** — per-repo, enforced by GitHub's permission system
- **Built-in audit trail** — all actions are visible in GitHub's activity log
- **Branch protection as a safety net** — write access is scoped to branches, not direct pushes to protected branches
- **Zero setup overhead** — select repos in a dropdown vs. configuring sandbox profiles, ACLs, and PATH restrictions

The project's experience with local sandboxing (both `sandbox-exec` and dedicated user approaches) demonstrated that while local isolation is possible, it is **complex to set up, fragile to maintain, and fundamentally limited** by the fact that the agent operates on the same machine as the developer's credentials. The GitHub App model sidesteps these problems entirely by moving execution off the developer's machine and into a controlled, ephemeral environment with GitHub-enforced access boundaries.

---

*Document generated from analysis of the Issues-FS__Dev repository structure, DevOps role definition, and sandbox configuration files.*
