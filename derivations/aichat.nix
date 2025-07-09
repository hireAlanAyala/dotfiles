{ lib, stdenv, fetchurl }:

stdenv.mkDerivation rec {
  pname = "aichat";
  version = "0.28.0";

  src = fetchurl {
    url = "https://github.com/sigoden/aichat/releases/download/v${version}/aichat-v${version}-x86_64-unknown-linux-musl.tar.gz";
    sha256 = "0ijjcv5qcia8bc26jwc1gg8645bq7ksqvj345bc8mzmxhcgfd3s8";
  };

  sourceRoot = ".";

  installPhase = ''
    mkdir -p $out/bin
    tar xf $src
    install -m755 aichat $out/bin/aichat
  '';

  meta = with lib; {
    description = "A CLI tool for chatting with AI models";
    homepage = "https://github.com/sigoden/aichat";
    license = licenses.mit;
    platforms = platforms.linux;
    maintainers = [ maintainers.yourgithubusername ];
  };
}
