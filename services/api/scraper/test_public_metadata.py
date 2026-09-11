import importlib.util
import pathlib
import unittest


SCRIPT = pathlib.Path(__file__).with_name("public_metadata.py")
SPEC = importlib.util.spec_from_file_location("public_metadata", SCRIPT)
MODULE = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(MODULE)


class PublicMetadataTest(unittest.TestCase):
    def test_parse_html_metadata_reads_open_graph_json_ld_and_relative_video(self):
        html = '''
          <meta property="og:title" content="公开教程">
          <meta property="og:video:url" content="/media/tutorial.mp4">
          <script type="application/ld+json">
          {"@type":"VideoObject","uploadDate":"2026-09-08T10:00:00Z",
           "interactionStatistic":[
             {"interactionType":"https://schema.org/LikeAction","userInteractionCount":101},
             {"interactionType":"https://schema.org/CommentAction","userInteractionCount":12},
             {"interactionType":"https://schema.org/ShareAction","userInteractionCount":3}
           ]}
          </script>
        '''

        self.assertEqual(
            MODULE.parse_html_metadata(html, "https://example.com/watch/1"),
            {
                "title": "公开教程",
                "play_url": "https://example.com/media/tutorial.mp4",
                "published_at": "2026-09-08T10:00:00+00:00",
                "likes": 101,
                "comments": 12,
                "shares": 3,
                "source_url": "https://example.com/watch/1",
            },
        )

    def test_parse_html_metadata_does_not_invent_play_url(self):
        html = '<meta property="og:title" content="没有视频地址">'

        metadata = MODULE.parse_html_metadata(html, "https://example.com/post/1")

        self.assertEqual(metadata["title"], "没有视频地址")
        self.assertNotIn("play_url", metadata)


if __name__ == "__main__":
    unittest.main()
