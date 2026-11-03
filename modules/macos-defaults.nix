{ lib, username, ... }:

{
  system.defaults = {
    NSGlobalDomain = {
      AppleInterfaceStyleSwitchesAutomatically = true;
      ApplePressAndHoldEnabled = false;
      InitialKeyRepeat = 15;
      KeyRepeat = 2;
      _HIHideMenuBar = false;
    };

    CustomUserPreferences = {
      "com.apple.controlcenter" = {
        AutoHideMenuBarOption = 3;
      };

      "com.apple.desktopsettings.menubar" = {
        AppleMenuBarVisibleInFullscreen = true;
      };

      NSGlobalDomain = {
        AppleMenuBarVisibleInFullscreen = true;
      };
    };

    dock = {
      autohide = true;
      mru-spaces = false;
      orientation = "bottom";
      show-recents = false;
      tilesize = 48;
    };

    finder = {
      AppleShowAllExtensions = true;
      FXEnableExtensionChangeWarning = false;
      FXPreferredViewStyle = "Nlsv";
      ShowPathbar = true;
      ShowStatusBar = true;
    };

    trackpad = {
      Clicking = true;
      TrackpadRightClick = true;
      TrackpadThreeFingerDrag = true;
    };

    screencapture.location = "~/Desktop";
  };

  system.activationScripts.postActivation.text = lib.mkAfter ''
    echo >&2 "refreshing menu bar defaults..."
    killall -qu ${username} cfprefsd || true
    killall -qu ${username} ControlCenter || true
    killall -qu ${username} SystemUIServer || true
    sleep 1
    launchctl asuser "$(id -u ${username})" sudo -u ${username} --set-home /usr/bin/osascript -l JavaScript <<'APPLESCRIPT' || true
    ObjC.import("Foundation");
    const center = $.NSDistributedNotificationCenter.defaultCenter;
    center.postNotificationNameObjectUserInfoOptions("AppleInterfaceMenuBarHidingChangedNotification", null, null, 1);
    center.postNotificationNameObjectUserInfoOptions("AppleInterfaceFullScreenMenuBarVisibilityChangedNotification", null, null, 1);
    APPLESCRIPT
  '';
}
