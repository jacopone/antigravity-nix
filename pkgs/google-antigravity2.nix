{ callPackage, ... }@args:
let
  filteredArgs = builtins.removeAttrs args [ "callPackage" ];
in
callPackage ./package.nix (filteredArgs // { appType = "Antigravity 2.0"; })
