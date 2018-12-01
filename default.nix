with import <nixpkgs> {}; {
  sdlEnv = stdenv.mkDerivation {
    name = "alephium-ops";
    shellHook = ''
      export NIX_LABEL="alephium-ops"
      export AWS_CONFIG_FILE=./.aws/config
    '';
    buildInputs = [
      awscli docker ipcalc jq openssh
    ];
  };
}
