# Set up a new personal Mac

The reference Mac is the template. `personal-new` is a separate full personal
profile; the existing personal and work profiles keep their current scope.
The installer refuses to activate `personal-new` on `alans-macbook-air-1`.

## First-run prerequisites

1. Use an administrator account on an Apple-silicon Mac.
2. Install and unlock 1Password. Under **Settings > Developer**, enable the
   **SSH agent** and **Integrate with 1Password CLI**. The installer supplies
   the CLI; the manually installed GUI stays vendor-managed.
3. No GitHub login is required to download the public configuration. Sign into
   the 1Password accounts containing your mapped keys (including Hermes).
   Keep the account recovery material available separately.
4. Run the single command in `scripts/new-mac-command.txt` in Terminal. That
   command downloads the small, readable `scripts/clone-and-setup.sh` launcher;
   it contains no credential. It can install Apple's command-line developer
   tools, wait for the installer, clone over public HTTPS, and start setup.

There will still be interactive Apple installer/admin prompts, 1Password
authorization prompts, macOS app permissions, and application sign-ins.
These are not bypassed or reported as already granted.

For a folder already copied to the destination, the equivalent command is:

```sh
bash ~/Developer/nix-config/scripts/bootstrap-mac.sh
```

Preview the operations without changing the machine:

```sh
bash scripts/bootstrap-mac.sh --plan
```

## What the installer does

- Installs upstream multi-user Nix when absent. Keeps `flake.lock` unchanged.
- Writes the destination account and current machine names to
  `hosts/personal-new/identity.json`. This file is intentionally local to that
  checkout after setup; review it before committing any later changes.
- Builds and activates `personal-new`, including the existing personal package
  and application baseline, plus Basecamp, BetterDisplay, standalone Tailscale,
  Hammerspoon, 1Password CLI, Claude Code CLI, and Codex CLI.
- Uses the pinned tap's CLI releases, not a copy of mutable local executables.
  They may differ from the reference Mac's self-updated versions.
- Installs version 0.6.401 of the personal WinMux fork and uses that app's own
  bundled CLI. This is the version observed on the reference Mac. The older
  `packages/winmux.nix` remains the official-release fallback.
- Seeds the captured WinMux preferences and project labels on first install.
  Monitor identifiers are omitted; `wm-toggle` owns login restoration. Existing
  live settings are not overwritten. First activation does not require WinMux
  to start successfully before its Accessibility permission is granted.
- Installs the existing Karabiner and Hammerspoon configurations.
- Seeds portable VS Code settings/keybindings and installs the captured 64
  extension IDs. Later runs preserve edited settings and retry missing
  extensions. Versions come from the marketplace, not archived extension files.
- Configures SSH to use the 1Password agent, with local host overrides in
  `~/.ssh/config.d/`. Declares the GitHub, Colab and Hermes HPC items in
  `~/.config/1Password/ssh/agent.toml`. No private keys are exported.
- Adds portable aliases for comma/comma3, oracle, alan-mac-studio, work-mbp,
  oracle-ts, ganymede2 and juno. HPC uses its mapped public key and the local
  1Password agent through the existing Oracle jump host, without agent forwarding.
  Existing trusted host keys are retained in a separate known-hosts file.
- Installs AgentsView 0.45.0 from the upstream Apple-silicon archive, verified by
  its published SHA-256. Declares an authenticated Tailscale spoke at login,
  using the destination's own address and separate mutable state.
- Installs a Colab 0.6.0 wrapper with all Python dependencies locked in
  `packages/colab/uv.lock`. Bootstrap downloads and warms its user environment;
  this requires PyPI network access after the Nix build. It does not sign in.
- Resolves all mapped SSH public keys in one `op inject` invocation. Later
  verification is local and does not prompt for another vault session.
  Exit status 2 means local setup checks need attention.

Run `scripts/install-app-store.sh` after App Store sign-in for the already
declared Fantastical, Slack, and WhatsApp apps. They are deliberately deferred
so App Store authentication cannot block the entire system activation.

## Credentials

Use 1Password as the primary secret store. Keep reference-only environment
files outside this checkout, for example `~/.config/secrets/project.env`:

```dotenv
SERVICE_TOKEN="op://Vault Name/Item Name/token"
```

Run only the command that needs those credentials:

```sh
with-secrets ~/.config/secrets/project.env command argument
```

`with-secrets` rejects plaintext values and delegates injection to `op run`.
Secret values do not enter Nix evaluation, the Nix store, system activation,
or a global shell startup file. Do not put an `op read` substitution into a
Nix derivation. App authentication sessions, Keychain items and device identity
remain owned by their applications.

Vault access was confirmed on November 2 after the app integration was enabled.
`op whoami` still reported not signed in while authenticated vault/item reads
succeeded. It is not used as a prerequisite. An explicit `op vault list` is a
useful interactive diagnostic, but normal verification does not query the vault.
`config/migration/credentials.json` contains item identifiers and public-key
references only. It maps the existing GitHub, Basecamp, and Tailscale logins and
records two OpenAI login candidates without choosing an account automatically.
Website login passwords are not treated as API keys or device enrollment tokens.
Unrelated service-vault API credentials are not injected into this Mac's shell.

The mapped SSH key's public portion matches the reference Git signing key.
The setup step selects that key specifically for GitHub using a public `.pub`
file and `IdentitiesOnly`. This comparison does not prove the key has access to
every remote repository. Check an SSH connection on the destination. No private
keys or new vault items were imported during the mapping audit.

The Colab key was imported into 1Password. On November 3, the existing Hermes
SSH item `id_ed25519_utd_hpc` was verified to match the local HPC public key.
The new profile replaces HPC's old local private-key path and `IdentityAgent none`
with the mapped public identity and local 1Password agent. Existing host-key
aliases, strict checks, jump host, username and timeouts are retained. macOS
Keychain passphrase settings are unnecessary for an agent-held key. Test the
connections on the destination; captured host keys can change, and local
configuration does not prove remote authorization or satisfy server-side MFA.

`config/migration/tool-credentials.json` records the selected tools' credential
decisions. Colab 0.6.0 uses Google OAuth with a native refresh-token cache; it
does not need a standalone API token. Use a fresh Google sign-in rather than
copying `token.json`, session tokens or old runtime endpoints. The metadata
search found no AgentsView-titled 1Password item. The user chose a new per-device
AgentsView token, to be saved in 1Password later. No vault writes were needed for
this expansion, and no unrelated service-vault credentials were assigned.

Desktop CLI authorization is session-bound, not permanent: it expires after
10 minutes of inactivity, has a 12-hour maximum, and is revoked on app lock.
For unattended work, a separate service account can have read-only access to a
dedicated automation vault. Service accounts cannot access built-in Private,
Personal, Employee, or default Shared vaults. Such an account has not been
created by this installer, and its token must stay outside Git and the Nix store.
See [1Password's authorization model](https://developer.1password.com/docs/cli/app-integration-security/)
and [service-account limitations](https://developer.1password.com/docs/service-accounts/get-started/).

### Batched import and export

The intended workflow is one reviewed import session on the reference Mac and
one export session on the new Mac. Reuse the same terminal for each batch.
Preparation and routine validation do not query 1Password, and existing login
items are not rewritten. One approval is the aim; expiry, app locking, separate
accounts, and SSH-agent authorization can still produce another prompt.

The import plan contains only the Colab SSH key, successfully imported on
November 2. HPC reuses the existing Hermes SSH key item, so no duplicate import
or passphrase retrieval is needed. Both original local keys remain unchanged.
Preview it without accessing 1Password or reading private-key contents:

```sh
python3 scripts/import-credentials.py
```

After reviewing that plan, the write step is:

```sh
bash scripts/import-credentials.sh --apply
```

The script performs one tagged metadata lookup for retry safety, validates all
missing keys locally, and submits them together through stdin to one
`op item create` call. Values never appear in command arguments or output.
It leaves original keys in place and does not edit existing vault items.
Passphrase-protected OpenSSH keys are decrypted in memory using the pinned
`credential-python` runtime; originals are never decrypted on disk. Map their
passphrase to the correct 1Password reference before the batch, or use
`--prompt-passphrases` to type it locally with echo disabled. Do not paste a
passphrase into chat. This is unnecessary for the already-stored HPC key.

Successful creation updates the local reference map from the returned item IDs,
without a follow-up vault read. Commit and push the reference-map change before
running setup on the destination. The new Mac exports the GitHub, Colab, and HPC
public keys in one invocation and leaves private-key operations to the SSH agent.
The declared agent configuration includes the HPC item from Hermes. Host routing
is configured, but actual remote SSH sessions remain destination acceptance checks.

Import is not a remote transaction: if the CLI reports partial success or times
out, rerunning first checks the tagged items rather than blindly creating them
again. The local receipt contains identifiers only.

## Colab SSH and AgentsView

The installed Colab 0.6.0 CLI communicates through runtime APIs; its command
table has no `ssh` subcommand. The reference `colab-ssh` alias is a separate
Cloudflare tunnel setup. The old temporary hostname is intentionally omitted.
After starting a new runtime's SSH server/tunnel and authorizing the public key
from `~/.ssh/1password-colab.pub`, run:

```sh
colab-ssh-config CURRENT.trycloudflare.com
ssh colab-ssh
```

The helper updates only its own `30-colab.conf`, preserving custom files. It uses
the declared cloudflared executable and the 1Password public identity. Verify the
runtime's host-key fingerprint when prompted; host checking is no longer disabled.
This helper does not provision a remote SSH server or spend Colab compute units.
Run `colab sessions` for the initial Google sign-in when you are ready.

The `io.agentsview.nix-spoke` launch agent waits for Tailscale to be running,
then binds to that Mac's Tailscale IPv4 address on port 18082. It preserves the
reference service's `--no-browser --no-sync` behavior and disables telemetry.
The upstream binary generates a new native auth token under
`~/.local/share/agentsview-nix/config.toml`; the service never calls 1Password.
Save that token to 1Password locally later and register the new address/token
with your existing hub. Do not paste the token into chat or commit the config.
The new archive starts empty; history transfer and remote hub changes are not
performed by this installer. Existing `~/.agentsview` data remains separate.

Only one service can occupy the chosen address/port. If an existing AgentsView
service already uses it, review which service to keep before enabling the new
one; this configuration does not stop or replace unrelated services.

Sources: [1Password agent selection](https://www.1password.dev/ssh/agent/config),
[AgentsView 0.45.0](https://github.com/kenn-io/agentsview/releases/tag/v0.45.0),
[Colab CLI](https://github.com/googlecolab/google-colab-cli).

## Settings requiring a supported export or fresh approval

- Finicky rules mirror Scriptable's DeepLink URL decoding: Mail links go to Mail,
  web links to Safari, and other schemes to their registered Mac application via
  the bundled DeepLink Opener. The Scriptable DeepLink source is also saved in
  `config/scriptable/DeepLink.js`. Set Finicky as the default web browser after
  installation; verify representative Mail and app links. Apps that only exist
  on iOS still need an appropriate Mac counterpart. See `config/finicky/README.md`.
- Use each browser's sync for profiles/extensions. Cookies and session databases
  are not copied into Nix. Browser sync still requires sign-in.
- Launcher configuration and licensed BetterDisplay state have not been
  exported. Display identifiers/layouts are hardware-dependent; configure them
  on the destination. Do not copy entire preference plists containing licenses.
- Ghostty's reference config has no active settings; no artificial terminal
  customization is added.
- Hammerspoon's shortcut targets `com.openai.codex` and expects the current
  app's Quick Chat shortcut and English accessibility labels. Check this after
  app sign-in, and grant its Accessibility permission.
- VS Code remote-host mappings, the old Settings Sync gist, the obsolete R/rye
  path, machine-specific environment values, a cloud project ID, and terminal
  auto-approval rules were omitted. R uses the declared Homebrew R installation;
  JetBrains Mono is the available font fallback.
- Colab and AgentsView are now declared. The remaining entries in
  `config/migration/local-tools.json`, such as `chatgpt-history`, instsci,
  textfold and Oracle CLI, still need individual packaging decisions.
- Snapclient and Queqiao startup were not selected and are not migrated.

## Verification and recovery

From the new checkout:

```sh
python3 scripts/setup-user.py verify .
wm-toggle on
wm-toggle status
```

Verification checks the selected application/command inventory, all three
public-key files, agent selection, managed SSH routes and trusted keys, Colab's
environment, recorded extension/install failures, and local launch-agent state.
It makes no vault calls or remote connections. Findings and manual approvals
are saved to `~/.local/state/mac-bootstrap/verification.json`; exit code 2 means
there are pending findings. macOS permissions and sign-ins remain explicit
manual checks, not claims inferred from installation. An existing local `colab`
or `agentsview` executable that shadows the declared version is reported.

Check Caps Lock navigation and app shortcuts, Control-Option-Space, browser
routing, Tailscale connectivity, and a representative SSH connection manually.
Home Manager backs up conflicting owned files with `.before-nix`; mutable
editor and WinMux files are seeded only when absent. If a previous backup
already exists, resolve that conflict rather than deleting it automatically.
The bootstrap can be rerun; it does not automatically pull over local edits.

Repository validation (Python 3.11+):

```sh
python3 scripts/tests/test_migration.py
for test in config/winmux/tests/*.sh; do bash "$test"; done
nix-instantiate --parse --eval --strict modules/window-manager.nix >/dev/null
nix build .#darwinConfigurations.personal-new.system --no-link --no-write-lock-file
nix build .#darwinConfigurations.alans-macbook-air-1.system --no-link --no-write-lock-file
```

Build checks do not prove successful clean-machine activation, Homebrew
downloads, App Store authentication, or hardware permissions. A real new-Mac
run remains the final acceptance check.
