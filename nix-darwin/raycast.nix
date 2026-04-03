{
  username,
  homeDirectory,
  ...
}:
{
  system.activationScripts.raycastLoginItem.text = ''
    /usr/bin/sudo -u ${username} env HOME=${homeDirectory} /usr/bin/osascript <<'APPLESCRIPT' >/dev/null 2>&1 || true
    tell application "System Events"
      if not (exists login item "Raycast") then
        make new login item at end with properties {name:"Raycast", path:"/Applications/Nix Apps/Raycast.app", hidden:false}
      end if
    end tell
APPLESCRIPT
  '';
}
