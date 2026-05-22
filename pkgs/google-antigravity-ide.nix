{ callPackage, ... }@args:
let
  filteredArgs = removeAttrs args [ "callPackage" ];
in
callPackage ./package.nix (filteredArgs // { appType = "Antigravity IDE"; })
