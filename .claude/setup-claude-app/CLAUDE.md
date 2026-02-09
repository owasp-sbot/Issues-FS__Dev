# CLAUDE.md — Issues-FS__Dev Project

## Execution Environment

**You are running inside a macOS `sandbox-exec` profile that restricts your filesystem access at the kernel level.**

Read `.claude/setup-exec-environment/SANDBOX-CONTEXT.md` immediately for:
- Your exact access map (which directories you can read/write vs read-only vs blocked)
- A decision tree for diagnosing every type of permission error
- How to instruct the user to update the sandbox profile
- Debugging tips for `Operation not permitted` errors

**Key rules:**
- Never search or operate outside `/Users/diniscruz/_dev/owasp-sbot/Issues-FS__Dev`
- Use the full venv Python path for running tests: `/Users/diniscruz/Library/Caches/pypoetry/virtualenvs/issues-fs-dev-1uzJze9o-py3.12/bin/python -m pytest`
- If you hit `Operation not permitted` or `command not found`, don't retry — diagnose it using `SANDBOX-CONTEXT.md` and tell the user exactly what to change in `claude-sandbox.sb`
- Sandbox violations are kernel-enforced and logged — there is no workaround, only configuration changes by the user

## Project Structure

- **Project root:** `~/_dev/owasp-sbot/Issues-FS__Dev`
- **Main module:** `modules/Issues-FS/` (this is the library source)
- **Tests:** `tests/`
- **Sandbox config:** `.claude/setup-exec-environment/` (sandbox profile, scripts, docs)

## Running Tests

```bash
# Preferred — uses the correct venv with all dependencies
/Users/diniscruz/Library/Caches/pypoetry/virtualenvs/issues-fs-dev-1uzJze9o-py3.12/bin/python -m pytest tests/ -x -v

# Alternative via poetry (if poetry is on PATH)
poetry run pytest tests/ -x -v
```

## Git Workflow

- Local git operations work normally: `git diff`, `git add`, `git commit`, `git stash`, `git log`, `git status`, `git checkout`
- `git push` and `git pull` may fail because `~/.ssh` and `~/.gitconfig` are outside the sandbox — ask the user to do these outside the sandbox or to add SSH access to the sandbox profile
- Always check `git diff --stat` before committing to review what changed

## Coding Conventions

- Follow existing code style and patterns in the codebase
- Run tests after making changes to verify nothing is broken
- Keep changes minimal and focused — don't refactor unrelated code
