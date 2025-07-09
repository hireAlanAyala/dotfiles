{ lib
, buildGoModule
, fetchFromGitHub
}:

buildGoModule rec {
  pname = "discordo";
  version = "unstable-2025-07-02";

  src = fetchFromGitHub {
    owner = "ayn2op";
    repo = "discordo";
    rev = "d701e7d15ba07457aa41ab1d1d02ce2c565c7736";
    hash = "sha256-E8Et8w8ebDjNKPnPIFHC+Ut2IfOCnNJKRwVFUVNf7+8=";
  };

  vendorHash = "sha256-X1/NjLI16U9+UyXMDmogRfIvuYNmWgIJ40uYo7VeTP0=";

  # Meta information
  meta = with lib; {
    description = "A lightweight Discord terminal client";
    homepage = "https://github.com/ayn2op/discordo";
    license = licenses.gpl3Only;
    maintainers = [ ];
    platforms = platforms.unix;
    mainProgram = "discordo";
  };
}
