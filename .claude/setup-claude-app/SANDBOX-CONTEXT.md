# Sandbox Execution Environment — Context for Claude Code

> **This file exists so that you (Claude, running inside Claude.app) understand the security sandbox you are operating inside.**
> Read this when you encounter permission errors, when planning commands that touch the filesystem,
> or when the user asks about the execution environment.

---

## What Is This?

Claude.app has been launched inside a **macOS sandbox profile** (`sandbox-exec`) that restricts your filesystem access to a tightly scoped set of directories. This is an intentional security measure applied at the OS level.

This means:

- You **cannot** access most of the developer's home directory (`/Users/diniscruz`).
- You **can only** read/write to explicitly allowed project directories.
- You **can only** read (not write) explicitly allowed read-only directories (e.g., virtual environments).
- Attempts to access anything outside the allowed paths will fail with `Operation not permitted` or `Permission denied`.
- Network access is allowed (required for Claude API), but filesystem access is locked down.

**This is by design. Do not attempt to work around these restrictions.**

---

## How the Sandbox Works

The sandbox uses macOS's `sandbox-exec` with a custom profile (`claude-sandbox.sb`). Unlike a separate user account, this runs as the same macOS user but with **kernel-enforced file access restrictions**. The kernel itself blocks disallowed operations — no userspace workaround is possible.

The sandbox profile is at: `.claude/setup-exec-environment/claude-sandbox.sb`

---

## Your Access Map

### Read/Write Access (you can read, create, modify, and delete files here)

| Directory | Purpose |
|-----------|---------|
| `/Users/diniscruz/_dev/owasp-sbot/Issues-FS__Dev` | Main project workspace |

### Read-Only Access (you can read and execute, but NOT write)

| Directory | Purpose |
|-----------|---------|
| `/Users/diniscruz/Library/Caches/pypoetry/virtualenvs/issues-fs-dev-1uzJze9o-py3.12` | Python virtual environment |

### Allowed Executable Paths (read + execute)

| Path | Contents |
|------|----------|
| `/usr/bin`, `/bin` | System utilities (ls, find, grep, sed, etc.) |
| `/usr/local/bin` | Homebrew-installed tools |
| `/opt/homebrew/bin`, `/opt/homebrew/Cellar` | Apple Silicon Homebrew |

### No Access (will fail with "Operation not permitted")

Everything else, including but not limited to:

- `/Users/diniscruz/.ssh/` — SSH keys
- `/Users/diniscruz/.zsh_history` — shell history
- `/Users/diniscruz/Desktop/`, `Documents/`, `Downloads/`
- `/Users/diniscruz/.env`, `.npmrc`, `.gitconfig` — credentials and configs
- Any other project directories under `/Users/diniscruz/_dev/` not listed above
- `/Users/diniscruz/.zshrc`, `.bash_profile` — shell configs

---

## Diagnosing Permission Errors

When you encounter an error, follow this decision tree:

### 1. "Operation not permitted" or "Permission denied" when reading a path

**Likely cause:** The path is outside the sandbox profile's allowed list.

**Check:** Is the path under one of the R/W or R/O directories listed above?

- **No** → This is expected. The sandbox blocks it. Tell the user:
  _"This path is outside the sandbox. I only have access to [list allowed dirs]. To grant access, add the path to `claude-sandbox.sb` in `.claude/setup-exec-environment/` and relaunch Claude.app with the sandbox script."_

- **Yes** → The sandbox profile may need adjustment. The path might be a symlink that resolves outside the allowed tree, or a new subdirectory not covered. Tell the user:
  _"This should be accessible but isn't. Check if the path involves symlinks that resolve outside the sandbox. You may need to add the resolved path to `claude-sandbox.sb`."_

### 2. "Operation not permitted" when writing/creating a file

**Likely cause:** The target path is in a read-only area, or outside the sandbox entirely.

- **In R/O directory** → By design. If writing is needed (e.g., installing packages into the venv), tell the user to change the path from `file-read*` to `file-read* file-write*` in `claude-sandbox.sb`.
- **In R/W directory** → Check for symlinks resolving outside the allowed tree.
- **Outside all allowed paths** → The sandbox is working correctly. Tell the user what path to add.

### 3. "Operation not permitted" on a command (not a file)

**Likely cause:** The executable is in a directory not allowed in the sandbox profile.

Common cases:
- **Homebrew on Intel Mac:** Tools might be in `/usr/local/bin` (should be allowed by default).
- **Homebrew on Apple Silicon:** Tools in `/opt/homebrew/bin` (should be allowed by default).
- **nvm-installed Node:** Might be in `~/.nvm/versions/...` which is NOT allowed by default. Tell the user to uncomment the nvm line in `claude-sandbox.sb`.
- **pyenv Python:** Might be in `~/.pyenv/versions/...` which is NOT allowed. User needs to add it.

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

### 6. Claude.app itself crashes or fails to start

**Likely cause:** The sandbox profile is too restrictive for the Electron app's needs.

The profile needs to allow access to:
- `~/Library/Caches/Claude` and `~/Library/Application Support/Claude` (R/W)
- `~/Library/Preferences` (R/O)
- `/private/tmp` and `/private/var/folders` (R/W for temp files)

If Claude.app won't start, check the system console (`Console.app`) for `sandbox` violation messages. These will tell you exactly which path was denied.

**How to debug:** Run `log stream --predicate 'process == "Claude" AND messageType == 16'` in a separate terminal to see sandbox violations in real time.

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

- **Add a project directory:** "Add a `(allow file-read* file-write* (subpath \"/path/to/dir\"))` entry to `claude-sandbox.sb` in `.claude/setup-exec-environment/`, then relaunch Claude.app with `./run-claude-sandboxed.sh`"
- **Add read-only access:** "Add a `(allow file-read* (subpath \"/path/to/dir\"))` entry to `claude-sandbox.sb`"
- **Allow an executable path:** "Add a `(allow file-read* process-exec (subpath \"/path/to/bin\"))` entry to `claude-sandbox.sb`"
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

If the "should fail" commands succeed, the sandbox is not active — Claude.app may not have been launched via `run-claude-sandboxed.sh`.
