# Scriptable DeepLink on macOS

`finicky.js` mirrors the `url` decoding and Mail normalization in
`config/scriptable/DeepLink.js`, captured from the iCloud script on 2026-11-03.
The iCloud source is unchanged. The saved copy can also be restored to Scriptable.

For `https://open.scriptable.app/run/DeepLink?url=ENCODED_URL`:

- Decode until a URL scheme appears, matching the Scriptable loop. Do not
  decode an already-readable destination's query parameters a second time.
- Normalize `message://<message-id>` and send it to Mail.
- Send HTTP and HTTPS destinations to Safari, the configured default browser.
- Send other schemes to their registered macOS application. That application
  must be installed; an iOS-only scheme has no automatic Mac equivalent.

The older `?type=mail&id=MESSAGE_ID` form remains supported. Invalid or unrelated
wrappers are left unchanged. Direct `finicky:` destinations are not unwrapped
to avoid sending Finicky a recursive request.

Finicky 4.2.2 requires an explicit destination application. Its launcher passes
custom `args` to `/usr/bin/open`; `-n --args URL` starts a fresh bundled
**DeepLink Opener** instance for each custom-scheme URL. The helper delegates
that single argument to macOS `/usr/bin/open`, without shell interpolation.
It refuses HTTP(S) and `finicky:` to avoid routing loops. Home Manager substitutes
the helper's Nix-store path; do not copy the template `finicky.js` verbatim into
your home directory.

Check behavior without opening any destination:

```sh
node --test config/finicky/tests/deeplink.test.mjs
```

The live configuration is a Nix-managed symlink. A system activation is required
to install changes; building alone does not change the running Mac's routing.

Upstream references:
[Finicky v4 configuration](https://github.com/johnste/finicky/wiki/Configuration-%28v4%29),
[4.2.2 launch implementation](https://github.com/johnste/finicky/blob/v4.2.2/apps/finicky/src/browser/launcher.go).
