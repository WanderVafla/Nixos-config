{ lib, rustPlatform }:

rustPlatform.buildRustPackage {
  pname = "dot-greeter";
  version = "0.1.0";

  src = lib.cleanSource ./.;
  cargoLock.lockFile = ./Cargo.lock;

  doCheck = true;

  meta = {
    description = "Minimal console greeter for greetd that shows nothing but dots";
    license = lib.licenses.gpl3Only;
    mainProgram = "dot-greeter";
  };
}
