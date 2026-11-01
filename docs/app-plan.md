# CINEFLIX Ultra Premium v5 — App Plan

## Product scope
A dark, mobile-first catalogue and streaming player for legally distributed/open-movie titles. This v5 package is a demonstration client with a small sample catalogue. It is not a licensed library of commercial films, anime or dramas. Production media must be supplied by the app owner with distribution rights.

## Design direction
- Near-pure black background for night viewing.
- Charcoal card hierarchy; red for playback and progress; cyan for server status; gold for ratings; green for verified readiness.
- Poppins typography with compact metadata.
- Portrait-first catalogue cards and a low-clutter player that hides controls during playback.

## Screens
| Screen | Route | Dart file | Purpose | Image |
|---|---|---|---|---|
| Splash | /splash | lib/screens/splash_screen.dart | Brand animation and transition to home | assets/images/app_logo.png; assets/images/splash_reel.png |
| Home | / | lib/screens/home_screen.dart | Featured titles, categories, continue watching, bottom navigation | assets/images/app_logo.png |
| Title detail | /detail/:id | lib/screens/detail_screen.dart | Synopsis, licence attribution, available source and play action | Placeholder until authorized posters are provided |
| Video player | /player/:id | lib/screens/player_screen.dart | HLS/MP4 playback, progress, track selection and failover | assets/images/splash_reel.png |
| Library | /library | lib/features/library/library_cubit.dart | Watch history, saved titles and continue watching | Built-in empty state |
| Explore/Search | /search | lib/screens/home_screen.dart | Browse and filter local catalogue metadata | Built-in placeholder |

## Data and playback
- Catalogue: assets/database/all_content.json; server definitions: assets/config/servers.json.
- Exactly five server definitions, each with 480p, 720p, 1080p and 4K fields. Empty slots are disabled, not online.
- HLS quality choices must come from the actual playlist tracks. A fixed MP4 is one fixed source, not four quality levels.
- Candidate ordering is preferred server first, quality downgrade, then next server; playback failures preserve the current position when possible.
- The app cannot guarantee zero buffering. It reacts to observed playback errors and buffering.
- No commercial film or copyrighted stream is embedded without authorization.

## Android compatibility
Android minimum SDK is API 24 to match the selected video_player release. INTERNET and ACCESS_NETWORK_STATE permissions are present.
