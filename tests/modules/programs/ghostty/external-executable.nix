{ ... }:
{
  programs.ghostty = {
    enable = true;
    package = null;
    executable = "/Applications/Ghostty.app/Contents/MacOS/ghostty";

    settings = {
      font-size = 12;
    };
  };

  nmt.script = ''
    assertFileContent \
      home-files/.config/ghostty/config \
      ${builtins.toFile "ghostty-config-expected" ''
        font-size = 12
      ''}

    assertFileContains activate \
      "/Applications/Ghostty.app/Contents/MacOS/ghostty"

    assertFileContains activate \
      "+validate-config --config-file=/home/hm-user/.config/ghostty/config"
  '';
}
