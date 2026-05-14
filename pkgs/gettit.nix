{
  lib,
  buildGoModule,
  pkgs,
}:

buildGoModule {
  pname = "gettit";
  version = "0.1";

  src = pkgs.fetchFromRadicle {
    seed = "seed.boers.email";
    repo = "z24gQBBitUHvTz4y8t4JrCNCPrfpG";
    rev = "d1f2fd0c7f145a56da757a72c6792c5547611f12";
    hash = "sha256-m4JW3m4JYcGcGtMO75ncB88cRLYy4AcNa3eKFnIioVI=";
  };

  vendorHash = "sha256-ueFiuCj9j/bYaEY+TpjRuEt2Wk+myW5eDRz91PhjUxo=";

  ldflags = [
    "-s"
    "-w"
  ];

  meta = with lib; {
    description = "Forensicly download website";
    homepage = "https://git.boers.email/nodes/seed.boers.email/rad:z24gQBBitUHvTz4y8t4JrCNCPrfpG/";
    license = licenses.mpl20;
    mainProgram = "gettit";
  };
}
