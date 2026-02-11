import subprocess
from pathlib                                                                    import Path


def find_dev_repo_root(start_path=None):                                        # Find the Issues-FS__Dev root from anywhere in the tree
    """Walk up from start_path looking for a directory that has .gitmodules
    with multiple submodule entries (the Dev orchestration repo).
    Works from inside submodules, from the Dev repo itself, or from nested dirs."""
    current = Path(start_path) if start_path else Path.cwd()
    if current.is_file() is True:
        current = current.parent
    while current != current.parent:
        gitmodules = current / '.gitmodules'
        if gitmodules.exists() is True:
            content = gitmodules.read_text()
            if content.count('[submodule') >= 5:                                # The Dev repo has 17+ submodules
                return current
        current = current.parent
    return Path.cwd()                                                           # Fallback to cwd


def copy_to_clipboard(text):                                                    # Copy text to clipboard if possible
    for cmd in [['xclip', '-selection', 'clipboard'],
                ['xsel', '--clipboard', '--input'],
                ['pbcopy']]:
        try:
            process = subprocess.Popen(cmd, stdin=subprocess.PIPE)
            process.communicate(input=text.encode())
            if process.returncode == 0:
                return True
        except FileNotFoundError:
            continue
    return False
