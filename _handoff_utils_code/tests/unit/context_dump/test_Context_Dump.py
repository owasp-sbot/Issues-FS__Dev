from unittest                                                                   import TestCase
from issues_fs_dev_utils.context_dump.Context_Dump                              import Context_Dump


class test_Context_Dump(TestCase):

    @classmethod
    def setUpClass(cls):
        cls.dumper = Context_Dump()

    def test__list_topics__returns_configured_topics(self):
        topics = self.dumper.list_topics()
        assert len(topics) > 0
        names = [t[0] for t in topics]
        assert 'path'    in names
        assert 'graph'   in names
        assert 'storage' in names
        assert 'cli'     in names

    def test__list_topics__includes_descriptions(self):
        topics = self.dumper.list_topics()
        for name, desc in topics:
            assert len(desc) > 0

    def test__gather__known_topic__returns_content(self):
        output = self.dumper.gather('path', max_files=3)
        assert len(output)          > 0
        assert '## File:' in output                                             # Has file headers

    def test__gather__unknown_topic__falls_back_to_search(self):
        output = self.dumper.gather('xyznonexistenttopic123', max_files=3)
        assert output is not None                                               # Should not crash

    def test__gather__respects_max_files(self):
        output = self.dumper.gather('path', max_files=2)
        file_count = output.count('## File:')
        assert file_count <= 2

    def test__gather__no_code_flag(self):
        output_with    = self.dumper.gather('cli', include_code=True,  max_files=20)
        output_without = self.dumper.gather('cli', include_code=False, max_files=20)
        assert len(output_with) >= len(output_without)

    def test__load_topic_map__has_required_keys(self):
        topic_map = self.dumper.topic_map
        assert 'always_include' in topic_map
        assert 'type_safety'    in topic_map
        assert 'topics'         in topic_map
