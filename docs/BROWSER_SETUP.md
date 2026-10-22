# Yandex Music in Chrome or Edge

Yandex Music’s desktop app needs no extension. The browser bridge is optional and currently supports Chrome and Edge; Safari is not implemented.

## Set up

1. Install Vinyl in Applications and launch it.
2. Download and extract this repository’s source using **Code → Download ZIP**, or clone it.
3. In Terminal, change to that extracted project directory and run:

   ```sh
   python3 Scripts/install-browser-bridge.py --app /Applications/Vinyl.app
   ```

   For Edge, add `--browser edge`.

4. Open `chrome://extensions` or `edge://extensions`, enable **Developer mode**, select **Load unpacked**, and choose the project’s `BrowserExtension` folder.
5. Reload the Yandex Music tab and play a song.

Keep the extracted extension folder in place. Register again if you move the app. The Python script requires Python 3; it does not need administrator access.

## What is installed

The script creates a native-host manifest and a shell launcher in your browser’s per-user `NativeMessagingHosts` directory, beneath `~/Library/Application Support`. The manifest permits this companion extension’s stable ID only. The extension requests `nativeMessaging`, runs on the five listed Yandex Music domains, and relays Media Session data. Its manifest `key` is a **public extension identifier**, not a private signing key or account token.

The website can supply its own metadata. The bridge is not an authentication or account integration, and local app notifications are not a security boundary against other software running as your user. See [SECURITY.md](../SECURITY.md).

## Remove the bridge

From the project directory:

```sh
python3 Scripts/install-browser-bridge.py --uninstall
# Or:
python3 Scripts/install-browser-bridge.py --browser edge --uninstall
```

Then remove the extension in your browser.
