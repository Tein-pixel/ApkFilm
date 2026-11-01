#!/usr/bin/env python3
"""Validate local catalogue integrity before a release.

Remote origins are deliberately not fetched during builds: transient CDN rate
limits and regional outages must not prevent a valid Android APK from building.
Runtime playback probing remains enabled in the app.
"""
import json
import sys
from pathlib import Path
from urllib.parse import urlparse

CATALOG = Path("assets/database/all_content.json")
QUALITIES = {"360p", "480p", "720p", "1080p", "4K"}
SERVERS = {"server1", "server2", "server3", "server4", "server5"}


def main() -> int:
    catalog = json.loads(CATALOG.read_text(encoding="utf-8"))
    if not isinstance(catalog, list) or not catalog:
        raise RuntimeError("Catalog must be a non-empty JSON array.")

    failures = []
    ids = set()
    poster_count = 0
    stream_count = 0
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
            poster_count += 1

        sources = title.get("sources") or {}
        if not isinstance(sources, dict):
            failures.append(f"{name}: sources must be an object")
            continue
        unknown = set(sources) - SERVERS
        if unknown:
            failures.append(f"{name}: unknown server slots: {sorted(unknown)}")
        for server, qualities in sources.items():
            if not isinstance(qualities, dict):
                failures.append(f"{name}: {server} quality map is invalid")
                continue
            for quality, value in qualities.items():
                if quality not in QUALITIES:
                    failures.append(f"{name}: unsupported quality label {quality}")
                    continue
                url = (value or "").strip()
                if not url:
                    continue
                parsed = urlparse(url)
                if parsed.scheme != "https" or not parsed.netloc:
                    failures.append(f"{name}: {server}/{quality} is not a valid HTTPS URL")
                else:
                    stream_count += 1

    if not stream_count:
        failures.append("No playback source URLs are configured.")

    if failures:
        print("\nCATALOG VALIDATION FAILED:", file=sys.stderr)
        for failure in failures:
            print(f" - {failure}", file=sys.stderr)
        return 1

    print(
        f"Catalogue OK: {len(catalog)} bundled titles, "
        f"{poster_count} HTTPS poster references, {stream_count} declared stream URLs."
    )
    print("Remote host availability is checked at runtime, not as a release-build gate.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
