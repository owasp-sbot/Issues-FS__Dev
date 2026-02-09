# CLAUDE.md — Issues-FS__Dev Project

## Execution Environment

**You are running inside a sandboxed macOS user account (`claude-code`) with restricted filesystem and executable access.**

Read `.claude/setup-exec-environment/SANDBOX-CONTEXT.md` for:
- Your exact access map (which directories you can read/write vs read-only vs no access)
- Available commands and what's blocked
- A decision tree for diagnosing permission errors
- How to instruct the user to fix permission issues

**Key rules:**
- Never search or operate outside `/Users/diniscruz/_dev/owasp-sbot/Issues-FS__Dev`
- Use the full venv Python path for running tests: `/Users/diniscruz/Library/Caches/pypoetry/virtualenvs/issues-fs-dev-1uzJze9o-py3.12/bin/python -m pytest`
- If you hit `Permission denied` or `command not found`, don't retry — diagnose it using `SANDBOX-CONTEXT.md` and tell the user exactly what config change is needed
- Never attempt to escalate privileges or access paths outside your sandbox

## Project Structure

- **Project root:** `~/_ dev/owasp-sbot/Issues-FS__Dev`
- **Main module:** `modules/Issues-FS/` (this is the library source)
- **Tests:** `tests/`

## Running Tests

```bash
# Preferred — uses the correct venv with all dependencies
/Users/diniscruz/Library/Caches/pypoetry/virtualenvs/issues-fs-dev-1uzJze9o-py3.12/bin/python -m pytest tests/ -x -v

# Alternative via poetry (if poetry is on PATH)
poetry run pytest tests/ -x -v
```

## Git Workflow

- Local git operations work normally: `git diff`, `git add`, `git stash`, `git status`, `git log`, `git checkout`
- `git push` and `git pull` require the user's credentials — if needed, ask the user to do these from their main account
- Always check `git diff --stat` before committing to review what changed

## Coding Conventions

- Follow existing code style and patterns in the codebase
- Run tests after making changes to verify nothing is broken
- Keep changes minimal and focused — don't refactor unrelated code
