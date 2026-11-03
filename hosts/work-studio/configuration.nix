{ hostName, ... }:

{
  # Verified read-only on 2026-08-19: Mac14,14 / M2 Ultra / arm64.
  # ComputerName and HostName intentionally differ on the live machine.
  networking = {
    computerName = "JSOM98196";
    inherit hostName;
    localHostName = "JSOM98196";
  };
}
