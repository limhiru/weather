# Weather repository

- Android is Flutter in `android_app/`; iPhone is native SwiftUI in `ios_app/`.
- All weather data must originate from the Korea Meteorological Administration. Never silently substitute sample data. Demo screens must display a visible demo label.
- Keep credentials only in ignored `server/.env` or deployment environment variables.
- Run `sh scripts/setup.sh` after cloning. Every new commit increments patch version from the parent (first: 1.0.0), synchronizes both app manifests, and creates `vX.Y.Z`.
- Stage version-managed files before committing. Do not bypass the version hook, amend released commits, or overwrite published version tags.
- Use the repository owner's verified GitHub author identity; do not invent an email address.
- Validate with Python unittest, `flutter analyze`, `flutter test`, Android build, and Xcode build/test when supported. Report unverified credentials/device behavior accurately.
- SwiftUI native Liquid Glass is guarded for the iOS 26 SDK; keep the older iOS material fallback buildable.
