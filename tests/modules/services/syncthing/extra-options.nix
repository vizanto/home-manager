{ lib, pkgs, ... }:

lib.mkMerge [
  {
    test.stubs.writers = {
      extraAttrs.writeBash = (_name: _fn: "@syncthing-wrapper@");
    };

    services.syncthing = {
      enable = true;
      extraOptions = [
        "-foo"
        ''-bar "baz"''
      ];
    };
  }

  (lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
    nmt.script = ''
      assertFileExists home-files/.config/systemd/user/syncthing.service
      assertPathNotExists home-files/.config/systemd/user/syncthing-init.service
      assertPathNotExists home-files/.config/systemd/user/default.target.wants/syncthing-init.service
      assertFileContains home-files/.config/systemd/user/syncthing.service \
      "ExecStart=@syncthing@/bin/syncthing serve --no-browser --no-restart --no-upgrade '--gui-address=127.0.0.1:8384' -foo '-bar \"baz\"'"
    '';
  })

  (lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
    nmt.script = ''
      serviceFile=LaunchAgents/org.nix-community.home.syncthing.plist
      assertFileExists "$serviceFile"
      assertPathNotExists LaunchAgents/org.nix-community.home.syncthing-init.plist

      # The agent registers a per-program trampoline rather than a shared shell
      # interpreter, so macOS attributes Login Items and privacy grants to
      # syncthing itself instead of to a common /nix/store bash.
      assertFileRegex "$serviceFile" '<string>/nix/store/.*-syncthing/bin/syncthing</string>'

      # The trampoline compiles argv in, so it records the resolved command
      # line next to the binary; the plist no longer carries it.
      launcher=$(sed -n \
        's|.*<string>\(/nix/store/[^<]*/bin/syncthing\)</string>.*|\1|p' \
        "$TESTED/$serviceFile" | head -1)
      commandFile="''${launcher%/bin/*}/command"
      if [[ ! -f "$commandFile" ]]; then
        echo "Expected the trampoline to record its argv at $commandFile" >&2
        exit 1
      fi
      if ! grep -qF -- ${lib.escapeShellArg "serve --no-browser --no-restart --no-upgrade '--gui-address=127.0.0.1:8384' -foo '-bar \"baz\"'"} "$commandFile"; then
        echo "Expected $commandFile to carry the extra options, got:" >&2
        cat "$commandFile" >&2
        exit 1
      fi
    '';
  })
]
