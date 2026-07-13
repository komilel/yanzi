{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    android-studio
    android-tools
    dotnet-sdk_10
    libGLU
    plantuml
  ];

  environment.sessionVariables = {
    DOTNET_ROOT = "${pkgs.dotnet-sdk_10}/share/dotnet";
    DOTNET_ROOT_X64 = "${pkgs.dotnet-sdk_10}/share/dotnet";
  };

  environment.etc = {
    "dotnet/install_location".text = "${pkgs.dotnet-sdk_10}/share/dotnet\n";
    "dotnet/install_location_x64".text = "${pkgs.dotnet-sdk_10}/share/dotnet\n";
  };
}
