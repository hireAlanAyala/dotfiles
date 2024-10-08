{ lib, stdenv, fetchurl, unzip, writeShellScript }:

stdenv.mkDerivation rec {
  pname = "win32yank-with-xclip";
  version = "0.1.1";

  src = fetchurl {
    url = "https://github.com/equalsraf/win32yank/releases/download/v${version}/win32yank-x64.zip";
    sha256 = "sha256-M6dHqS2mD7ZeZo7b92YdPZAkEaLVRf6dwIYjzs0UKiA=";
  };

  nativeBuildInputs = [ unzip ];

  unpackPhase = "unzip $src";

  installPhase = ''
    mkdir -p $out/bin
    cp win32yank.exe $out/bin/win32yank.exe
    chmod +x $out/bin/win32yank.exe

    cat > $out/bin/xclip <<EOF
    #!/usr/bin/env bash
    WIN32YANK="$out/bin/win32yank.exe"
    if [ "\$1" = "-selection" ] && [ "\$2" = "clipboard" ]; then
      if [ "\$3" = "-o" ]; then
        \$WIN32YANK -o --lf
      else
        \$WIN32YANK -i --crlf
      fi
    elif [ "\$1" = "-o" ]; then
      \$WIN32YANK -o --lf
    else
      \$WIN32YANK -i --crlf
    fi
    EOF

    chmod +x $out/bin/xclip
  '';
}
