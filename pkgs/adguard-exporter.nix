{
  pkgs,
  buildGoModule,
  fetchFromGitHub,
}:
with pkgs;


buildGoModule {
  pname = "adguard-exporter";
  version = "master";

  src = fetchFromGitHub {
    owner = "relrod";
    repo = "adguard-exporter";
    rev = "master";
    sha256 = "sha256-gfXxfvO9go/4dtqgyxRIiZNC5aGwz+S2kPS/MpwFcs0=";
  };

  vendorHash = "sha256-nm+B7Qjtx/NHqGuaqVKt2kM9ZvSNYHhTfLxHeu4hlT4=";
  outputs = [ "out" ];

  meta = with pkgs.lib; {
    description = "Prometheus exporter for AdGuard Home";
    homepage = "https://github.com/ebrianne/adguard-exporter";
    license = licenses.mit;
  };
}
