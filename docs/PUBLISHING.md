# First GitHub publication

The repository is prepared locally; it has not been pushed and no release is online yet.

## Review once

- The owner selected rights reserved for original code and assets; see [LICENSE](../LICENSE). Confirm you have permission to redistribute the supplied icon and reference-derived generated scene assets. The helper’s BSD license must remain intact.
- Review `git status --short` and `git diff --cached`. Keep local screenshots, personal notes, editor state, binaries and diagnostics out of commits.
- Run `python3 Scripts/check-publication.py` and `Scripts/scan-secrets.sh`. The latter scans publishable files with pinned, checksum-verified Gitleaks. Audit history separately if importing an existing repository.
- Set up a private reporting channel (GitHub Security settings) and enable secret scanning/push protection if available. Protect the default branch and release tags.

## Upload source

Create an empty GitHub repository without an auto-generated README. Set your desired public commit identity locally; names and email addresses in commits become public. If you prefer privacy, use your GitHub-provided **noreply** email from GitHub email settings.

```sh
git add .
python3 Scripts/check-publication.py
git diff --cached --stat
git diff --cached
# After reviewing, with your intended commit identity configured:
git commit -m "Prepare Vinyl for GitHub"
# origin is already configured to https://github.com/xbahodirovich/vinyl.git
git push -u origin main
```

The configured remote contains no credentials. Do not paste credentials into remote URLs. Use GitHub’s normal SSH or credential-manager authentication.

## Make the download button work

The README download button links directly to https://github.com/xbahodirovich/vinyl/releases/latest. That page becomes usable after the first release is published.

After source checks pass, publish the initial matching `v0.1.0` tag as described in [Development](DEVELOPMENT.md#publish-a-github-release). GitHub Actions builds and attaches the DMG and checksum. Users can then download it directly from Releases without cloning or installing Xcode.

Do not push signing certificates, API secrets or raw local build folders to GitHub. Do not upload the old unsanitized build from before publication preparation; rebuild with the current scripts and sanitized resources.
