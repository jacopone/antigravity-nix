{ callPackage, ... }@args:
let
  filteredArgs = removeAttrs args [ "callPackage" ];
in
callPackage ./package.nix (filteredArgs // { appType = "Antigravity 2.0"; })
