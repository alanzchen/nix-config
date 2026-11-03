{ fetchurl, stdenvNoCC, unzip, lib }:
stdenvNoCC.mkDerivation {
  pname = "winmux-personal";
  version = "0.6.401";
  src = fetchurl {
    url = "https://github.com/alanzchen/winmux/releases/download/v0.6.401/WinMux-0.6.401.zip";
    sha256 = "a268f01d5b3888913e2759c1e39a35f63fcfb41b3fc1568612009a6250884000";
  };
  nativeBuildInputs = [ unzip ];
  sourceRoot = ".";
  dontFixup = true;
  installPhase = ''
    mkdir -p "$out/Applications"
    cp -R WinMux.app "$out/Applications/"
    test -x "$out/Applications/WinMux.app/Contents/Helpers/winmux"
  '';
  meta = {
    description = "Alan's WinMux fork, matching the reference Mac";
    platforms = [ "aarch64-darwin" ];
    license = lib.licenses.mit;
  };
}
