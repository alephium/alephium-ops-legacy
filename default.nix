with import <nixpkgs> {}; {
  sdlEnv = stdenv.mkDerivation {
    name = "alephium-ops";
    shellHook = ''
      export NIX_LABEL="alephium-ops"
      export AWS_CONFIG_FILE=./.aws/config
      source .env/bin/activate
    '';
    buildInputs = [
      awscli
      ipcalc jq openssh
      python3 python35.pkgs.pip python35.pkgs.virtualenv
      # optional
      pssh ws
    ];
  };
}
