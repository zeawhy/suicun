# SuiVault （随存）

SuiVault is a local-first personal information vault for Android.
No account, no signup — open the app and start saving the things you'll need to find later.

Chinese name: 随存. Package: `com.suivault.app`.

## What it is

Not a traditional note app: SuiVault stores **structured cards** for the bits of
personal data you look up again and again — credentials, IDs, contacts, to-dos —
all in one encrypted local vault, with optional end-to-end encrypted WebDAV sync
you configure yourself.

## Features

- **Structured card templates** — one tap to create a card, no blank-page anxiety:
  - Record cards: password, inspiration, to-do, contact, blank
  - ID document cards: 身份证， 驾驶证， 行驶证， 护照， 港澳通行证， 社保卡， 房产证， plus custom ("其他")
  - ID numbers are masked by default; tap the eye to reveal
  - Document photos stay in the app's private directory — never in your public gallery
- **Local-first** — everything lives on your device; the app works fully offline
- **Search & organize** — full-text search, categories, tags, favorites, trash with restore
- **App lock** — lock the vault behind device authentication
- **Optional sync** — bring-your-own WebDAV server, end-to-end encrypted; sync is
  strictly opt-in and never requested until you configure it
- **Export & backup** — full JSON backup, Markdown ZIP, plain TXT; you own your data
- **Privacy built in** — privacy policy and "erase all data" are one tap away in Settings;
  no analytics, no ads, no account system
- Light / dark themes

## Status

- Android only for now (iOS is planned, not started)
- Current version: 1.0.0 (versionCode 1)
- Min/target SDK follows the Flutter stable default (targets API 36 for the Play release)

## Build

```bash
flutter pub get
flutter build apk --release        # APK
flutter build appbundle --release  # AAB (Google Play)
```

Release builds are also produced by the `Build APK` GitHub Actions workflow
(`.github/workflows/build-apk.yml`) via manual dispatch.

## Project layout

- `lib/` — Flutter app source (Dart)
- `docs/product-spec.md` — product design & staged delivery plan (Chinese)
- `android/` — Android shell (`applicationId com.suivault.app`)

## Contributing

Issues and PRs are welcome. Please keep PRs focused and run
`flutter analyze` plus the test suite before submitting.

## License

MIT — see [LICENSE](LICENSE).
