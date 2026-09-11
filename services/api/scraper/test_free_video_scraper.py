import importlib.util
import contextlib
import io
import json
import pathlib
import random
import sys
import tempfile
import unittest
from unittest import mock


SCRIPT = pathlib.Path(__file__).with_name("free_video_scraper.py")
SPEC = importlib.util.spec_from_file_location("free_video_scraper", SCRIPT)
MODULE = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(MODULE)


class FreeVideoScraperTest(unittest.TestCase):
    def test_default_minimum_likes_is_disabled(self):
        self.assertEqual(MODULE.DEFAULT_MIN_LIKES, 0)

    def test_normalizes_pexels_video_with_generated_metrics(self):
        record = MODULE.normalize_pexels_video(
            {
                "id": 123,
                "url": "https://www.pexels.com/video/a-blue-ocean-123/",
                "video_files": [
                    {"quality": "sd", "link": "https://cdn.example/sd.mp4"},
                    {"quality": "hd", "link": "https://cdn.example/hd.mp4"},
                ],
            },
            random.Random(7),
        )

        self.assertEqual(record["platform"], "pexels")
        self.assertEqual(record["videoId"], "123")
        self.assertEqual(record["playUrl"], "https://cdn.example/hd.mp4")
        self.assertGreater(record["likes"], 0)
        self.assertGreater(record["comments"], 0)
        self.assertGreater(record["shares"], 0)

    def test_load_discovery_config_reads_queries_and_limits(self):
        with tempfile.TemporaryDirectory() as directory:
            path = pathlib.Path(directory) / "discovery.json"
            path.write_text(
                json.dumps(
                    {
                        "queries": ["AI"],
                        "platforms": ["youtube", "web"],
                        "perQueryLimit": 3,
                        "maxCandidates": 9,
                        "minLikes": 100,
                        "sinceDays": 30,
                    }
                ),
                encoding="utf-8",
            )

            config = MODULE._load_discovery(path)

        self.assertEqual(config.queries, ["AI"])
        self.assertEqual(config.platforms, ["youtube", "web"])
        self.assertEqual(config.per_query_limit, 3)
        self.assertEqual(config.max_candidates, 9)
        self.assertEqual(config.min_likes, 100)
        self.assertEqual(config.since_days, 30)

    def test_collect_discovered_merges_platform_and_web_candidates(self):
        search_payload = {
            "entries": [
                {
                    "id": "yt-1",
                    "title": "Popular",
                    "webpage_url": "https://youtube.com/watch?v=yt-1",
                }
            ]
        }
        detail = {
            "id": "yt-1",
            "title": "Popular",
            "webpage_url": "https://youtube.com/watch?v=yt-1",
            "url": "https://cdn.example/yt-1.mp4",
            "like_count": 101,
        }
        config = MODULE.DiscoveryConfig(
            queries=["AI"],
            platforms=["youtube", "web"],
            per_query_limit=2,
            max_candidates=4,
            min_likes=100,
            since_days=None,
        )
        with mock.patch.object(MODULE, "_extract_search", return_value=search_payload), mock.patch.object(
            MODULE, "search_public", return_value=["https://youtube.com/watch?v=yt-1"]
        ), mock.patch.object(MODULE, "_extract", return_value=detail):
            records = MODULE.collect_discovered(config)

        self.assertEqual(len(records), 1)
        self.assertEqual(records[0]["videoId"], "yt-1")

    def test_collect_discovered_uses_html_fallback_for_unknown_site(self):
        config = MODULE.DiscoveryConfig(
            queries=["AI"],
            platforms=["web"],
            per_query_limit=1,
            max_candidates=1,
            min_likes=100,
            since_days=None,
        )
        with mock.patch.object(
            MODULE, "search_public", return_value=["https://example.com/video/1"]
        ), mock.patch.object(
            MODULE,
            "_extract",
            side_effect=MODULE.subprocess.CalledProcessError(1, "yt_dlp"),
        ), mock.patch.object(
            MODULE,
            "extract_public_metadata",
            return_value={
                "title": "公开视频",
                "play_url": "https://cdn.example/video.mp4",
                "likes": 101,
                "source_url": "https://example.com/video/1",
            },
        ):
            records = MODULE.collect_discovered(config)

        self.assertEqual(len(records), 1)
        self.assertEqual(records[0]["platform"], "web")
        self.assertEqual(records[0]["likes"], 101)

    def test_query_config_min_likes_does_not_change_import(self):
        with tempfile.TemporaryDirectory() as directory:
            path = pathlib.Path(directory) / "discovery.json"
            path.write_text(
                json.dumps(
                    {
                        "queries": ["AI"],
                        "platforms": ["web"],
                        "minLikes": 250,
                        "sinceDays": 30,
                    }
                ),
                encoding="utf-8",
            )
            record = {"platform": "web", "videoId": "1", "likes": 251}
            imported = []
            with mock.patch.object(MODULE, "collect_discovered", return_value=[record]), mock.patch.object(
                MODULE, "_import_records", side_effect=lambda rows, root: imported.append(len(rows))
            ), mock.patch.object(sys, "argv", ["free_video_scraper.py", "--queries", str(path), "--import"]), contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(MODULE.main(), 0)

        self.assertEqual(imported, [1])


    def test_load_queries_accepts_platform_keyword_lists(self):
        with tempfile.TemporaryDirectory() as directory:
            path = pathlib.Path(directory) / "queries.json"
            path.write_text(
                json.dumps(
                    {
                        "youtube": ["AI 创作"],
                        "x": ["design"],
                        "douyin": ["摄影"],
                    }
                ),
                encoding="utf-8",
            )

            self.assertEqual(
                MODULE._load_queries(path),
                {"youtube": ["AI 创作"], "x": ["design"], "douyin": ["摄影"]},
            )

    def test_query_seed_uses_platform_search_entry(self):
        self.assertEqual(
            MODULE._query_seed("youtube", "AI 创作", 20), "ytsearch20:AI 创作"
        )
        self.assertIn(
            "q=design",
            MODULE._query_seed("x", "design", 20),
        )

    def test_collect_queries_expands_search_results_and_filters_recent_videos(self):
        search_result = {
            "entries": [
                {
                    "id": "yt-123",
                    "title": "Popular video",
                    "webpage_url": "https://youtube.com/watch?v=yt-123",
                }
            ]
        }
        detail = {
            "id": "yt-123",
            "title": "Popular video",
            "webpage_url": "https://youtube.com/watch?v=yt-123",
            "url": "https://cdn.example/video.mp4",
            "like_count": 1_500_000,
            "comment_count": 3200,
            "timestamp": 1756729800,
        }
        with mock.patch.object(
            MODULE,
            "_extract_search",
            return_value=search_result,
        ) as search_mock, mock.patch.object(MODULE, "_extract", return_value=detail) as detail_mock:
            records = MODULE.collect_queries(
                {"youtube": ["AI 创作"], "x": [], "douyin": []},
                minimum_likes=100,
                search_limit=20,
                since_days=3650,
            )

        self.assertEqual(len(records), 1)
        self.assertEqual(records[0]["videoId"], "yt-123")
        search_mock.assert_called_once_with("ytsearch20:AI 创作")
        detail_mock.assert_called_once_with("https://youtube.com/watch?v=yt-123")

    def test_collect_queries_skips_timed_out_search(self):
        with mock.patch.object(
            MODULE,
            "_extract_search",
            side_effect=MODULE.subprocess.TimeoutExpired("yt_dlp", 20),
        ):
            self.assertEqual(
                MODULE.collect_queries(
                    {"youtube": ["AI 创作"], "x": [], "douyin": []},
                    minimum_likes=100,
                    search_limit=20,
                ),
                [],
            )

    def test_youtube_extract_uses_android_client(self):
        completed = mock.Mock(stdout="{}")
        with mock.patch.object(MODULE.subprocess, "run", return_value=completed) as run_mock:
            MODULE._extract("https://www.youtube.com/watch?v=yt-123")

        command = run_mock.call_args.args[0]
        self.assertIn("--extractor-args", command)
        self.assertIn("youtube:player_client=android", command)

    def test_normalizes_youtube_metadata_for_importer(self):
        item = MODULE.normalize_entry(
            {
                "id": "yt-123",
                "title": "Popular video",
                "webpage_url": "https://youtube.com/watch?v=yt-123",
                "url": "https://cdn.example/video.mp4",
                "like_count": 1_500_000,
                "comment_count": 3200,
                "repost_count": 120,
                "timestamp": 1756729800,
            },
            "youtube",
        )

        self.assertEqual(
            item,
            {
                "platform": "youtube",
                "videoId": "yt-123",
                "title": "Popular video",
                "playUrl": "https://cdn.example/video.mp4",
                "url": "https://youtube.com/watch?v=yt-123",
                "likes": 1_500_000,
                "comments": 3200,
                "shares": 120,
                "publishedAt": "2025-09-01T12:30:00+00:00",
            },
        )

    def test_keeps_video_with_zero_likes_when_required_fields_exist(self):
        self.assertIsNotNone(
            MODULE.normalize_entry(
                {"id": "low", "title": "Low", "url": "https://example/low", "like_count": 0},
                "x",
            )
        )

    def test_keeps_exactly_100_likes_when_threshold_is_100(self):
        self.assertIsNotNone(
            MODULE.normalize_entry(
                {"id": "exact", "title": "Exact", "url": "https://example/exact", "like_count": 100},
                "youtube",
                100,
            )
        )

    def test_douyin_platform_is_preserved_even_for_cdn_playback_url(self):
        item = MODULE.normalize_entry(
            {
                "id": "dy-1",
                "desc": "Douyin popular",
                "url": "https://cdn.example/dy-1.mp4",
                "webpage_url": "https://www.douyin.com/video/dy-1",
                "digg_count": 2_000_000,
                "upload_date": "20250901",
            },
            "douyin",
        )

        self.assertEqual(item["platform"], "douyin")
        self.assertEqual(item["publishedAt"], "2025-09-01T00:00:00+00:00")
        self.assertIsNone(
            MODULE.normalize_entry(
                {"id": "missing", "title": "Missing", "like_count": 2_000_000},
                "douyin",
            )
        )


if __name__ == "__main__":
    unittest.main()
