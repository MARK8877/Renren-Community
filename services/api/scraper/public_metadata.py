#!/usr/bin/env python3
"""Dependency-free metadata fallback for publicly accessible video pages."""

import datetime as dt
import json
from html.parser import HTMLParser
from typing import Any, Dict, Iterable, List, Optional
from urllib.parse import urljoin
from urllib.request import Request, urlopen


USER_AGENT = "CreatorHubPublicCollector/1.0"


class PublicMetadataError(RuntimeError):
    """Raised when a public page cannot be fetched or decoded."""


class _MetadataParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.meta: Dict[str, str] = {}
        self.video_sources: List[str] = []
        self._title_parts: List[str] = []
        self._in_title = False
        self._json_ld_parts: List[str] = []
        self._in_json_ld = False

    def handle_starttag(self, tag: str, attrs: List[tuple]) -> None:
        values = dict(attrs)
        if tag == "meta":
            key = values.get("property") or values.get("name")
            content = values.get("content")
            if key and content:
                self.meta[key.lower()] = content.strip()
        elif tag in {"video", "source"} and values.get("src"):
            self.video_sources.append(values["src"].strip())
        elif tag == "title":
            self._in_title = True
        elif tag == "script" and values.get("type", "").lower() == "application/ld+json":
            self._in_json_ld = True

    def handle_endtag(self, tag: str) -> None:
        if tag == "title":
            self._in_title = False
        elif tag == "script" and self._in_json_ld:
            self._in_json_ld = False

    def handle_data(self, data: str) -> None:
        if self._in_title:
            self._title_parts.append(data)
        if self._in_json_ld:
            self._json_ld_parts.append(data)

    @property
    def title(self) -> str:
        return "".join(self._title_parts).strip()

    @property
    def json_ld(self) -> Iterable[Any]:
        for raw in self._json_ld_parts:
            try:
                yield json.loads(raw)
            except (TypeError, ValueError):
                continue


def _number(value: Any) -> Optional[int]:
    if isinstance(value, bool) or value is None:
        return None
    try:
        return max(0, int(float(str(value).replace(",", "").strip())))
    except (TypeError, ValueError):
        return None


def _published_at(value: Any) -> Optional[str]:
    if not isinstance(value, str) or not value.strip():
        return None
    try:
        parsed = dt.datetime.fromisoformat(value.strip().replace("Z", "+00:00"))
    except ValueError:
        return None
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=dt.timezone.utc)
    return parsed.astimezone(dt.timezone.utc).isoformat()


def _video_objects(value: Any) -> Iterable[Dict[str, Any]]:
    if isinstance(value, list):
        for item in value:
            yield from _video_objects(item)
    elif isinstance(value, dict):
        types = value.get("@type")
        if types == "VideoObject" or (isinstance(types, list) and "VideoObject" in types):
            yield value
        for item in value.get("@graph", []):
            yield from _video_objects(item)


def _interaction_counts(video: Dict[str, Any]) -> Dict[str, int]:
    counts: Dict[str, int] = {}
    statistics = video.get("interactionStatistic", [])
    if isinstance(statistics, dict):
        statistics = [statistics]
    if not isinstance(statistics, list):
        return counts
    for statistic in statistics:
        if not isinstance(statistic, dict):
            continue
        interaction = str(statistic.get("interactionType", "")).lower()
        count = _number(statistic.get("userInteractionCount"))
        if count is None:
            continue
        if "like" in interaction:
            counts["likes"] = count
        elif "comment" in interaction:
            counts["comments"] = count
        elif "share" in interaction:
            counts["shares"] = count
    return counts


def parse_html_metadata(html: str, page_url: str) -> Dict[str, Any]:
    parser = _MetadataParser()
    parser.feed(html)
    metadata: Dict[str, Any] = {"source_url": page_url}
    title = parser.meta.get("og:title") or parser.title or parser.meta.get("description")
    if title:
        metadata["title"] = title
    play_url = parser.meta.get("og:video:url") or parser.meta.get("og:video")
    if not play_url and parser.video_sources:
        play_url = parser.video_sources[0]
    if play_url:
        metadata["play_url"] = urljoin(page_url, play_url)

    for payload in parser.json_ld:
        for video in _video_objects(payload):
            metadata.setdefault("title", str(video.get("name", "")).strip())
            content_url = video.get("contentUrl") or video.get("embedUrl")
            if content_url and "play_url" not in metadata:
                metadata["play_url"] = urljoin(page_url, str(content_url))
            identifier = video.get("identifier") or video.get("@id")
            if identifier:
                metadata.setdefault("video_id", str(identifier))
            published = _published_at(video.get("uploadDate") or video.get("datePublished"))
            if published:
                metadata.setdefault("published_at", published)
            metadata.update({key: value for key, value in _interaction_counts(video).items()})

    return {key: value for key, value in metadata.items() if value not in (None, "")}


def extract_public_metadata(url: str, timeout: int = 20) -> Dict[str, Any]:
    request = Request(url, headers={"User-Agent": USER_AGENT})
    try:
        with urlopen(request, timeout=timeout) as response:
            body = response.read()
            charset = response.headers.get_content_charset() or "utf-8"
            html = body.decode(charset, errors="replace")
    except Exception as error:
        raise PublicMetadataError(
            "public metadata request failed: %s" % type(error).__name__
        ) from error
    return parse_html_metadata(html, url)
