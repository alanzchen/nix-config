{ hostName, ... }:

{
  # Verified read-only on 2026-08-19: Mac15,10 / M3 Max / arm64.
  # Preserve the Jamf-managed machine identity during the migration.
  networking = {
    computerName = "UTD98207";
    inherit hostName;
    localHostName = "UTD98207";
  };
}
