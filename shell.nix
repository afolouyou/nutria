{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  buildInputs = with pkgs; [
    elixir_1_18
    erlang_27
    postgresql_16
    gcc
    gnumake
    pkg-config
    libffi
    openssl
    zlib
  ];

  shellHook = ''
    export PATH="$PWD/tmp/bin:$PATH"
  '';
}
