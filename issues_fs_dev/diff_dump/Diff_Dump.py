import subprocess
from pathlib                                                                    import Path


class Diff_Dump:                                                                # Cross-repo diff aggregation across submodules

    def __init__(self, repo_root=None):
        self.repo_root = Path(repo_root) if repo_root else self.find_repo_root()

    def find_repo_root(self):                                                   # Walk up to find Issues-FS__Dev root
        current = Path.cwd()
        while current != current.parent:
            if (current / '.gitmodules').exists():
                return current
            current = current.parent
        return Path.cwd()

    def get_submodules(self):                                                   # List all submodule paths
        result = self.run_git(['config', '--file', '.gitmodules',
                               '--get-regexp', 'path'], cwd=self.repo_root)
        if result is None:
            return []
        submodules = []
        for line in result.strip().split('\n'):
            if line:
                parts = line.split()
                if len(parts) >= 2:
                    submodules.append(parts[1])
        return sorted(submodules)

    def get_submodule_commit(self, ref, submodule_path):                        # Get the commit a submodule points to at a given ref
        result = self.run_git(['ls-tree', ref, submodule_path],
                              cwd=self.repo_root)
        if result is None:
            return None
        parts = result.strip().split()
        if len(parts) >= 3:
            return parts[2]                                                     # The commit hash
        return None

    def get_main_repo_log(self, from_ref, to_ref):                              # Get commit log for the main repo between two refs
        result = self.run_git(
            ['log', '--oneline', '--no-merges', f'{from_ref}..{to_ref}'],
            cwd=self.repo_root
        )
        return result or ''

    def get_main_repo_diff_stat(self, from_ref, to_ref):                        # Get diffstat for the main repo
        result = self.run_git(
            ['diff', '--stat', from_ref, to_ref],
            cwd=self.repo_root
        )
        return result or ''

    def get_submodule_log(self, submodule_path, from_commit, to_commit):        # Get commit log for a submodule between two commits
        sub_dir = self.repo_root / submodule_path
        if sub_dir.exists() is False:
            return None
        result = self.run_git(
            ['log', '--oneline', '--no-merges', f'{from_commit}..{to_commit}'],
            cwd=sub_dir
        )
        return result

    def get_submodule_diff(self, submodule_path, from_commit, to_commit,        # Get diff content for a submodule
                           full_diff=False):
        sub_dir = self.repo_root / submodule_path
        if sub_dir.exists() is False:
            return None
        if full_diff is True:
            cmd = ['diff', from_commit, to_commit]
        else:
            cmd = ['diff', '--stat', from_commit, to_commit]
        return self.run_git(cmd, cwd=sub_dir)

    def get_submodule_tags_at(self, submodule_path, commit):                    # Get tags pointing at a commit in a submodule
        sub_dir = self.repo_root / submodule_path
        if sub_dir.exists() is False:
            return []
        result = self.run_git(['tag', '--points-at', commit], cwd=sub_dir)
        if result is None:
            return []
        return [t.strip() for t in result.strip().split('\n') if t.strip()]

    def generate(self, from_ref, to_ref,                                        # Generate full cross-repo diff dump
                 include_stats    = True,
                 include_full_diff= False,
                 modules_only     = False):
        sections = []

        sections.append(f"# Cross-Repo Diff: {from_ref} .. {to_ref}")          # Header
        sections.append(f"Repository: Issues-FS__Dev")
        sections.append(f"{'=' * 80}\n")

        main_log = self.get_main_repo_log(from_ref, to_ref)                    # Main repo commits
        sections.append("## Main Repository Commits")
        sections.append("-" * 40)
        if main_log.strip():
            sections.append(main_log)
        else:
            sections.append("(no commits)")
        sections.append("")

        if include_stats is True:                                               # Main repo diffstat
            stat = self.get_main_repo_diff_stat(from_ref, to_ref)
            if stat.strip():
                sections.append("## Main Repository Diff Stats")
                sections.append("-" * 40)
                sections.append(stat)
                sections.append("")

        submodules = self.get_submodules()                                      # Per-submodule diffs
        changed_count = 0

        for sub_path in submodules:
            if modules_only is True:                                            # Filter to modules only
                if sub_path.startswith('modules/') is False:
                    continue

            old_commit = self.get_submodule_commit(from_ref, sub_path)
            new_commit = self.get_submodule_commit(to_ref  , sub_path)

            if old_commit is None or new_commit is None:
                continue
            if old_commit == new_commit:
                continue

            changed_count += 1
            old_short = old_commit[:8]
            new_short = new_commit[:8]

            old_tags = self.get_submodule_tags_at(sub_path, old_commit)         # Resolve tags for readability
            new_tags = self.get_submodule_tags_at(sub_path, new_commit)
            old_label = old_tags[0] if old_tags else old_short
            new_label = new_tags[0] if new_tags else new_short

            sections.append(f"## Submodule: {sub_path}")
            sections.append(f"   {old_label} -> {new_label}")
            sections.append("-" * 40)

            sub_log = self.get_submodule_log(sub_path, old_commit, new_commit)  # Submodule commit log
            if sub_log and sub_log.strip():
                sections.append("### Commits")
                sections.append(sub_log)
            else:
                sections.append("(unable to retrieve commit log)")

            if include_stats is True or include_full_diff is True:              # Submodule diff
                sub_diff = self.get_submodule_diff(
                    sub_path, old_commit, new_commit,
                    full_diff=include_full_diff
                )
                if sub_diff and sub_diff.strip():
                    label = "### Full Diff" if include_full_diff is True else "### Diff Stats"
                    sections.append(label)
                    sections.append(sub_diff)

            sections.append("")

        sections.append(f"\n{'=' * 80}")                                        # Summary
        sections.append(f"Total submodules changed: {changed_count} / {len(submodules)}")

        return '\n'.join(sections)

    def copy_to_clipboard(self, text):                                          # Copy text to clipboard if possible
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

    def run_git(self, args, cwd=None):                                          # Run a git command and return stdout
        try:
            result = subprocess.run(
                ['git'] + args,
                capture_output = True,
                text           = True,
                cwd            = str(cwd or self.repo_root),
                timeout        = 30
            )
            if result.returncode == 0:
                return result.stdout
            return None
        except (subprocess.TimeoutExpired, FileNotFoundError):
            return None
