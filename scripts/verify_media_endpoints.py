#!/usr/bin/env python3
"""Validate each catalog poster and playback endpoint before an Android release."""
import json
import sys
import time
import urllib.request
from pathlib import Path

CATALOG = Path("assets/database/all_content.json")
HEADERS = {
    "User-Agent": "CineWave-ReleaseValidator/7.0",
    "Range": "bytes=0-4095",
    "Accept": "*/*",
}
TIMEOUT_SECONDS = 18
RETRIES = 2


def read_prefix(url: str):
    error = None
    for attempt in range(RETRIES + 1):
        try:
            request = urllib.request.Request(url, headers=HEADERS)
            with urllib.request.urlopen(request, timeout=TIMEOUT_SECONDS) as response:
                if response.status < 200 or response.status > 206:
                    raise RuntimeError(f"HTTP {response.status}")
                return response.headers.get("Content-Type", "").lower(), response.read(4096)
        except Exception as exc:
            error = exc
            if attempt < RETRIES:
                retry_after = 0
                if hasattr(exc, "headers") and exc.headers:
                    try:
                        retry_after = float(exc.headers.get("Retry-After", "0"))
                    except (TypeError, ValueError):
                        retry_after = 0
                time.sleep(max(retry_after, 2.0 * (attempt + 1)))
    raise RuntimeError(str(error))


def media_signature_ok(url: str, content_type: str, data: bytes) -> bool:
    path = url.split("?", 1)[0].lower()
    text = data.decode("utf-8", errors="replace").lstrip("\ufeff \r\n\t")
    if path.endswith(".m3u8") or "mpegurl" in content_type:
        return text.startswith("#EXTM3U")
    if path.endswith(".mpd") or "dash+xml" in content_type:
        return "<MPD" in text or ":MPD" in text
    if path.endswith((".mp4", ".m4v", ".mov")) or "video/mp4" in content_type or "video/quicktime" in content_type:
        return len(data) >= 8 and data[4:8] == b"ftyp"
    if path.endswith(".webm") or "webm" in content_type:
        return data.startswith(bytes((0x1A, 0x45, 0xDF, 0xA3)))
    return False


def main() -> int:
    catalog = json.loads(CATALOG.read_text(encoding="utf-8"))
    if not isinstance(catalog, list) or not catalog:
        raise RuntimeError("Catalog must be a non-empty JSON array.")

    poster_urls = set()
    stream_urls = set()
    failures = []
    ids = set()
    for title in catalog:
        name = title.get("title", "<untitled>")
        ident = title.get("id", "")
        if not ident or ident in ids:
            failures.append(f"{name}: missing or duplicate id")
        ids.add(ident)
        if not title.get("license") or not title.get("attribution"):
            failures.append(f"{name}: missing license/attribution")

        poster = (title.get("poster") or "").strip()
        if not poster.startswith("https://"):
            failures.append(f"{name}: missing HTTPS poster")
        else:
            poster_urls.add(poster)

        for server in (title.get("sources") or {}).values():
            if not isinstance(server, dict):
                continue
            for key, value in server.items():
                if key not in ("360p", "480p", "720p", "1080p", "4K"):
                    continue
                url = (value or "").strip()
                if url:
                    if not url.startswith("https://"):
                        failures.append(f"{name}: source {key} is not HTTPS")
                    else:
                        stream_urls.add(url)

    for url in sorted(poster_urls):
        try:
            content_type, data = read_prefix(url)
            if not content_type.startswith("image/") or not data:
                raise RuntimeError(f"not an image response ({content_type!r})")
            print(f"POSTER OK: {url}")
        except Exception as exc:
            failures.append(f"poster {url}: {exc}")

    for url in sorted(stream_urls):
        try:
            content_type, data = read_prefix(url)
            if not media_signature_ok(url, content_type, data):
                raise RuntimeError(
                    f"invalid media signature; content-type={content_type!r}, prefix={data[:24]!r}"
                )
            print(f"STREAM OK: {url}")
        except Exception as exc:
            failures.append(f"stream {url}: {exc}")

    if failures:
        print("\nMEDIA VALIDATION FAILED:", file=sys.stderr)
        for failure in failures:
            print(f" - {failure}", file=sys.stderr)
        return 1

    print(
        f"Validated {len(catalog)} titles, {len(poster_urls)} posters and "
        f"{len(stream_urls)} unique video endpoints."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
