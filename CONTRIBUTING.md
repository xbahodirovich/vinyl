# Contributing

Keep changes focused and include the problem, resulting behavior and relevant checks in a pull request. Follow the build and test instructions in [Development](docs/DEVELOPMENT.md).

Preserve click-through wallpaper layering, all-display behavior, paused phase, reduced-motion support and low idle work. Do not add telemetry, account credentials or new outbound data flows without an explicit product decision and privacy documentation.

Use synthetic tracks for screenshots and tests. Do not include listening history, home-directory paths, secrets or private certificates. Report security issues privately as described in [SECURITY.md](SECURITY.md).

Before submitting:

```sh
python3 Scripts/check-publication.py
Scripts/scan-secrets.sh
swift test --disable-sandbox
node Scripts/test-browser.mjs
```

Describe manual checks separately from automated results. Do not claim physical display/Space, Intel hardware or battery validation based only on synthetic previews. Vinyl is source-available with rights reserved, not open source. See [LICENSE](LICENSE); contact the owner before contributing code so contribution permissions can be agreed explicitly.
