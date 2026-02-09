# Sandbox Execution Environment — Context for Claude Code

> **This file exists so that you (Claude, running inside Claude.app) understand the security sandbox you are operating inside.**
> Read this when you encounter permission errors, when planning commands that touch the filesystem,
> or when the user asks about the execution environment.

---

## What Is This?

Claude.app has been launched inside a **macOS sandbox profile** (`sandbox-exec`) that uses a **deny-list** to block access to sensitive paths. Most system operations work normally, but specific directories containing credentials, personal files, and secrets are blocked at the kernel level.

This means:

- You **can** access your project directory and most system paths normally.
- You **cannot** access explicitly blocked sensitive paths (SSH keys, personal folders, credentials, shell history).
- Attempts to access blocked paths will fail with `Operation not permitted`.
- Network access is allowed (required for Claude API).
- All executables on the system PATH are available.

**The blocked paths are blocked by design. Do not attempt to work around these restrictions.**

---

## How the Sandbox Works

The sandbox uses macOS's `sandbox-exec` with a custom profile (`claude-sandbox.sb`). It runs as the same macOS user but with **kernel-enforced deny rules** on specific paths. The approach is: allow everything by default, then explicitly deny access to sensitive directories. The kernel blocks denied operations — no userspace workaround is possible.

The sandbox profile is at: `.claude/setup-exec-environment/claude-sandbox.sb`

---

## Your Access Map

### Full Access (everything works normally)

| Directory | Purpose |
|-----------|---------|
| `/Users/diniscruz/_dev/owasp-sbot/Issues-FS__Dev` | Main project workspace (R/W) |
| `/Users/diniscruz/Library/Caches/pypoetry/virtualenvs/...` | Python virtual environment |
| `/usr/bin`, `/bin`, `/usr/local/bin`, `/opt/homebrew/bin` | System executables |
| All other non-blocked system paths | Normal macOS operation |

### Blocked Paths (will fail with "Operation not permitted")

| Path | Why blocked |
|------|-------------|
| `~/.ssh/` | SSH keys and credentials |
| `~/.aws/credentials`, `~/.aws/config` | AWS credentials |
| `~/.gnupg/` | GPG keys |
| `~/.zsh_history`, `~/.bash_history` | Shell history (may contain secrets) |
| `~/.node_repl_history`, `~/.python_history` | REPL history |
| `~/Desktop/`, `~/Documents/`, `~/Downloads/` | Personal files |
| `~/Pictures/`, `~/Movies/`, `~/Music/` | Personal media |
| `~/.env`, `~/.npmrc`, `~/.pypirc`, `~/.netrc` | Secret environment/credential files |
| `~/.docker/config.json` | Docker credentials |
| `~/Library/Keychains/` | macOS keychain database |

---

## Diagnosing Permission Errors

When you encounter an error, follow this decision tree:

### 1. "Operation not permitted" when reading a path

**Likely cause:** The path is on the sandbox deny list.

**Check:** Is the path one of the blocked paths listed above (e.g., `~/.ssh`, `~/Desktop`, `~/.env`)?

- **Yes** → This is expected and by design. The sandbox blocks these sensitive paths. Tell the user:
  _"This path is blocked by the sandbox profile for security. If you need me to access it, remove the corresponding `(deny ...)` entry from `claude-sandbox.sb` in `.claude/setup-exec-environment/` and relaunch Claude.app."_

- **No** → This is unexpected. The deny-list sandbox allows everything not explicitly blocked. Check if the path is a symlink that resolves into a blocked directory. Tell the user to run `log stream --predicate 'process == "Claude" AND messageType == 16'` to see the exact denial.

### 2. "Operation not permitted" when writing/creating a file

**Likely cause:** The target path is in a blocked directory.

- **In a blocked dir** (e.g., `~/Desktop`, `~/Documents`) → By design. Tell the user which deny rule is blocking it.
- **In the project dir** → This should not happen with the deny-list approach. Check for symlinks resolving into blocked paths.
- **Anywhere else** → Most paths should be writable. Check the sandbox log for the specific denial reason.

### 4. Git push/pull authentication failures

**Likely cause:** Git credential helpers or SSH keys may be in paths the sandbox can't read (e.g., `~/.ssh/`, `~/.gitconfig`).

**What to do:** Local git operations (`diff`, `add`, `commit`, `stash`, `log`, `status`, `checkout`) work fine because they only need the `.git` directory inside the project. For push/pull, tell the user to either:
- Add `(allow file-read* (subpath (string-append (param "HOME") "/.ssh")))` to the sandbox profile (trades some security for convenience), or
- Perform push/pull outside the sandboxed session.

### 5. Python/pytest can't find modules

**Likely cause:** The virtual environment path might not be in the sandbox profile's allowed paths.

**Troubleshooting steps:**
1. Verify the venv is accessible: `ls /Users/diniscruz/Library/Caches/pypoetry/virtualenvs/issues-fs-dev-1uzJze9o-py3.12/bin/python`
2. If that fails with "Operation not permitted", the venv path needs to be added to the sandbox profile.
3. Use the full venv python path: `/Users/diniscruz/Library/Caches/pypoetry/virtualenvs/issues-fs-dev-1uzJze9o-py3.12/bin/python -m pytest`

### 6. Claude.app behaves unexpectedly

**Likely cause:** A deny rule is blocking a path the app legitimately needs.

**How to debug:** Run this in a separate terminal before launching Claude.app sandboxed:

```bash
log stream --predicate 'process == "Claude" AND messageType == 16'
```

This shows sandbox violations in real time. If the app misbehaves, the log will show exactly which path was denied, so you can adjust the sandbox profile.

---

## Important Behavioral Rules

1. **Never attempt to access paths outside the allowed list.** Commands like `find /Users/diniscruz -name ...` will mostly fail with "Operation not permitted" and waste time. Always scope searches to the project directory.

2. **Use absolute paths for the venv Python.** The system `python3` may not have the project's dependencies. Use the full venv path.

3. **When you hit a permission error, explain it clearly.** Don't retry the same command. Diagnose it using the decision tree above and tell the user exactly what to change in `claude-sandbox.sb`.

4. **Don't attempt to install packages globally.** `pip install` without the venv prefix will fail. Always use `poetry run` or the venv's pip.

5. **Remember: sandbox violations are logged.** The macOS kernel logs every denied operation. The user can review these in Console.app to understand what happened.

---

## Configuration Files Reference

All sandbox configuration lives in:

```
.claude/setup-exec-environment/
├── config.env                          # Central config: paths, app location
├── claude-sandbox.sb                   # macOS sandbox profile (kernel-enforced rules)
├── run-claude-sandboxed.sh             # Launches Claude.app inside the sandbox
├── setup-claude-code-user.sh           # (Alternative) Creates sandbox user + ACLs
├── run-claude-code.sh                  # (Alternative) Launches CLI claude in user sandbox
├── verify-sandbox.sh                   # Tests user-based sandbox permissions
├── refresh-acls.sh                     # Re-applies ACLs for user-based sandbox
├── teardown-claude-code-user.sh        # Removes user-based sandbox
├── claude-settings.json                # Application-level permission allowlist
├── SANDBOX-CONTEXT.md                  # This file (context for Claude)
└── Claude-Code-Sandbox-Guide.md        # Full documentation for the developer
```

### How to tell the user to fix things

When directing the user to fix configuration, always reference the specific file:

- **Unblock a path:** "Remove or comment out the corresponding `(deny ...)` entry in `claude-sandbox.sb` in `.claude/setup-exec-environment/`, then relaunch Claude.app with `./run-claude-sandboxed.sh`"
- **Block a new path:** "Add a `(deny file-read* file-write* (subpath \"/path/to/block\"))` entry to `claude-sandbox.sb`"
- **Block a sibling project:** "Add `(deny file-read* file-write* (subpath \"/Users/diniscruz/_dev/other-project\"))` to `claude-sandbox.sb`"
- **Debug sandbox failures:** "Run `log stream --predicate 'process == \"Claude\" AND messageType == 16'` to see which paths are being denied"

---

## Quick Self-Test

If you want to verify sandbox restrictions are active, try these commands:

```bash
# Should succeed (R/W project dir)
ls /Users/diniscruz/_dev/owasp-sbot/Issues-FS__Dev/

# Should succeed (R/O venv)
ls /Users/diniscruz/Library/Caches/pypoetry/virtualenvs/issues-fs-dev-1uzJze9o-py3.12/bin/python

# Should FAIL with "Operation not permitted" (no access to Desktop)
ls /Users/diniscruz/Desktop/

# Should FAIL (no access to SSH keys)
cat /Users/diniscruz/.ssh/id_rsa

# Should FAIL (no access to shell history)
cat /Users/diniscruz/.zsh_history
```

If the "should fail" commands succeed, the sandbox is not active — Claude.app may not have been launched via `run-claude-sandboxed.sh`. Note that with the deny-list approach, most paths work normally; only the specifically blocked paths should fail.
