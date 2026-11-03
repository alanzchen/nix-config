{ runCommandLocal, src }:

# Homebrew 7 moved version detection into a function; nix-homebrew's existing
# patch targets the old assignments. Keep this aligned with homebrew-src.
runCommandLocal "brew-7.0.3" { version = "7.0.3"; } ''
  cp -R ${src} "$out"
  chmod u+w "$out/Library/Homebrew/brew.sh"
  substituteInPlace "$out/Library/Homebrew/brew.sh" \
    --replace-fail 'set-homebrew-version-from-git' 'HOMEBREW_VERSION="7.0.3"'
''
