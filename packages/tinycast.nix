{
  fetchurl,
  lib,
  stdenvNoCC,
  _7zz,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "tinycast";
  version = "0.10.23";

  # Official stable Apple-silicon release; checksum from the upstream cask.
  src = fetchurl {
    url = "https://github.com/abue-ammar/tinycast/releases/download/v${finalAttrs.version}/Tinycast-${finalAttrs.version}.dmg";
    hash = "sha256-Oh6CTbllakMqAejnMkaDQsX6MOcJkBhV+ipioCcGcHs=";
  };

  # APFS disk image; exclude extended attributes that 7zz exposes as files.
  nativeBuildInputs = [ _7zz ];
  unpackCmd = "7zz x -snld -xr'!*:com.apple.*' $curSrc";
  sourceRoot = ".";
  dontFixup = true;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/Applications"
    cp -R Tinycast.app "$out/Applications/Tinycast.app"
    runHook postInstall
  '';

  meta = {
    description = "Native macOS launcher, hotkeys, and clipboard history";
    homepage = "https://github.com/abue-ammar/tinycast";
    license = lib.licenses.agpl3Plus;
    platforms = [ "aarch64-darwin" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
})
