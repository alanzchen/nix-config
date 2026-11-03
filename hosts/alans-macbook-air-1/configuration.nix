{ hostName, ... }:

{
  networking = {
    computerName = "Alan's MacBook Air";
    inherit hostName;
    localHostName = "alans-macbook-air-1";
  };
}
