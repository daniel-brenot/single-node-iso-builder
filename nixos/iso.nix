{
  config,
  lib,
  modulesPath,
  pkgs,
  autoUpdaterBinary,
  ...
}:

let
  autoUpdater = pkgs.stdenvNoCC.mkDerivation {
    pname = "auto-updater";
    version = "latest";
    src = autoUpdaterBinary;
    dontUnpack = true;

    installPhase = ''
      install -Dm755 "$src" "$out/bin/auto-updater"
    '';
  };
in
{
  imports = [
    "${modulesPath}/installer/cd-dvd/iso-image.nix"
    "${modulesPath}/profiles/base.nix"
    "${modulesPath}/profiles/minimal.nix"
  ];

  image.fileName = lib.mkForce "single-node-k3s-${pkgs.stdenv.hostPlatform.system}.iso";

  isoImage = {
    volumeID = "SN_K3S_ISO";
    makeEfiBootable = true;
    makeUsbBootable = true;
  };

  hardware = {
    enableAllHardware = true;
    enableRedistributableFirmware = lib.mkDefault true;
  };

  swapDevices = lib.mkImageMediaOverride [ ];
  fileSystems = lib.mkImageMediaOverride config.lib.isoFileSystems;
  boot.initrd.luks.devices = lib.mkImageMediaOverride { };

  networking = {
    hostName = "single-node-k3s";
    networkmanager.enable = true;

    firewall = {
      enable = true;
      allowedTCPPorts = [
        22
        6443
        10250
      ];
      allowedTCPPortRanges = [
        {
          from = 30000;
          to = 32767;
        }
      ];
      allowedUDPPorts = [
        8472
      ];
    };
  };

  time.timeZone = "UTC";

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = true;
      PermitRootLogin = "no";
    };
  };

  services.k3s = {
    enable = true;
    role = "server";
    clusterInit = true;
    extraFlags = [
      "--data-dir=/persistent/k3s"
      "--write-kubeconfig-mode=0644"
      "--node-name=single-node-k3s"
    ];
  };

  systemd.services.k3s = {
    wantedBy = lib.mkForce [ ];
    after = [
      "network-online.target"
      "systemd-tmpfiles-setup.service"
    ];
    wants = [
      "network-online.target"
    ];
  };

  systemd.tmpfiles.rules = [
    "d /persistent 0755 root root -"
    "d /persistent/k3s 0755 root root -"
    "d /versions 0755 root root -"
  ];

  system.activationScripts.singleNodeIsoVersion.text = ''
    mkdir -p /versions
    ${pkgs.coreutils}/bin/install -Dm755 ${autoUpdater}/bin/auto-updater /versions/auto-updater
    auto_updater_hash="$(${pkgs.coreutils}/bin/sha256sum /versions/auto-updater)"
    printf '%s\n' "''${auto_updater_hash%% *}" > /versions/auto-updater.sha256

    cat > /versions/current-system <<EOF
    system=${pkgs.stdenv.hostPlatform.system}
    nixos=${config.system.nixos.version}
    label=${config.system.nixos.label}
    EOF
  '';

  users.users.nixos = {
    isNormalUser = true;
    initialHashedPassword = lib.mkForce null;
    initialPassword = "nixos";
    extraGroups = [
      "networkmanager"
      "video"
      "wheel"
    ];
  };

  security.sudo.wheelNeedsPassword = false;

  systemd.services."getty@tty1".enable = false;

  systemd.services.auto-updater-console = {
    description = "Run auto-updater on the primary console";
    wantedBy = [
      "multi-user.target"
    ];
    after = [
      "network-online.target"
      "systemd-tmpfiles-setup.service"
    ];
    wants = [
      "network-online.target"
    ];
    conflicts = [
      "getty@tty1.service"
    ];

    serviceConfig = {
      ExecStart = "${autoUpdater}/bin/auto-updater";
      Restart = "always";
      RestartSec = "2s";
      StandardInput = "tty";
      StandardOutput = "tty";
      StandardError = "tty";
      TTYPath = "/dev/tty1";
      TTYReset = true;
      TTYVHangup = true;
      TTYVTDisallocate = true;
    };
  };

  environment = {
    systemPackages = [
      autoUpdater
    ] ++ (with pkgs; [
      curl
      git
      jq
      k3s
      kubectl
      vim
    ]);

    variables.KUBECONFIG = "/etc/rancher/k3s/k3s.yaml";

    etc."single-node-k3s-iso/README".text = ''
      This live ISO starts a single-node k3s server on boot.

      Login user:
        username: nixos
        password: nixos

      Runtime directories:
        /persistent - k3s data lives under /persistent/k3s
        /versions   - auto-updater and build metadata are written here

      kubeconfig:
        /etc/rancher/k3s/k3s.yaml
    '';
  };

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
}
