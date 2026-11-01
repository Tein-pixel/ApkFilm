# CINEFLIX Ultra 6.0.0

CINEFLIX Ultra is an Android-first catalogue and streaming player for openly licensed or otherwise authorized media. Its design takes inspiration from modern streaming interfaces: cinematic featured artwork, portrait posters, compact metadata, saved titles, watch history and a focused player.

## Current bundled catalogue

The release contains six Blender Open Movies with poster artwork and title-specific source metadata:

| Title | Year | License |
|---|---:|---|
| Big Buck Bunny | 2008 | CC BY 3.0 |
| Elephants Dream | 2006 | CC BY 2.5 |
| Sintel | 2010 | CC BY 3.0 |
| Tears of Steel | 2012 | CC BY 3.0 |
| Spring | 2019 | CC BY 4.0 |
| Sprite Fright | 2021 | CC BY 1.0 |

Poster images are loaded from Wikimedia Commons and cached on device. Attribution is included with each title. Some artwork files contain logos or other excluded trademarks; the app uses the source artwork without implying endorsement.

## Playback and reliability

- Android HLS/MP4 playback through Flutter `video_player` (ExoPlayer on Android).
- Quality choices are limited to the renditions actually declared in the title's source map; adaptive tracks are selected from the HLS/DASH stream when the native player exposes them.
- Source probing uses a byte-range request with a bounded timeout.
- The player can move to another configured source while attempting to preserve playback position.
- Sustained buffering triggers a lower available video track or a configured fallback source.
- Watch history, resume position and My List are stored locally.

A public demo origin is not a content-delivery SLA. An origin can become unavailable, respond differently by region, or be congested; the player reports unavailable sources instead of inventing a working stream. A fixed MP4 has one real resolution, not four selectable quality levels.

## Catalogue and content rights

This APK does **not** contain a commercial library of every film, anime or drama. Movie metadata and poster art do not grant rights to stream a film. Commercial titles can only be added when the app owner has an authorized playback URL and the required distribution rights. Do not paste scraped or unlicensed third-party stream links into the catalogue.

To add an authorized title, append an object to `assets/database/all_content.json` with:
- a unique `id`, title, year, synopsis, categories and age rating;
- an HTTPS `poster` URL and optional `backdrop` URL that you are allowed to use;
- a license and attribution string;
- at least one genuine source URL for the same title, under one of `server1` through `server5`, using only real rendition labels (`480p`, `720p`, `1080p`, `4K`).

Keep server credentials on a backend. Do not embed private CDN tokens or API secrets in an APK because APK assets can be extracted.

## Android compatibility and build

- Minimum Android API: 24 (Android 7.0+); includes Android 10.
- Network permissions: INTERNET and ACCESS_NETWORK_STATE.
- Build pipeline: Java 17, Flutter stable, `flutter pub get`, formatting, analyzer, tests, release APK.

GitHub Actions uploads a `cineflix-ultra-v6-apk` artifact and attaches the APK to a GitHub Release.
