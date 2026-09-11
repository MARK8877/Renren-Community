import importlib.util
import pathlib
import unittest


SCRIPT = pathlib.Path(__file__).with_name("public_search.py")
SPEC = importlib.util.spec_from_file_location("public_search", SCRIPT)
MODULE = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(MODULE)


class PublicSearchTest(unittest.TestCase):
    def test_parse_results_returns_unique_http_links_in_order(self):
        html = '''<a class="result__a" href="//example.com/a">A</a>
                  <a class="result__a" href="https://example.com/a">duplicate</a>
                  <a class="result__a" href="https://example.com/b">B</a>'''

        self.assertEqual(
            MODULE.parse_result_links(html, 10),
            ["https://example.com/a", "https://example.com/b"],
        )

    def test_parse_results_skips_non_http_links_and_applies_limit(self):
        html = '''<a class="result__a" href="javascript:void(0)">bad</a>
                  <a class="result__a" href="https://example.com/a">A</a>
                  <a class="result__a" href="https://example.com/b">B</a>'''

        self.assertEqual(MODULE.parse_result_links(html, 1), ["https://example.com/a"])


if __name__ == "__main__":
    unittest.main()
