# CINEFLIX Ultra Premium v5

The first GitHub Actions run restores the Flutter project from the versioned source bundle, runs dependency resolution, formatting, static analysis and tests, then builds a release APK. After a successful build, the workflow commits the extracted Flutter source to the repository root and publishes the APK as a GitHub Release.

The app includes a small, verifiable open-movie sample catalogue. It does not include commercial films, anime or dramas without the relevant distribution rights. The five playback server slots are configurable; sources not populated with authorized URLs remain disabled. A quality slot is only playable when the underlying stream actually provides that resolution.

Minimum Android API: 24. Android 10 is supported.
