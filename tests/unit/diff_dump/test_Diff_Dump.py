from unittest                                                                   import TestCase
from issues_fs_dev.diff_dump.Diff_Dump                                          import Diff_Dump


class test_Diff_Dump(TestCase):

    @classmethod
    def setUpClass(cls):
        cls.dumper = Diff_Dump()

    def test__get_submodules__returns_list(self):
        submodules = self.dumper.get_submodules()
        assert len(submodules) == 17                                            # All 17 submodules

    def test__get_submodules__includes_modules_and_roles(self):
        submodules = self.dumper.get_submodules()
        has_module = any(s.startswith('modules/') for s in submodules)
        has_role   = any(s.startswith('roles/')   for s in submodules)
        assert has_module is True
        assert has_role   is True

    def test__generate__produces_output(self):
        output = self.dumper.generate('HEAD~1', 'HEAD')
        assert 'Cross-Repo Diff' in output
        assert 'Main Repository' in output
        assert 'Total submodules changed' in output

    def test__generate__modules_only_flag(self):
        output_all     = self.dumper.generate('HEAD~3', 'HEAD', modules_only=False)
        output_modules = self.dumper.generate('HEAD~3', 'HEAD', modules_only=True)
        assert 'roles/' not in output_modules or 'Submodule: roles/' not in output_modules

    def test__get_submodule_commit__returns_hash(self):
        submodules = self.dumper.get_submodules()
        if len(submodules) > 0:
            commit = self.dumper.get_submodule_commit('HEAD', submodules[0])
            assert commit is not None
            assert len(commit) >= 7                                             # At least short hash length

    def test__run_git__handles_bad_command(self):
        result = self.dumper.run_git(['log', '--oneline', '-1', 'nonexistent_ref_xyz'])
        assert result is None                                                   # Should return None, not crash
