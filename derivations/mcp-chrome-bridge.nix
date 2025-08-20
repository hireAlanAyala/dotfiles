{ lib, stdenv, nodejs_20, makeWrapper, writeShellScriptBin }:

let
  packageName = "mcp-chrome-bridge";
  version = "1.0.29";
in
writeShellScriptBin packageName ''
  #!${stdenv.shell}
  export PATH="${nodejs_20}/bin:$PATH"
  export NPM_CONFIG_PREFIX="$HOME/.npm-global"
  export PATH="$NPM_CONFIG_PREFIX/bin:$PATH"
  
  # Create npm global directory if it doesn't exist
  mkdir -p "$NPM_CONFIG_PREFIX"
  
  # Check if package is installed in user's npm-global
  if ! [ -f "$NPM_CONFIG_PREFIX/bin/${packageName}" ]; then
    echo "Installing ${packageName}@${version} to ~/.npm-global..."
    npm install -g ${packageName}@${version}
  fi
  
  # Run the command
  exec "$NPM_CONFIG_PREFIX/bin/${packageName}" "$@"
''