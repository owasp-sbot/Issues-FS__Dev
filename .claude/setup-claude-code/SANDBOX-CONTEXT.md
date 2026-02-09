# Sandbox Execution Environment — Context for Claude Code

> **This file exists so that you (Claude Code) understand the security sandbox you are running inside.**
> Read this when you encounter permission errors, when planning commands that touch the filesystem,
> or when the user asks about the execution environment.

---

## What Is This?

You are running as a **dedicated, unprivileged macOS user** called `claude-code` (not as the developer's main user account). This is an intentional security measure that restricts your filesystem access and available executables to a tightly scoped set.

This means:

- You **cannot** access most of the developer's home directory (`/Users/diniscruz`).
- You **can only** read/write to explicitly ACL'd project directories.
- You **can only** execute commands that have been symlinked into your restricted `PATH`.
- You have **no** access to SSH keys, shell history, credentials, other projects, or system admin tools.

**This is by design. Do not attempt to work around these restrictions.**

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

### No Access (permission will be denied)

Everything else, including but not limited to:

- `/Users/diniscruz/.ssh/` — SSH keys
- `/Users/diniscruz/.zsh_history` — shell history
- `/Users/diniscruz/Desktop/`, `Documents/`, `Downloads/`
- `/Users/diniscruz/.env`, `.npmrc`, `.gitconfig` — credentials and configs
- Any other project directories under `/Users/diniscruz/_dev/` not listed above

---

## Available Commands

Your `PATH` only includes a restricted set of executables. These are the commands you can use:

**Core tools:** `echo`, `ls`, `find`, `cat`, `head`, `tail`, `grep`, `awk`, `sed`, `sort`, `wc`, `xargs`, `diff`, `test`, `mkdir`, `cp`, `mv`, `rm`, `touch`, `chmod`

**Development:** `git`, `python3`, `python`, `pip`, `poetry`, `pytest`, `node`, `npm`

### Commands you DO NOT have access to

`curl`, `wget`, `ssh`, `scp`, `sudo`, `su`, `brew`, `nc`, `nmap`, `dd`, `diskutil`, `dscl`, `open`, and any other command not explicitly listed above.

If you need a command that isn't available, tell the user and suggest they add it to `CC_ALLOWED_EXECUTABLES` in `config.env` and re-run `setup-claude-code-user.sh`.

---

## Diagnosing Permission Errors

When you encounter a `Permission denied` error, follow this decision tree:

### 1. "Permission denied" when reading/listing a directory

**Likely cause:** The directory is outside your ACL'd access map.

**Check:** Is the path under one of your R/W or R/O directories listed above?

- **No** → This is expected. You don't have access. Tell the user: _"This path is outside my sandbox. I only have access to [list R/W dirs]. If you need me to access this, add it to `CC_RW_DIRECTORIES` or `CC_RO_DIRECTORIES` in `config.env` and run `sudo ./refresh-acls.sh`."_
- **Yes** → ACLs may not have propagated to new files. Tell the user: _"This file may have been created after the ACLs were set. Run `sudo ./refresh-acls.sh` to re-apply permissions."_

### 2. "Permission denied" when writing/creating a file

**Likely cause:** The directory is R/O, or ACL inheritance didn't propagate.

**Check:** Is the target directory in your R/W list or your R/O list?

- **R/O** → You cannot write here by design. If writing is needed (e.g., installing packages into the venv), tell the user to move this path from `CC_RO_DIRECTORIES` to `CC_RW_DIRECTORIES` in `config.env`.
- **R/W** → ACL inheritance issue. Tell the user to run `sudo ./refresh-acls.sh`.

### 3. "command not found"

**Likely cause:** The command is not in your restricted `PATH`.

**What to do:** Tell the user which command you need and suggest they add it to `CC_ALLOWED_EXECUTABLES` in `config.env` and re-run setup.

### 4. Git push/pull authentication failures

**Likely cause:** You are running as `claude-code`, which has its own (empty) git config and no SSH keys or credential helpers.

**What to do:** Local git operations (`diff`, `add`, `commit`, `stash`, `log`, `status`, `checkout`) work fine. For push/pull, tell the user to either perform those from their main account or set up a deploy key for the `claude-code` user.

### 5. Python/pytest can't find modules

**Likely cause:** The virtual environment path might not be accessible, or the Python path might not resolve.

**Troubleshooting steps:**
1. Verify the venv is in your R/O access list: `ls /Users/diniscruz/Library/Caches/pypoetry/virtualenvs/issues-fs-dev-1uzJze9o-py3.12/bin/python`
2. If that fails, ACLs need refreshing.
3. Use the full venv python path for running tests: `/Users/diniscruz/Library/Caches/pypoetry/virtualenvs/issues-fs-dev-1uzJze9o-py3.12/bin/python -m pytest`

---

## Important Behavioral Rules

1. **Never attempt to escalate privileges.** Don't try `sudo`, don't try to access `/etc/sudoers`, don't try to modify your own PATH or user account.

2. **Never search broadly outside the project.** Commands like `find /Users/diniscruz -name ...` will mostly fail and waste time. Always scope your searches to the project directory.

3. **Use absolute paths for the venv Python.** The system `python3` may not have the project's dependencies. Use the full venv path.

4. **When you hit a permission error, explain it clearly.** Don't retry the same command. Diagnose it using the decision tree above and tell the user exactly what to do.

5. **Don't attempt to install packages globally.** `pip install` without the venv prefix will fail or install to the wrong location. Always use `poetry run` or the venv's pip.

---

## Configuration Files Reference

All sandbox configuration lives in:

```
.claude/setup-exec-environment/
├── config.env                          # Central config: paths, users, executables
├── setup-claude-code-user.sh           # Creates the sandbox user + ACLs
├── run-claude-code.sh                  # Launches Claude Code in the sandbox
├── verify-sandbox.sh                   # Tests that permissions are correct
├── refresh-acls.sh                     # Re-applies ACLs (run after file changes)
├── teardown-claude-code-user.sh        # Removes the sandbox completely
├── claude-settings.json                # Application-level permission allowlist
├── SANDBOX-CONTEXT.md                  # This file (context for Claude Code)
└── Claude-Code-Sandbox-Guide.md        # Full documentation for the developer
```

### How to tell the user to fix things

When directing the user to fix configuration, always reference the specific file and variable:

- **Add a project directory:** "Add the path to `CC_RW_DIRECTORIES` in `.claude/setup-exec-environment/config.env`, then run `sudo .claude/setup-exec-environment/refresh-acls.sh`"
- **Add a command:** "Add `<command>` to `CC_ALLOWED_EXECUTABLES` in `.claude/setup-exec-environment/config.env`, then re-run `sudo .claude/setup-exec-environment/setup-claude-code-user.sh`"
- **Fix permissions on new files:** "Run `sudo .claude/setup-exec-environment/refresh-acls.sh`"

---

## Quick Self-Test

If you want to verify your access is working, try these commands:

```bash
# Should succeed (R/W project dir)
ls /Users/diniscruz/_dev/owasp-sbot/Issues-FS__Dev/

# Should succeed (R/O venv)
ls /Users/diniscruz/Library/Caches/pypoetry/virtualenvs/issues-fs-dev-1uzJze9o-py3.12/bin/python

# Should FAIL (no access to home dir root)
ls /Users/diniscruz/Desktop/

# Should FAIL (no access to SSH)
ls /Users/diniscruz/.ssh/

# Should work (allowed command)
git --version

# Should FAIL (blocked command)
curl --version
```

If any of the "should succeed" commands fail, tell the user to run `sudo .claude/setup-exec-environment/refresh-acls.sh`.
