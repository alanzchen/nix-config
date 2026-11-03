{ runCommand }:
runCommand "deeplink-opener" { } ''
  app="$out/Applications/DeepLink Opener.app/Contents"
  mkdir -p "$app/MacOS"
  install -m755 ${../config/finicky/open-url.sh} "$app/MacOS/deeplink-opener"
  cat > "$app/Info.plist" <<'PLIST'
  <?xml version="1.0" encoding="UTF-8"?>
  <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
  <plist version="1.0"><dict>
    <key>CFBundleIdentifier</key><string>ch.zenan.deeplink-opener</string>
    <key>CFBundleName</key><string>DeepLink Opener</string>
    <key>CFBundleExecutable</key><string>deeplink-opener</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSUIElement</key><true/>
  </dict></plist>
  PLIST
''
