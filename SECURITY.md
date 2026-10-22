# Security & privacy

## Report a concern

For a security issue, use this repository’s **Security → Report a vulnerability** if private reporting is enabled. Otherwise contact the repository owner privately through a channel they provide. Do not open a public issue containing tokens, listening history, personal paths or an exploit affecting other users. No security contact address has been configured yet.

## Data flow

- Desktop playback metadata is read locally through the bundled MediaRemote adapter. No credentials or microphone recording are needed.
- The optional browser extension reads Media Session metadata only on the Yandex Music domains in its manifest. It communicates with a local native host.
- Browser artwork requests go to approved Yandex artwork hosts. Optional high-resolution lookup sends current Yandex title and artist to `api.music.yandex.net`, then fetches the matched artwork. This option is off by default on a new Mac.
- Artwork networking requires HTTPS on the default port, disallows URL credentials, blocks redirects and uses an ephemeral session without persistent cookies or disk caches. Downloads still expose the client IP and requested resource to Yandex/network infrastructure.
- Up to four high-resolution images are cached in memory. Preferences persist through macOS UserDefaults. No analytics or Vinyl backend is included.
- Diagnostic live previews deliberately write current track details to local files. Never publish them without review.

## Trust boundaries & limitations

The browser page controls its metadata. The native host caps message size and normalizes the payload. Same-user distributed notifications are **not authenticated IPC**: another process running as your user can spoof metadata or playback commands. Vinyl is not a sandbox against malicious local software.

The adapter uses a private Apple interface and runs in a bundled helper through system Perl. Private APIs can change across OS versions. Its source and BSD license are vendored for inspection. No browser account cookies/tokens are requested by Vinyl.

Development builds are ad-hoc signed and not Apple-notarized. A checksum alongside a DMG protects against accidental corruption, not an attacker replacing the entire release. No claim of a formal security audit is made.

## Before publishing

Run `python3 Scripts/check-publication.py` and `Scripts/scan-secrets.sh`, review the staged diff, and enable GitHub secret scanning/push protection when available. The script is a limited pattern guard, not a replacement for established secret-scanning tools or review. Never commit private signing material, `.env` files, developer account credentials, local Xcode state, listening screenshots or build diagnostics.

Use GitHub’s private vulnerability reporting, branch/tag protections and reviewed workflow changes. Release workflows run only on version tags, with their built-in repository token scoped to the release job. No `pull_request_target` workflow executes untrusted PR code.
