{
  lib,
  stdenvNoCC,
  fetchurl,
}:
stdenvNoCC.mkDerivation {
  pname = "agentsview";
  version = "0.45.0";
  src = fetchurl {
    url = "https://github.com/kenn-io/agentsview/releases/download/v0.45.0/agentsview_0.45.0_darwin_arm64.tar.gz";
    hash = "sha256-wrWiTU/ERVplbFTxaw4oH4lMZI+KA5+lLnakfh4YMVs=";
  };
  sourceRoot = ".";
  dontBuild = true;
  dontStrip = true;
  installPhase = ''
    runHook preInstall
    install -Dm755 agentsview "$out/bin/agentsview"
    runHook postInstall
  '';
  meta = {
    description = "Pinned AgentsView CLI matching the reference Mac";
    homepage = "https://github.com/kenn-io/agentsview";
    platforms = [ "aarch64-darwin" ];
    license = lib.licenses.mit;
    mainProgram = "agentsview";
  };
}
