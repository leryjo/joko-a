# .idx/dev.nix
{ pkgs, ... }: {
  
  # 1. Channel NixOS
  channel = "stable-24.05";

  # 2. Install Docker & Tools
  packages = [
    pkgs.docker
    pkgs.htop
    pkgs.playwright
    pkgs.python312Full
    
    pkgs.chromium
    pkgs.chromedriver

    pkgs.chromium
    pkgs.glib
    pkgs.gtk3
    pkgs.nss
    pkgs.atk
    pkgs.cups
    pkgs.dbus
    pkgs.xorg.libX11
    pkgs.xorg.libXcomposite
    pkgs.xorg.libXdamage
    pkgs.xorg.libXfixes
    pkgs.xorg.libXrandr
    pkgs.xorg.libxcb
    pkgs.pango
    pkgs.cairo
    pkgs.alsa-lib
    pkgs.expat
    pkgs.fontconfig
    pkgs.freetype
  ];

  # 3. Aktifkan Service Docker (WAJIB)
  services.docker.enable = true;
  
  env = {};

  idx = {
    extensions = [
      "ms-python.python"
    ];

    previews = {
      enable = true;
      previews = {};
    };

    workspace = {
      # Event saat Workspace Dibuat
      onCreate = {
        default.openFiles = [ "README.md" "agent.py" ];
      };

      # Event saat Workspace Dinyalakan (Auto-Start Bot)
      onStart = {
        # jembut
        
      };
    };
  };
}