import json
import os
import subprocess
from pathlib                                                                    import Path


TOPIC_MAP_FILE = Path(__file__).parent / 'topic_map.json'


class Context_Dump:                                                             # Gathers relevant source and docs for a topic

    def __init__(self, repo_root=None):
        self.repo_root = Path(repo_root) if repo_root else self.find_repo_root()
        self.topic_map = self.load_topic_map()

    def find_repo_root(self):                                                   # Walk up to find Issues-FS__Dev root
        current = Path.cwd()
        while current != current.parent:
            if (current / '.gitmodules').exists():
                return current
            current = current.parent
        return Path.cwd()

    def load_topic_map(self):                                                   # Load the Librarian-maintained topic map
        if TOPIC_MAP_FILE.exists() is True:
            with open(TOPIC_MAP_FILE) as f:
                return json.load(f)
        return {}

    def list_topics(self):                                                      # Return available topic names
        topics = self.topic_map.get('topics', {})
        result = []
        for name, config in topics.items():
            result.append((name, config.get('description', '')))
        return result

    def gather(self, topic,                                                     # Gather all relevant files for a topic
               include_code    = True,
               include_docs    = True,
               include_roles   = False,
               include_types   = True,
               max_files       = 50):
        sections    = []
        files_added = set()
        file_count  = 0

        always = self.topic_map.get('always_include', {})                       # Always-include docs
        for doc_path in always.get('docs', []):
            if file_count >= max_files:
                break
            full_path = self.repo_root / doc_path
            if full_path.exists() is True and doc_path not in files_added:
                sections.append(self.format_file(doc_path, full_path))
                files_added.add(doc_path)
                file_count += 1

        if include_types is True:                                               # Type safety docs (for coding sessions)
            type_safety = self.topic_map.get('type_safety', {})
            for doc_path in type_safety.get('docs', []):
                if file_count >= max_files:
                    break
                full_path = self.repo_root / doc_path
                if full_path.exists() is True and doc_path not in files_added:
                    sections.append(self.format_file(doc_path, full_path))
                    files_added.add(doc_path)
                    file_count += 1

        topic_config = self.topic_map.get('topics', {}).get(topic)              # Topic-specific content
        if topic_config is None:
            code_files = self.search_code_by_keyword(topic)                     # Fallback: search by keyword
            for rel_path, full_path in code_files:
                if file_count >= max_files:
                    break
                if rel_path not in files_added:
                    sections.append(self.format_file(rel_path, full_path))
                    files_added.add(rel_path)
                    file_count += 1
            return '\n'.join(sections)

        if include_docs is True:                                                # Topic docs
            for doc_path in topic_config.get('docs', []):
                if file_count >= max_files:
                    break
                full_path = self.repo_root / doc_path
                if full_path.exists() is True and doc_path not in files_added:
                    sections.append(self.format_file(doc_path, full_path))
                    files_added.add(doc_path)
                    file_count += 1

        if include_roles is True:                                               # Role files
            for role_path in topic_config.get('role_files', []):
                if file_count >= max_files:
                    break
                full_path = self.repo_root / role_path
                if full_path.exists() is True and role_path not in files_added:
                    sections.append(self.format_file(role_path, full_path))
                    files_added.add(role_path)
                    file_count += 1

        if include_code is True:                                                # Code files from configured modules
            modules  = topic_config.get('modules' , [])
            globs    = topic_config.get('code_globs', [])
            patterns = topic_config.get('code_patterns', [])

            for module_path in modules:                                         # Search by glob patterns
                module_dir = self.repo_root / module_path
                if module_dir.exists() is False:
                    continue
                for glob_pattern in globs:
                    if file_count >= max_files:
                        break
                    for match in sorted(module_dir.rglob(glob_pattern)):
                        if file_count >= max_files:
                            break
                        if match.is_file() is False:
                            continue
                        rel = str(match.relative_to(self.repo_root))
                        if rel not in files_added:
                            sections.append(self.format_file(rel, match))
                            files_added.add(rel)
                            file_count += 1

            for module_path in modules:                                         # Search by grep patterns
                module_dir = self.repo_root / module_path
                if module_dir.exists() is False:
                    continue
                for pattern in patterns:
                    if file_count >= max_files:
                        break
                    grep_matches = self.grep_files(module_dir, pattern)
                    for match_path in grep_matches:
                        if file_count >= max_files:
                            break
                        rel = str(match_path.relative_to(self.repo_root))
                        if rel not in files_added:
                            sections.append(self.format_file(rel, match_path))
                            files_added.add(rel)
                            file_count += 1

        return '\n'.join(sections)

    def search_code_by_keyword(self, keyword):                                  # Fallback search across all modules
        results = []
        modules_dir = self.repo_root / 'modules'
        if modules_dir.exists() is False:
            return results
        grep_matches = self.grep_files(modules_dir, keyword)
        for match_path in grep_matches:
            rel = str(match_path.relative_to(self.repo_root))
            results.append((rel, match_path))
        return results

    def grep_files(self, search_dir, pattern):                                  # Use git grep or rg to find files matching pattern
        matches = []
        try:
            result = subprocess.run(                                            # Try ripgrep first, fall back to grep
                ['grep', '-rl', '--include=*.py', '--include=*.md', pattern, str(search_dir)],
                capture_output = True,
                text           = True,
                timeout        = 10
            )
            if result.returncode == 0:
                for line in result.stdout.strip().split('\n'):
                    if line:
                        matches.append(Path(line))
        except (subprocess.TimeoutExpired, FileNotFoundError):
            pass
        return sorted(matches)

    def format_file(self, rel_path, full_path):                                 # Format a file with a header for LLM context
        try:
            content = full_path.read_text(errors='replace')
        except Exception:
            content = '<unable to read file>'
        header    = f"{'=' * 80}"
        file_line = f"## File: {rel_path}"
        footer    = f"{'=' * 80}"
        return f"{header}\n{file_line}\n{header}\n{content}\n{footer}\n"

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
