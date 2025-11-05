{ pkgs, fetchFromGitHub }:

let
  claude-code-src = fetchFromGitHub {
    owner = "sadjow";
    repo = "claude-code-nix";
    rev = "main";
    sha256 = "sha256-Eq5hbRoOvO9cVpeExOyoysQhxScYe8kpgzfj1ZKnArk=";
  };
in
  pkgs.callPackage "${claude-code-src}/package.nix" {}
