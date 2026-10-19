{pkgs, ...}: {
  # Side-by-side with programs.weylus; no autostart or service replacement.
  home.packages = [(pkgs.callPackage ../../modules/weylus {})];
}
