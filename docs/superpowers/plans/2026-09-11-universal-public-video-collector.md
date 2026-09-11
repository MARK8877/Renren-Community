# Universal Public Video Collector Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a manually triggered discovery mode that finds publicly indexed video pages from platform search and public web search, extracts metadata without downloading media, filters strictly to `likes > 100`, and imports results into the existing `platform_videos` table.

**Architecture:** Keep the existing Python scraper and Go importer as the execution path. Add two small standard-library adapters: one for public HTML search results and one for generic page metadata; compose their candidate URLs in `free_video_scraper.py`, then reuse its normalizer, deduplicator, and importer. Existing URL-seed mode and API/Flutter contracts remain unchanged.

**Tech Stack:** Python 3.9+, `yt-dlp`, Python standard library (`urllib`, `html.parser`, `json`), Go 1.24, MySQL, Flutter/Dart tests.

**Spec:** `docs/superpowers/specs/2026-09-11-universal-public-video-collector-design.md`

## Global Constraints

- Only process publicly accessible pages; do not bypass login, CAPTCHA, paywalls, geo restrictions, robots restrictions, or anti-bot controls.
- Do not download, transcode, proxy, or host video media.
- Accept a record only when title, playable URL, and numeric likes are available and `likes > 100`; exactly 100 is rejected.
- Use no search API key; read public HTML search pages and tolerate provider blocking.
- Limit each host to one request per second, each request to 20 seconds, and each manual run to 200 candidates.
- Continue after a per-site timeout, HTTP error, parse error, or unsupported page; log the platform/query/URL and error type without secrets.
- Reuse `platform_videos`, `cmd/importvideos`, `GET /api/v1/videos`, and the existing Flutter video model without schema changes.

## File Map

- Create: `services/api/scraper/public_search.py` — public HTML search adapter and URL extraction.
- Create: `services/api/scraper/public_metadata.py` — generic OpenGraph/JSON-LD/`<video>` metadata fallback.
- Modify: `services/api/scraper/free_video_scraper.py` — discovery configuration, adapter orchestration, candidate limits, and CLI mode while preserving `--seeds`.
- Modify: `services/api/scraper/test_free_video_scraper.py` — discovery orchestration, threshold, deduplication, timeout, and config tests.
- Create: `services/api/scraper/test_public_search.py` — deterministic HTML search parsing tests.
- Create: `services/api/scraper/test_public_metadata.py` — deterministic page metadata parsing tests.
- Modify: `services/api/scraper/queries.example.json` — universal keyword configuration with limits and platform list.
- Modify: `README.md` — one-time discovery command, limits, failure behavior, and temporary playback URL warning.
- Verify only: `services/api/internal/video/repository.go`, `services/api/cmd/server/main.go`, `services/api/cmd/importvideos/main.go`, `apps/mobile/lib/src/video/video_api.dart` — existing `>100` behavior must remain unchanged.

### Task 1: Add deterministic public search adapter

**Files:**
- Create: `services/api/scraper/public_search.py`
- Create: `services/api/scraper/test_public_search.py`

**Interfaces:**
- Produces `search_public(query: str, limit: int, timeout: int = 20) -> list[str]`.
- The function fetches the public HTML endpoint `https://html.duckduckgo.com/html/?q=<urlencoded query>` with a fixed user agent, parses result anchors using `html.parser`, resolves relative links, removes non-HTTP links, and returns at most `limit` unique URLs in page order.
- Network errors and malformed HTML raise a typed `PublicSearchError`; the caller decides whether to skip the query.

- [ ] **Step 1: Write the failing tests**

Add tests that pass a representative HTML string to a pure parser helper and assert:

```python
def test_parse_results_returns_unique_http_links_in_order():
    html = '''<a class="result__a" href="//example.com/a">A</a>
              <a class="result__a" href="https://example.com/a">duplicate</a>
              <a class="result__a" href="https://example.com/b">B</a>'''
    assert parse_result_links(html, 10) == [
        "https://example.com/a",
        "https://example.com/b",
    ]
```

Also test that `limit=1` truncates and non-HTTP links are skipped.

- [ ] **Step 2: Run the focused tests and verify they fail**

Run: `python3 -m unittest services/api/scraper/test_public_search.py`

Expected: FAIL because `public_search.py` and `parse_result_links` do not exist.

- [ ] **Step 3: Implement the minimal adapter**

Use `urllib.request.Request`, `urllib.request.urlopen(..., timeout=timeout)`, `urllib.parse.urljoin`, and an `HTMLParser` subclass. Keep the parser independent from network I/O so the test never accesses the internet. Raise `PublicSearchError` with the original exception as context and never include headers or credentials in the message.

- [ ] **Step 4: Run the focused tests and verify they pass**

Run: `python3 -m unittest services/api/scraper/test_public_search.py`

Expected: PASS with all search parser tests green.

- [ ] **Step 5: Commit**

```bash
git add services/api/scraper/public_search.py services/api/scraper/test_public_search.py
git commit -m "feat: add public HTML search adapter"
```

The current workspace has no Git metadata; if that remains true, record the equivalent change without attempting a commit.

### Task 2: Add generic public-page metadata fallback

**Files:**
- Create: `services/api/scraper/public_metadata.py`
- Create: `services/api/scraper/test_public_metadata.py`

**Interfaces:**
- Produces `extract_public_metadata(url: str, timeout: int = 20) -> dict[str, Any]`.
- The extractor fetches one public page with a fixed user agent and returns raw normalized keys: `title`, `play_url`, `video_id`, `likes`, `comments`, `shares`, `published_at`, `source_url`.
- Parse `meta[property="og:title"]`, `meta[property="og:video"]`, `meta[property="og:video:url"]`, `meta[name="description"]`, JSON-LD `VideoObject`, public numeric interaction fields, and `<video>/<source src>`; resolve relative URLs against the page URL.
- Raise `PublicMetadataError` for HTTP, timeout, encoding, or parse failures. Missing optional fields remain absent; missing title/play URL/likes is handled by the caller as a skipped record.

- [ ] **Step 1: Write the failing tests**

Add an offline HTML fixture asserting OpenGraph title/video, JSON-LD publish date, numeric likes/comments/shares, and a relative `<source>` URL are extracted. Add a fixture with no playable URL and assert the result does not invent one.

- [ ] **Step 2: Run the focused tests and verify they fail**

Run: `python3 -m unittest services/api/scraper/test_public_metadata.py`

Expected: FAIL because the module and parser are missing.

- [ ] **Step 3: Implement the minimal parser**

Use `urllib.request` for fetching, `html.parser.HTMLParser` for meta/video tags, and `json.loads` for JSON-LD script blocks. Convert localized numeric strings by stripping separators and suffixes only when unambiguous; leave unknown numbers absent rather than guessing. Keep URL fetching separate from the pure HTML parsing helper used by tests.

- [ ] **Step 4: Run the focused tests and verify they pass**

Run: `python3 -m unittest services/api/scraper/test_public_metadata.py`

Expected: PASS with all fallback parser tests green.

- [ ] **Step 5: Commit**

```bash
git add services/api/scraper/public_metadata.py services/api/scraper/test_public_metadata.py
git commit -m "feat: parse generic public video metadata"
```

### Task 3: Compose platform and web discovery in the existing scraper

**Files:**
- Modify: `services/api/scraper/free_video_scraper.py`
- Modify: `services/api/scraper/test_free_video_scraper.py`

**Interfaces:**
- Add `DiscoveryConfig` with `queries: list[str]`, `platforms: list[str]`, `per_query_limit: int`, `max_candidates: int`, `min_likes: int`, and `since_days: int | None`.
- Add `_load_discovery(path: pathlib.Path) -> DiscoveryConfig`, accepting the new top-level `queries` JSON shape and preserving the existing platform-array shape for backward compatibility.
- Add `collect_discovered(config: DiscoveryConfig) -> list[dict[str, Any]]`; it merges platform search candidates and `search_public` candidates, caps the merged candidate list at `max_candidates`, extracts details with yt-dlp first and `extract_public_metadata` second, then calls the existing normalizer and strict recency/likes filters.
- Preserve `collect`, `collect_queries`, `--seeds`, and existing importer output.

- [ ] **Step 1: Write failing orchestration tests**

Add tests that patch adapter functions with deterministic values and assert:

```python
config = DiscoveryConfig(
    queries=["AI 创作"], platforms=["youtube", "web"],
    per_query_limit=2, max_candidates=2, min_likes=100, since_days=None,
)
records = collect_discovered(config)
assert [record["videoId"] for record in records] == ["yt-1"]
```

Cover exact 100 rejection, 101 acceptance, duplicate platform/web candidates, one adapter timeout being skipped, and the 200-candidate cap.

- [ ] **Step 2: Run the focused tests and verify they fail**

Run: `python3 -m unittest services/api/scraper/test_free_video_scraper.py`

Expected: FAIL because `DiscoveryConfig`, `_load_discovery`, and `collect_discovered` are not defined.

- [ ] **Step 3: Implement minimal orchestration**

For each configured keyword, call platform search using the existing yt-dlp path and call `search_public` for the web path. Normalize candidate URLs before deduplication. For each candidate, call yt-dlp detail extraction; on `OSError`, `CalledProcessError`, `TimeoutExpired`, or JSON errors, call the generic metadata fallback once. Apply `likes > min_likes`, recency, required-field, and deduplication checks before appending. Keep request timeout at 20 seconds and stop adding candidates after `max_candidates`.

- [ ] **Step 4: Update CLI without breaking URL mode**

Change `main()` so `--seeds` and `--queries` remain mutually exclusive. `--queries` loads `DiscoveryConfig` and invokes `collect_discovered`; `--seeds` invokes the existing `collect`. Keep `--min-likes`, `--search-limit`, and `--since-days` as explicit overrides, with defaults 100, 20, and 30. Print a final JSON summary containing `discovered`, `imported`, and `skipped` counts while keeping the existing records JSON output available through `--output`.

- [ ] **Step 5: Run the focused tests and verify they pass**

Run: `python3 -m unittest services/api/scraper/test_free_video_scraper.py`

Expected: PASS with legacy seed tests and new discovery tests green.

- [ ] **Step 6: Commit**

```bash
git add services/api/scraper/free_video_scraper.py services/api/scraper/test_free_video_scraper.py
git commit -m "feat: compose universal public video discovery"
```

### Task 4: Update configuration, documentation, and cross-layer regression checks

**Files:**
- Modify: `services/api/scraper/queries.example.json`
- Modify: `README.md`
- Verify: `services/api/internal/video/repository.go`
- Verify: `services/api/cmd/server/main.go`
- Verify: `services/api/cmd/importvideos/main.go`
- Verify: `apps/mobile/lib/src/video/video_api.dart`
- Test: `services/api/scraper/test_free_video_scraper.py`, Go tests, and Flutter `test/video_api_test.dart`

**Interfaces:**
- The example config contains `queries`, `platforms`, `perQueryLimit`, `maxCandidates`, `minLikes`, and `sinceDays`.
- The documented one-time command remains:

```bash
cd services/api
scraper/.venv/bin/python scraper/free_video_scraper.py \
  --queries scraper/queries.json \
  --import
```

- [ ] **Step 1: Update the example config**

Use the five approved keywords (`AI 创作`, `产品设计`, `摄影`, `科技`, `视频剪辑`), platforms `youtube`, `x`, `douyin`, and `web`, with limits 20, 200, 100, and 30.

- [ ] **Step 2: Update README instructions and limitations**

Document the manual command, public-page-only boundary, no API key requirement, strict `likes > 100` rule, 200-candidate cap, 20-second timeout, per-host delay, partial X/Douyin fields, and temporary playback URLs. Keep the legacy URL-seed command documented.

- [ ] **Step 3: Run all scraper tests**

Run: `python3 -m unittest services/api/scraper/test_public_search.py services/api/scraper/test_public_metadata.py services/api/scraper/test_free_video_scraper.py`

Expected: all scraper tests pass without network access.

- [ ] **Step 4: Run Go and Flutter regression tests**

Run: `(cd services/api && GOCACHE=/tmp/creatorhub-go-cache go test ./internal/video ./cmd/server ./cmd/importvideos)` and `(cd apps/mobile && FLUTTER_SUPPRESS_ANALYTICS=true PUB_CACHE=/tmp/creatorhub-pub-cache flutter test test/video_api_test.dart)`.

Expected: Go packages and the Flutter video API test pass; API default and SQL comparison remain strict `> 100`.

- [ ] **Step 5: Run one bounded manual discovery smoke test**

Run with one keyword, one result, and no import:

```bash
scraper/.venv/bin/python scraper/free_video_scraper.py \
  --queries scraper/queries.example.json \
  --search-limit 1 \
  --since-days 3650 \
  --output /tmp/creatorhub-discovery-smoke.json
```

Expected: command exits cleanly; successful records have `likes > 100`; blocked or unsupported sites appear as skipped diagnostics; no media file is created.

- [ ] **Step 6: Verify API remains healthy and keep it running**

Run: `curl -fsS http://127.0.0.1:18080/health`

Expected: `{"code":0,"message":"ok"}`. Restart only the project API process if source changes are not loaded, and leave the service listening on port 18080.

- [ ] **Step 7: Commit**

```bash
git add services/api/scraper/queries.example.json README.md
git commit -m "docs: document universal video discovery workflow"
```

## Final Review Checklist

- [ ] Spec sections 1–8 each map to at least one completed task above.
- [ ] No task introduces a new database table, API field, Flutter screen, API key, or media download path.
- [ ] Exact-threshold tests prove 100 is excluded and 101 is accepted in Python, Go filtering, SQL listing, and Flutter request defaults.
- [ ] Search and metadata adapters are unit tested offline; real network access is only a bounded manual smoke test.
- [ ] README command and example config agree with the CLI flags and defaults.
- [ ] API health check passes and the server remains running after implementation.
