{
  fetchurl,
  lib,
  stdenvNoCC,
  unzip,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "winmux";
  version = "0.5.3";

  src = fetchurl {
    url = "https://github.com/ZimengXiong/winmux/releases/download/v${finalAttrs.version}/WinMux-${finalAttrs.version}.zip";
    hash = "sha256-t1sgr1qmCTMzCQkkmHoXGZ4JB8CWKJtJnyaTJkPn3s0=";
  };

  nativeBuildInputs = [ unzip ];

  unpackPhase = ''
    runHook preUnpack
    unzip -q "$src"
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/Applications"
    cp -R WinMux.app "$out/Applications/WinMux.app"
    runHook postInstall
  '';

  meta = {
    description = "Project-based, sidebar-first window manager for macOS";
    homepage = "https://github.com/ZimengXiong/winmux";
    license = lib.licenses.mit;
    platforms = lib.platforms.darwin;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
})
