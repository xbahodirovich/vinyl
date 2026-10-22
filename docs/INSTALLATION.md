# Install Vinyl

## From a GitHub release

Open [Releases](https://github.com/xbahodirovich/vinyl/releases/latest), expand **Assets**, and download `Vinyl-<version>.dmg`. Drag Vinyl to Applications, eject the disk, then launch the installed app. Its controls live in the menu bar.

Requires macOS 14 or newer. Release builds include Apple Silicon and Intel slices; Intel hardware has not been exercised directly.

### Verify your download

Download the adjacent `.sha256` file into the same folder as the DMG. In Terminal, change to that folder and run:

```sh
shasum -a 256 -c Vinyl-0.1.0.dmg.sha256
```

Substitute the version you downloaded. `OK` means the file matches the published checksum. The checksum detects corruption; an attacker who controls the release could replace both files. It is not an independent signature.

### macOS security prompts

Current releases are **ad-hoc signed and not notarized**. For a copy you trust, use [Apple’s instructions](https://support.apple.com/102445) for **System Settings → Privacy & Security → Open Anyway** after attempting to open it. Do not turn off Gatekeeper or run blanket quarantine-removal commands. If macOS reports malware or damage, stop and verify the source rather than overriding that warning.

Public distribution with verified developer identity requires [Developer ID signing and notarization](https://developer.apple.com/developer-id/). The automated release does not claim or perform these steps.

## Updating

Quit the running Vinyl from its menu, then replace the copy in Applications using the new DMG. Start the installed copy. Settings normally remain in macOS preferences. Avoid running a development build and the installed app simultaneously.

## Troubleshooting

| Symptom | Try |
| --- | --- |
| No app window | Expected: open the small disc menu in the menu bar |
| No wallpaper | Enable **Show Wallpaper**; check **Scene Background** |
| Track missing | Start the supported desktop player, select **Automatic**, then **Reconnect** |
| Yandex works on desktop but not in Chrome/Edge | Install the [companion bridge](BROWSER_SETUP.md) |
| Blurry Yandex cover | Enable **High-Resolution Yandex Covers** if you accept catalogue requests |
| Different cover version / no sharper image | Lookup requires a matching result; ambiguous releases fall back to local artwork |
| Old logo | Quit both app copies, replace the installed app, then reopen; Finder may cache icons |

Desktop behavior depends on macOS and the player’s Now Playing publication. OS upgrades may affect the private adapter.

## Uninstalling

Quit Vinyl and move its app from Applications to Trash. If installed, [remove the browser bridge](BROWSER_SETUP.md#remove-the-bridge) and extension separately. Vinyl preferences may remain in `~/Library/Preferences/local.sidea.mac.plist`; no account or server deletion is required.
