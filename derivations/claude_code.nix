# ../derivations/claude-code.nix
{ lib
, stdenv
, fetchurl
, nodejs_20
, npm
, makeWrapper
}:

stdenv.mkDerivation rec {
  pname = "claude-code";
  version = "1.0.18";

  src = fetchurl {
    url = "https://registry.npmjs.org/@anthropic-ai/claude-code/-/claude-code-${version}.tgz";
    sha256 = "sha256-bY+lkBeGYGy3xLcoo6Hlf5223z1raWuatR0VMQPfxKc=";  # Replace with the output from nix hash to-sri
  };

  nativeBuildInputs = [ nodejs_20 npm makeWrapper ];

  # Unpack and install the npm package
  installPhase = ''
    runHook preInstall
    
    # Create output directories
    mkdir -p $out/lib/node_modules/@anthropic-ai
    mkdir -p $out/bin
    
    # Copy the package to node_modules
    cp -r . $out/lib/node_modules/@anthropic-ai/claude-code
    
    # Install npm dependencies in place
    cd $out/lib/node_modules/@anthropic-ai/claude-code
    npm install --production --ignore-scripts
    
    # Create the binary wrapper
    makeWrapper ${nodejs_20}/bin/node $out/bin/claude \
      --add-flags "$out/lib/node_modules/@anthropic-ai/claude-code/dist/index.js" \
      --prefix PATH : ${lib.makeBinPath [ nodejs_20 ]}
    
    runHook postInstall
  '';

  meta = with lib; {
    description = "Claude Code - Agentic command line tool for delegating coding tasks to Claude";
    homepage = "https://www.anthropic.com/claude-code";
    license = licenses.unfree;  # Commercial license
    platforms = platforms.unix;  # Excludes Windows
    mainProgram = "claude";
  };
}
