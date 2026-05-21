{ callPackage, ... }@args:
let
  filteredArgs = builtins.removeAttrs args [ "callPackage" ];
in
callPackage ./package.nix (filteredArgs // { appType = "Antigravity IDE"; })
