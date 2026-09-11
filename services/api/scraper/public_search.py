#!/usr/bin/env python3
"""Small, dependency-free adapter for public HTML search results."""

from html.parser import HTMLParser
from typing import List
from urllib.parse import parse_qs, quote_plus, unquote, urljoin, urlparse
from urllib.request import Request, urlopen


SEARCH_ENDPOINT = "https://html.duckduckgo.com/html/?q="
USER_AGENT = "CreatorHubPublicCollector/1.0"


class PublicSearchError(RuntimeError):
    """Raised when a public search page cannot be fetched or decoded."""


class _ResultLinkParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.links: List[str] = []

    def handle_starttag(self, tag: str, attrs: List[tuple]) -> None:
        if tag != "a":
            return
        values = dict(attrs)
        classes = set((values.get("class") or "").split())
        if "result__a" in classes and values.get("href"):
            self.links.append(values["href"])


def _canonical_link(link: str) -> str:
    link = urljoin("https://html.duckduckgo.com", link.strip())
    parsed = urlparse(link)
    if parsed.hostname in {"html.duckduckgo.com", "duckduckgo.com", "www.duckduckgo.com"}:
        redirect = parse_qs(parsed.query).get("uddg", [])
        if redirect:
            link = unquote(redirect[0])
    parsed = urlparse(link)
    if parsed.scheme not in {"http", "https"} or not parsed.netloc:
        return ""
    return link


def parse_result_links(html: str, limit: int) -> List[str]:
    if limit <= 0:
        return []
    parser = _ResultLinkParser()
    parser.feed(html)
    result: List[str] = []
    seen = set()
    for raw_link in parser.links:
        link = _canonical_link(raw_link)
        if not link or link in seen:
            continue
        seen.add(link)
        result.append(link)
        if len(result) >= limit:
            break
    return result


def search_public(query: str, limit: int, timeout: int = 20) -> List[str]:
    if not query.strip() or limit <= 0:
        return []
    request = Request(
        SEARCH_ENDPOINT + quote_plus(query.strip()),
        headers={"User-Agent": USER_AGENT},
    )
    try:
        with urlopen(request, timeout=timeout) as response:
            body = response.read()
            charset = response.headers.get_content_charset() or "utf-8"
            html = body.decode(charset, errors="replace")
    except Exception as error:
        raise PublicSearchError("public search request failed: %s" % type(error).__name__) from error
    return parse_result_links(html, limit)
