#!/usr/bin/env python3
"""Free public-page video scraper backed by yt-dlp.

The script never downloads media. It reads public metadata, normalizes it to
the existing Go importer shape, and optionally imports the result into MySQL.
"""

import argparse
import datetime as dt
import hashlib
import json
import os
import pathlib
import random
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request
from dataclasses import dataclass
from typing import Any, Dict, Iterable, List, Optional
from urllib.parse import quote, quote_plus, urlparse

SCRAPER_DIR = pathlib.Path(__file__).resolve().parent
if str(SCRAPER_DIR) not in sys.path:
    sys.path.insert(0, str(SCRAPER_DIR))
from public_metadata import PublicMetadataError, extract_public_metadata
from public_search import PublicSearchError, search_public


DEFAULT_MIN_LIKES = 0
DEFAULT_SEARCH_LIMIT = 20
DEFAULT_SINCE_DAYS = 30
DEFAULT_REQUEST_TIMEOUT_SECONDS = 20
PLATFORMS = ("youtube", "x", "douyin")
DISCOVERY_PLATFORMS = PLATFORMS + ("web",)
IMPORT_PLATFORMS = DISCOVERY_PLATFORMS + ("pexels",)
PEXELS_POPULAR_ENDPOINT = "https://api.pexels.com/v1/videos/popular?per_page=%d"


@dataclass(frozen=True)
class DiscoveryConfig:
    queries: List[str]
    platforms: List[str]
    per_query_limit: int = DEFAULT_SEARCH_LIMIT
    max_candidates: int = 200
    min_likes: int = DEFAULT_MIN_LIKES
    since_days: Optional[int] = DEFAULT_SINCE_DAYS


_LAST_REQUEST_BY_HOST: Dict[str, float] = {}


def _respect_host_rate_limit(target: str) -> None:
    if target.startswith("ytsearch"):
        host = "youtube.com"
    else:
        host = urlparse(target).netloc.lower()
    if not host:
        return
    now = time.monotonic()
    elapsed = now - _LAST_REQUEST_BY_HOST.get(host, 0.0)
    if elapsed < 1.0:
        time.sleep(1.0 - elapsed)
    _LAST_REQUEST_BY_HOST[host] = time.monotonic()


def _first_text(item: Dict[str, Any], *keys: str) -> str:
    for key in keys:
        value = item.get(key)
        if isinstance(value, str) and value.strip():
            return value.strip()
    return ""


def _number(item: Dict[str, Any], *keys: str) -> int:
    for key in keys:
        value = item.get(key)
        try:
            if value is not None:
                return max(0, int(float(value)))
        except (TypeError, ValueError):
            continue
    return 0


def _published_at(value: Any) -> Optional[str]:
    if value is None:
        return None
    if isinstance(value, str) and len(value) == 8 and value.isdigit():
        try:
            return dt.datetime.strptime(value, "%Y%m%d").replace(
                tzinfo=dt.timezone.utc
            ).isoformat()
        except ValueError:
            return None
    try:
        timestamp = float(value)
        if timestamp > 1e12:
            timestamp /= 1000
        return dt.datetime.fromtimestamp(timestamp, dt.timezone.utc).isoformat()
    except (TypeError, ValueError, OverflowError, OSError):
        pass
    if isinstance(value, str):
        try:
            parsed = dt.datetime.fromisoformat(value.replace("Z", "+00:00"))
            if parsed.tzinfo is None:
                parsed = parsed.replace(tzinfo=dt.timezone.utc)
            return parsed.astimezone(dt.timezone.utc).isoformat()
        except ValueError:
            return None
    return None


def normalize_entry(
    item: Dict[str, Any], platform: str, minimum_likes: int = DEFAULT_MIN_LIKES
) -> Optional[Dict[str, Any]]:
    platform = platform.lower().strip()
    if platform == "tiktok":
        platform = "douyin"
    likes = _number(item, "like_count", "likes", "likesCount", "digg_count", "diggCount")
    video_id = _first_text(item, "id", "video_id", "videoId", "aweme_id", "tweet_id")
    title = _first_text(item, "title", "description", "desc", "text", "caption")
    play_url = _first_text(item, "url", "play_url", "playUrl", "video_url", "videoUrl")
    source_url = _first_text(
        item, "webpage_url", "webpageUrl", "original_url", "post_url", "postUrl", "url"
    )
    if not platform or not video_id or not title or not play_url:
        return None
    record: Dict[str, Any] = {
        "platform": platform,
        "videoId": video_id,
        "title": title,
        "playUrl": play_url,
        "url": source_url,
        "likes": likes,
        "comments": _number(item, "comment_count", "comments", "commentsCount", "reply_count"),
        "shares": _number(item, "repost_count", "retweet_count", "share_count", "shares"),
    }
    published = _published_at(
        item.get("timestamp")
        or item.get("upload_timestamp")
        or item.get("create_time")
        or item.get("publishedAt")
        or item.get("upload_date")
    )
    if published:
        record["publishedAt"] = published
    return record


def normalize_pexels_video(item: Dict[str, Any], rng: random.Random) -> Dict[str, Any]:
    video_id = str(item.get("id", "")).strip()
    source_url = _first_text(item, "url")
    files = [file for file in item.get("video_files", []) if isinstance(file, dict)]
    hd_files = [file for file in files if file.get("quality") == "hd"]
    candidates = hd_files or files
    play_file = max(
        candidates,
        key=lambda file: int(file.get("width") or 0) * int(file.get("height") or 0),
        default={},
    )
    play_url = _first_text(play_file, "link")
    slug = source_url.rstrip("/").rsplit("/", 1)[-1]
    if slug.endswith("-" + video_id):
        slug = slug[: -(len(video_id) + 1)]
    title = slug.replace("-", " ").strip().capitalize() or "Pexels video " + video_id
    return {
        "platform": "pexels",
        "videoId": video_id,
        "title": title,
        "playUrl": play_url,
        "url": source_url,
        "likes": rng.randint(120, 9800),
        "comments": rng.randint(8, 680),
        "shares": rng.randint(4, 420),
    }


def collect_pexels_videos(limit: int = 20) -> List[Dict[str, Any]]:
    if limit <= 0:
        return []
    request = urllib.request.Request(
        PEXELS_POPULAR_ENDPOINT % min(limit, 80),
        headers={
            "User-Agent": "CreatorHubPublicCollector/1.0",
            **({"Authorization": os.environ["PEXELS_API_KEY"]} if os.environ.get("PEXELS_API_KEY") else {}),
        },
    )
    try:
        with urllib.request.urlopen(request, timeout=DEFAULT_REQUEST_TIMEOUT_SECONDS) as response:
            payload = json.load(response)
    except (OSError, urllib.error.URLError, json.JSONDecodeError) as error:
        raise RuntimeError("Pexels public video request failed: %s" % type(error).__name__) from error
    videos = payload.get("videos", []) if isinstance(payload, dict) else []
    rng = random.Random()
    records = []
    for item in videos:
        if not isinstance(item, dict):
            continue
        record = normalize_pexels_video(item, rng)
        if record["videoId"] and record["playUrl"]:
            records.append(record)
    return records[:limit]


def _extract(seed: str) -> Dict[str, Any]:
    command = [
        sys.executable,
        "-m",
        "yt_dlp",
        "--dump-single-json",
        "--skip-download",
        "--no-playlist",
        "--no-warnings",
    ]
    if "youtube.com/" in seed or "youtu.be/" in seed:
        command.extend(["--extractor-args", "youtube:player_client=android"])
    command.append(seed)
    completed = subprocess.run(
        command,
        check=True,
        text=True,
        capture_output=True,
        timeout=DEFAULT_REQUEST_TIMEOUT_SECONDS,
    )
    return json.loads(completed.stdout)


def _extract_search(seed: str) -> Dict[str, Any]:
    """Return a flat list of public search results for a discovery seed."""
    command = [
        sys.executable,
        "-m",
        "yt_dlp",
        "--dump-single-json",
        "--flat-playlist",
        "--skip-download",
        "--no-warnings",
        seed,
    ]
    completed = subprocess.run(
        command,
        check=True,
        text=True,
        capture_output=True,
        timeout=DEFAULT_REQUEST_TIMEOUT_SECONDS,
    )
    return json.loads(completed.stdout)


def _entries(payload: Dict[str, Any]) -> Iterable[Dict[str, Any]]:
    entries = payload.get("entries")
    if isinstance(entries, list):
        return (item for item in entries if isinstance(item, dict))
    return (payload,)


def collect(seeds: Dict[str, List[str]], minimum_likes: int) -> List[Dict[str, Any]]:
    records: List[Dict[str, Any]] = []
    seen = set()
    for platform in PLATFORMS:
        for seed in seeds.get(platform, []):
            try:
                payload = _extract(seed)
            except (
                OSError,
                subprocess.CalledProcessError,
                subprocess.TimeoutExpired,
                json.JSONDecodeError,
            ) as error:
                print("skip %s (%s): %s" % (platform, seed, error), file=sys.stderr)
                continue
            for item in _entries(payload):
                record = normalize_entry(item, platform, minimum_likes)
                if not record:
                    continue
                key = (platform, record["videoId"])
                if key in seen:
                    continue
                seen.add(key)
                records.append(record)
    return records


def _query_seed(platform: str, query: str, search_limit: int) -> str:
    query = query.strip()
    if platform == "youtube":
        return "ytsearch%d:%s" % (search_limit, query)
    if platform == "x":
        return "https://x.com/search?q=%s&f=video" % quote_plus(query)
    return "https://www.douyin.com/search/%s?type=video" % quote(query)


def _entry_target(item: Dict[str, Any], platform: str) -> str:
    target = _first_text(
        item, "webpage_url", "webpageUrl", "original_url", "post_url", "postUrl"
    )
    if target.startswith("http"):
        return target
    url = _first_text(item, "url")
    if url.startswith("http"):
        return url
    video_id = _first_text(item, "id", "video_id", "videoId", "aweme_id", "tweet_id")
    if platform == "youtube" and video_id:
        return "https://www.youtube.com/watch?v=" + video_id
    return ""


def _is_recent(record: Dict[str, Any], since_days: Optional[int]) -> bool:
    if since_days is None:
        return True
    published_at = record.get("publishedAt")
    if not isinstance(published_at, str):
        return False
    try:
        published = dt.datetime.fromisoformat(published_at.replace("Z", "+00:00"))
    except ValueError:
        return False
    if published.tzinfo is None:
        published = published.replace(tzinfo=dt.timezone.utc)
    cutoff = dt.datetime.now(dt.timezone.utc) - dt.timedelta(days=since_days)
    return published >= cutoff


def collect_queries(
    queries: Dict[str, List[str]],
    minimum_likes: int,
    search_limit: int = DEFAULT_SEARCH_LIMIT,
    since_days: Optional[int] = DEFAULT_SINCE_DAYS,
) -> List[Dict[str, Any]]:
    """Discover videos from public search pages, then fetch detail metadata."""
    records: List[Dict[str, Any]] = []
    seen = set()
    for platform in PLATFORMS:
        for query in queries.get(platform, []):
            seed = _query_seed(platform, query, search_limit)
            try:
                payload = _extract_search(seed)
            except (
                OSError,
                subprocess.CalledProcessError,
                subprocess.TimeoutExpired,
                json.JSONDecodeError,
            ) as error:
                print("skip query %s (%s): %s" % (platform, query, error), file=sys.stderr)
                continue
            for search_item in _entries(payload):
                target = _entry_target(search_item, platform)
                if not target:
                    continue
                try:
                    detail_payload = _extract(target)
                except (
                    OSError,
                    subprocess.CalledProcessError,
                    subprocess.TimeoutExpired,
                    json.JSONDecodeError,
                ) as error:
                    print("skip result %s: %s" % (target, error), file=sys.stderr)
                    continue
                for item in _entries(detail_payload):
                    record = normalize_entry(item, platform, minimum_likes)
                    if not record or not _is_recent(record, since_days):
                        continue
                    key = (platform, record["videoId"])
                    if key in seen:
                        continue
                    seen.add(key)
                    records.append(record)
    return records


def _platform_from_url(url: str, fallback: str = "web") -> str:
    lowered = url.lower()
    if "youtube.com" in lowered or "youtu.be" in lowered:
        return "youtube"
    if "douyin.com" in lowered or "tiktok.com" in lowered:
        return "douyin"
    if "x.com" in lowered or "twitter.com" in lowered:
        return "x"
    if "pexels.com" in lowered:
        return "pexels"
    return fallback


def _fallback_item(metadata: Dict[str, Any], target: str) -> Dict[str, Any]:
    video_id = metadata.get("video_id") or hashlib.sha1(target.encode("utf-8")).hexdigest()
    item: Dict[str, Any] = {
        "id": str(video_id),
        "title": metadata.get("title", ""),
        "url": metadata.get("play_url", ""),
        "webpage_url": metadata.get("source_url", target),
        "like_count": metadata.get("likes"),
        "comment_count": metadata.get("comments"),
        "share_count": metadata.get("shares"),
        "publishedAt": metadata.get("published_at"),
    }
    return item


def _discovery_candidates(config: DiscoveryConfig) -> List[tuple]:
    candidates: List[tuple] = []
    seen = set()
    for query in config.queries:
        for platform in config.platforms:
            if len(candidates) >= config.max_candidates:
                return candidates
            try:
                if platform == "web":
                    _respect_host_rate_limit("https://html.duckduckgo.com")
                    targets = search_public(query, config.per_query_limit, DEFAULT_REQUEST_TIMEOUT_SECONDS)
                    items = ({"url": target} for target in targets)
                else:
                    seed = _query_seed(platform, query, config.per_query_limit)
                    _respect_host_rate_limit(seed)
                    payload = _extract_search(seed)
                    items = _entries(payload)
                for item in items:
                    target = item.get("url", "") if platform == "web" else _entry_target(item, platform)
                    if not isinstance(target, str) or not target.startswith(("http://", "https://")):
                        continue
                    key = target.split("#", 1)[0]
                    if key in seen:
                        continue
                    seen.add(key)
                    candidates.append((platform, target))
                    if len(candidates) >= config.max_candidates:
                        return candidates
            except (
                OSError,
                PublicSearchError,
                subprocess.CalledProcessError,
                subprocess.TimeoutExpired,
                json.JSONDecodeError,
            ) as error:
                print("skip discovery %s/%s: %s" % (platform, query, error), file=sys.stderr)
    return candidates


def collect_discovered(
    config: DiscoveryConfig, stats: Optional[Dict[str, int]] = None
) -> List[Dict[str, Any]]:
    """Discover public video pages from platform and web search adapters."""
    records: List[Dict[str, Any]] = []
    seen = set()
    candidates = _discovery_candidates(config)
    if stats is not None:
        stats.update({"discovered": len(candidates), "accepted": 0, "skipped": 0})
    for requested_platform, target in candidates:
        platform = _platform_from_url(target, requested_platform)
        detail_items: Iterable[Dict[str, Any]]
        try:
            _respect_host_rate_limit(target)
            detail_items = _entries(_extract(target))
        except (
            OSError,
            subprocess.CalledProcessError,
            subprocess.TimeoutExpired,
            json.JSONDecodeError,
        ):
            try:
                detail_items = (_fallback_item(extract_public_metadata(target), target),)
            except PublicMetadataError as error:
                print("skip result %s: %s" % (target, error), file=sys.stderr)
                if stats is not None:
                    stats["skipped"] = stats.get("skipped", 0) + 1
                continue
        for item in detail_items:
            record = normalize_entry(item, platform, config.min_likes)
            if not record or not _is_recent(record, config.since_days):
                if stats is not None:
                    stats["skipped"] = stats.get("skipped", 0) + 1
                continue
            key = (platform, record["videoId"])
            if key in seen:
                continue
            seen.add(key)
            records.append(record)
            if stats is not None:
                stats["accepted"] = stats.get("accepted", 0) + 1
    return records


def _load_platform_lists(path: pathlib.Path, label: str) -> Dict[str, List[str]]:
    payload = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(payload, dict):
        raise ValueError("%s must be an object with youtube, x, and douyin arrays" % label)
    result = {}
    for platform in PLATFORMS:
        values = payload.get(platform, [])
        if not isinstance(values, list) or not all(isinstance(value, str) and value for value in values):
            raise ValueError("%s %s must be a list of non-empty strings" % (platform, label))
        result[platform] = values
    return result


def _load_seeds(path: pathlib.Path) -> Dict[str, List[str]]:
    return _load_platform_lists(path, "seeds")


def _load_queries(path: pathlib.Path) -> Dict[str, List[str]]:
    return _load_platform_lists(path, "queries")


def _string_list(payload: Any, field: str) -> List[str]:
    if not isinstance(payload, list) or not all(isinstance(value, str) and value.strip() for value in payload):
        raise ValueError("%s must be a list of non-empty strings" % field)
    return [value.strip() for value in payload]


def _positive_int(payload: Dict[str, Any], field: str, default: int) -> int:
    value = payload.get(field, default)
    if isinstance(value, bool) or not isinstance(value, int) or value <= 0:
        raise ValueError("%s must be a positive integer" % field)
    return value


def _load_discovery(path: pathlib.Path) -> DiscoveryConfig:
    payload = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(payload, dict):
        raise ValueError("discovery config must be an object")
    queries = _string_list(payload.get("queries", []), "queries")
    platforms = _string_list(
        payload.get("platforms", list(DISCOVERY_PLATFORMS)), "platforms"
    )
    unknown = sorted(set(platforms) - set(DISCOVERY_PLATFORMS))
    if unknown:
        raise ValueError("unsupported discovery platforms: %s" % ", ".join(unknown))
    since_days = payload.get("sinceDays", DEFAULT_SINCE_DAYS)
    if since_days is not None and (
        isinstance(since_days, bool) or not isinstance(since_days, int) or since_days < 0
    ):
        raise ValueError("sinceDays must be a non-negative integer or null")
    return DiscoveryConfig(
        queries=queries,
        platforms=platforms,
        per_query_limit=_positive_int(payload, "perQueryLimit", DEFAULT_SEARCH_LIMIT),
        max_candidates=_positive_int(payload, "maxCandidates", 200),
        min_likes=_positive_int(payload, "minLikes", DEFAULT_MIN_LIKES),
        since_days=since_days,
    )


def _load_dotenv(path: pathlib.Path) -> Dict[str, str]:
    values: Dict[str, str] = {}
    if not path.exists():
        return values
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        values[key.strip()] = value.strip().strip('"').strip("'")
    return values


def _import_records(records: List[Dict[str, Any]], api_root: pathlib.Path) -> None:
    env = os.environ.copy()
    for key, value in _load_dotenv(api_root / ".env").items():
        env.setdefault(key, value)
    with tempfile.TemporaryDirectory(prefix="creatorhub-videos-") as directory:
        input_path = pathlib.Path(directory) / "videos.json"
        input_path.write_text(json.dumps(records, ensure_ascii=False), encoding="utf-8")
        for platform in IMPORT_PLATFORMS:
            platform_records = [item for item in records if _platform_for(item) == platform]
            if not platform_records:
                continue
            input_path.write_text(json.dumps(platform_records, ensure_ascii=False), encoding="utf-8")
            subprocess.run(
                [
                    "go",
                    "run",
                    "./cmd/importvideos",
                    "-platform",
                    platform,
                    "-input",
                    str(input_path),
                ],
                cwd=str(api_root),
                env=env,
                check=True,
            )


def _platform_for(record: Dict[str, Any]) -> str:
    platform = record.get("platform")
    if isinstance(platform, str) and platform in IMPORT_PLATFORMS:
        return platform
    source = record.get("url", "")
    if "youtube" in source or "youtu.be" in source:
        return "youtube"
    if "douyin" in source or "tiktok" in source:
        return "douyin"
    if "pexels" in source:
        return "pexels"
    return "x"


def main() -> int:
    parser = argparse.ArgumentParser(description="Scrape public video metadata without Apify")
    source = parser.add_mutually_exclusive_group(required=True)
    source.add_argument("--seeds", type=pathlib.Path)
    source.add_argument("--queries", type=pathlib.Path)
    source.add_argument("--pexels", action="store_true")
    parser.add_argument("--output", type=pathlib.Path)
    parser.add_argument("--min-likes", type=int)
    parser.add_argument("--search-limit", type=int)
    parser.add_argument("--since-days", type=int)
    parser.add_argument("--pexels-limit", type=int, default=20)
    parser.add_argument("--import", dest="import_records", action="store_true")
    args = parser.parse_args()
    minimum_likes = args.min_likes if args.min_likes is not None else DEFAULT_MIN_LIKES
    stats: Dict[str, int] = {"discovered": 0, "accepted": 0, "skipped": 0, "imported": 0}
    if args.pexels:
        records = collect_pexels_videos(args.pexels_limit)
        stats.update({"discovered": len(records), "accepted": len(records)})
    elif args.queries:
        config = _load_discovery(args.queries)
        effective_min_likes = args.min_likes if args.min_likes is not None else config.min_likes
        config = DiscoveryConfig(
            queries=config.queries,
            platforms=config.platforms,
            per_query_limit=(
                args.search_limit if args.search_limit is not None else config.per_query_limit
            ),
            max_candidates=config.max_candidates,
            min_likes=effective_min_likes,
            since_days=args.since_days if args.since_days is not None else config.since_days,
        )
        minimum_likes = effective_min_likes
        records = collect_discovered(config, stats)
    else:
        records = collect(_load_seeds(args.seeds), minimum_likes)
        stats.update({"discovered": len(records), "accepted": len(records)})
    payload = json.dumps(records, ensure_ascii=False, indent=2) + "\n"
    if args.output:
        args.output.write_text(payload, encoding="utf-8")
    else:
        sys.stdout.write(payload)
    if args.import_records and records:
        _import_records(records, pathlib.Path(__file__).resolve().parents[1])
        stats["imported"] = len(records)
    print(json.dumps(stats, ensure_ascii=False), file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
