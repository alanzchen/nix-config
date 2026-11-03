# Set up a new personal Mac

The reference Mac is the template. `personal-new` is a separate full personal
profile; the existing personal and work profiles keep their current scope.
The installer refuses to activate `personal-new` on `alans-macbook-air-1`.

## First-run prerequisites

1. Use an administrator account on an Apple-silicon Mac.
2. Install and unlock 1Password. Under **Settings > Developer**, enable the
   **SSH agent** and **Integrate with 1Password CLI**. The installer supplies
   the CLI; the manually installed GUI stays vendor-managed.
3. The SSH key in 1Password must have access to the private
   `alanzchen/nix-config` GitHub repository. An account password alone does not
   give SSH access. Keep the account recovery material available separately.
4. Run the single command in `scripts/new-mac-command.txt` in Terminal. That
   command embeds the small, readable `scripts/clone-and-setup.sh` launcher;
   it contains no credential. It can install Apple's command-line developer
   tools, wait for the installer, clone via the 1Password agent, and start setup.

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
  `~/.ssh/config.d/`. Reads only the mapped public key to configure GitHub key
  selection; no private keys are exported. Existing custom routing is preserved.
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
`config/migration/credentials.json` contains item identifiers and a public-key
reference only. It maps the existing GitHub, Basecamp, and Tailscale logins and
records two OpenAI login candidates without choosing an account automatically.
Website login passwords are not treated as API keys or device enrollment tokens.
Unrelated service-vault API credentials are not injected into this Mac's shell.

The mapped SSH key's public portion matches the reference Git signing key.
The setup step selects that key specifically for GitHub using a public `.pub`
file and `IdentitiesOnly`. This comparison does not prove the key has access to
every remote repository. Check an SSH connection on the destination. No private
keys or new vault items were imported during the mapping audit.

SSH exceptions also need review: the reference configuration includes a local
Colab key and HPC connections that explicitly use a local key and disable the
agent. Both local public keys differ from the mapped vault key. These host
blocks are not copied because their dependencies would be
missing. Import suitable keys into 1Password deliberately, configure host key
selection, and verify each connection. Unattended services may need a scoped
service account or their native credential store rather than an interactive
unlock. Never store a service-account bootstrap token in this repository.

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

The prepared import plan currently contains the HPC and Colab SSH keys only.
Preview it without accessing 1Password or reading private-key contents:

```sh
python3 scripts/import-credentials.py
```

After reviewing that plan, the write step is:

```sh
python3 scripts/import-credentials.py --apply
```

The script performs one tagged metadata lookup for retry safety, validates all
missing keys locally, and submits them together through stdin to one
`op item create` call. Values never appear in command arguments or output.
It leaves original keys in place and does not edit existing vault items.
Passphrase-protected keys need separate preparation and cause the batch to stop
before writing. No import has yet been executed or live-tested.

Successful creation updates the local reference map from the returned item IDs,
without a follow-up vault read. Commit and push the reference-map change before
running setup on the destination. The new Mac exports public keys only in one
invocation and leaves private-key operations to the SSH agent. Additional HPC
host routing and the Colab tool's dynamic connection setup still need validation
before those connections can be called migrated.

Import is not a remote transaction: if the CLI reports partial success or times
out, rerunning first checks the tagged items rather than blindly creating them
again. The local receipt contains identifiers only.

## Settings requiring a supported export or fresh approval

- Finicky rules are managed. Set Finicky as the default web browser after
  installation; then verify the mail-link route.
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
- `config/migration/local-tools.json` inventories additional tools without
  copying executables. Local-project commands such as `chatgpt-history`, and
  npm/uv/custom tools still need individual packaging decisions.
- Third-party launch agents are not bulk-copied. In particular, the existing
  Snapclient, AgentsView, and Queqiao entries require ownership, executable,
  active/disabled state, and secret checks before inclusion. A plist's presence
  does not prove that its service should run on the new Mac.

## Verification and recovery

From the new checkout:

```sh
python3 scripts/setup-user.py verify .
op vault list
wm-toggle on
wm-toggle status
```

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
