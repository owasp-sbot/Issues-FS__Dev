from unittest                                                                   import TestCase
from pathlib                                                                    import Path
from issues_fs_dev_utils.utils.Dev_Repo                                         import find_dev_repo_root


class test_Dev_Repo(TestCase):

    def test__find_dev_repo_root__from_submodule(self):
        utils_dir = Path(__file__).parent.parent.parent.parent                  # The Utils repo root
        root = find_dev_repo_root(start_path=utils_dir)
        assert (root / '.gitmodules').exists() is True                          # Found the Dev repo
        assert (root / 'modules').exists()     is True                          # Has modules dir

    def test__find_dev_repo_root__from_cwd(self):
        root = find_dev_repo_root()
        assert (root / '.gitmodules').exists() is True

    def test__find_dev_repo_root__returns_path(self):
        root = find_dev_repo_root()
        assert isinstance(root, Path) is True
