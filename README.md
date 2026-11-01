# CINEFLIX Ultra Premium v5

Flutter Android streaming-catalogue demo with a dark multi-accent UI, local My List/progress, HLS track selection, connectivity-aware starting quality, URL health probes, and server failover.

## Important content and server boundaries

This repository is a working **open-content demo**, not a preloaded commercial-film service. It includes a curated set of Blender open-movie entries and public test streams. Copyrighted films, anime, dramas, and subscription catalogue titles cannot be bundled or streamed without the relevant distribution and streaming rights. A list of 1,000 invented records would not make 1,000 playable films, so the bundled JSON only contains verifiable demo entries.

Five server slots are defined in `assets/config/servers.json`. Server 1 and Server 2 are demo sources for the Big Buck Bunny title; the remaining three are deliberately marked `needs_configuration`. A server becomes a real backup only after the same authorized title asset and its renditions are uploaded to that origin and entered in the title's `sources` map. Do not put Bunny, Cloudflare, Backblaze, Google Drive, Telegram, or other private API keys in this APK: APK assets can be extracted. Keep private credentials on a backend and return short-lived signed playback URLs to the app.

The quality labels are preferences, not a promise that every source has a 4K rendition. For adaptive HLS/DASH, the player enumerates actual tracks and enables the qualities it finds. For a fixed MP4 source, manual quality switching is not supported. The bundled Mux sample has up to 1080p variants; it does not provide 4K. The player will not pretend otherwise.

`connectivity_plus` identifies the available transport (Wi-Fi/mobile); it does not determine whether a cellular connection is 4G or 5G or guarantee Internet reachability. The app starts at 1080p on Wi-Fi, 720p on mobile, and 480p when Data Saver is enabled. It then probes stream URLs with a bounded timeout and reacts to sustained player buffering. No client can guarantee zero buffering on an overloaded or unavailable origin.

## Build APK

The included GitHub Actions workflow `.github/workflows/build-android.yml` generates the Android platform scaffold, sets Android minSdk 24 (Android 7.0+; includes Android 10), resolves dependencies, generates the launcher icon, runs formatting/analyze/tests, and builds a release APK. It uploads the APK as a workflow artifact and attaches it to a GitHub Release.

You can also build locally with Flutter 3.41+ and Java 17:

```bash
flutter create --platforms=android --org com.teinzz --project-name cineflix_ultra .
flutter pub get
dart run flutter_launcher_icons
flutter analyze
flutter test
flutter build apk --release
```

The workflow uses the current stable Flutter channel. The resulting APK size depends on Flutter, native plugin binaries, ABI packaging and assets; 40 MB is not guaranteed. The workflow creates a universal APK rather than split ABI APKs for easier installation.

## Add a licensed title

Add a JSON object to `assets/database/all_content.json`. Each source map must contain only HTTPS URLs for that *same title*. Example shape:

```json
{
  "id": "your-title-id",
  "title": "Your Licensed Title",
  "type": "movie",
  "categories": ["Drama"],
  "year": 2026,
  "rating": 0,
  "age": "13+",
  "duration": "90m",
  "status": "Complete",
  "poster": null,
  "backdrop": null,
  "synopsis": "A short synopsis you have rights to publish.",
  "license": "Your distribution licence reference",
  "attribution": "Required attribution",
  "sources": {
    "server1": {
      "480p": "https://your-origin/title/480p.m3u8",
      "720p": "https://your-origin/title/720p.m3u8",
      "1080p": "https://your-origin/title/1080p.m3u8",
      "4K": "https://your-origin/title/2160p.m3u8"
    }
  }
}
```

For an HLS master playlist, the same master `.m3u8` can be listed for each preference; the player selects the matching actual HLS video track when available. For fixed MP4, use its real URL but expect a fixed resolution. Each server's map must point to a copy of the same title, not a different movie, or failover would change content mid-playback.

## Current implementation

- Dark UI, original app logo and animated splash reel image.
- Home hero carousel, collection cards, explore grid and My List.
- Detail page with per-title server availability and quality preference.
- ExoPlayer-backed Flutter `video_player` for HLS/MP4 on Android.
- Actual adaptive track selection when the native player exposes tracks.
- 2-second buffering watchdog: try a lower actual track, then move to the next configured source while restoring playback position.
- Dio source probe with a response stream so probing a large MP4 does not intentionally download the full movie.
- Hive persistence for My List, playback history and resume position.
- Five server slots and four quality keys per server/title, with empty unconfigured slots clearly marked.

## Credits

- Big Buck Bunny: Blender Foundation; CC BY 3.0 attribution included in the catalogue.
- Tears of Steel: Blender Foundation; CC BY 3.0 attribution included in the catalogue.
- Sintel, Spring and Sprite Fright: Blender open-movie projects. Check each current official project page for applicable attribution and redistribution terms before publishing your own build.
- Playback demo origins: Mux, Google sample storage, Unified Streaming and Blender video hosting. Public sample availability may change and is not a production SLA.
