{
  config = {
    launchd.agents."test-service" = {
      enable = true;
      config = {
        ProgramArguments = [
          "/some/command"
          "--with-arguments"
          "foo"
        ];
        KeepAlive = {
          Crashed = true;
          SuccessfulExit = false;
        };
        ProcessType = "Background";
        UnrecognizedByHomeManager = "should make it to the resulting plist";
        "\"Special\" characters" = "<should be escaped>";
      };
    };

    nmt.script = ''
      serviceFile=LaunchAgents/org.nix-community.home.test-service.plist
      assertFileExists $serviceFile
      assertFileContains $serviceFile '<key>&quot;Special&quot; characters</key>'
      assertFileContains $serviceFile '<string>&lt;should be escaped&gt;</string>'
      assertFileContains $serviceFile '<key>KeepAlive</key>'
      assertFileContains $serviceFile '<key>Crashed</key>'
      assertFileContains $serviceFile '<true/>'
      assertFileContains $serviceFile '<key>SuccessfulExit</key>'
      assertFileContains $serviceFile '<false/>'
      assertFileContains $serviceFile '<string>org.nix-community.home.test-service</string>'
      assertFileContains $serviceFile '<string>Background</string>'
      # The agent is registered as a per-program trampoline, not a shared shell
      # interpreter, so macOS attributes it to the actual program.
      assertFileRegex $serviceFile '<string>/nix/store/.*-command/bin/command</string>'
      assertFileContains $serviceFile '<key>UnrecognizedByHomeManager</key>'
      assertFileContains $serviceFile '<string>should make it to the resulting plist</string>'

      domainFile=LaunchAgentDomains/org.nix-community.home.test-service.domain
      assertFileExists $domainFile
      assertFileContent $domainFile ${builtins.toFile "expected-domain" "gui\n"}

      assertFileExists activate
      assertRegexOrder() {
        local file="$1"
        local path="$TESTED/$file"
        shift
        local patterns=("$@")
        local index=0
        local line

        while IFS= read -r line; do
          if [[ "$line" =~ ''${patterns[$index]} ]]; then
            index=$((index + 1))
            if [[ "$index" -eq "''${#patterns[@]}" ]]; then
              return 0
            fi
          fi
        done < "$path"

        echo "Expected $file to contain regexes in order: $*" >&2
        return 1
      }

      assertFileContains activate 'readAgentDomain'
      assertFileContains activate 'resolveDomain'
      assertFileContains activate 'agentIsLoaded'
      assertFileContains activate 'alternateDomainName'
      assertFileContains activate 'bootoutDomainIfAvailable'
      assertFileRegex activate '^[[:space:]]*userHasGuiSession()[[:space:]]*{$'
      assertFileRegex activate '^[[:space:]]*/usr/bin/pgrep[[:space:]]*-u[[:space:]]*"\$UID"[[:space:]]*-x[[:space:]]*loginwindow[[:space:]]*>/dev/null[[:space:]]*2>&1$'
      assertFileRegex activate '^[[:space:]]*domainIsAvailable()[[:space:]]*{$'
      assertRegexOrder activate \
        '^[[:space:]]*domainIsAvailable\(\)[[:space:]]*\{$' \
        '^[[:space:]]*gui\)$' \
        '^[[:space:]]*userHasGuiSession$' \
        '^[[:space:]]*user\)$' \
        '^[[:space:]]*return 0$'
      assertFileContains activate 'agentIsLoaded "$newDomain" "$agentName"'
      assertFileContains activate 'is up-to-date but not loaded'
      assertFileContains activate 'is up-to-date but no GUI session is active; skipping bootstrap'
      assertFileContains activate "printf 'gui/%s"
      assertFileContains activate "printf 'user/%s"
      assertFileContains activate 'domainIsAvailable "$newDomainName"'
      assertFileContains activate 'newDomainAvailable=$?'
      assertFileRegex activate '^[[:space:]]*if \[\[ "\$newDomainAvailable" -ne 0 \]\]; then$'
      assertFileContains activate 'installAgentFile "$srcPath" "$dstPath" "$agentName"'
      assertFileContains activate 'Installed agent'
      assertFileContains activate 'no GUI session is active; it will load at next login'
      assertRegexOrder activate \
        'installAgentFile "\$srcPath" "\$dstPath" "\$agentName"' \
        'if \[\[ "\$newDomainAvailable" -ne 0 \]\]; then' \
        'no GUI session is active; it will load at next login' \
        '^[[:space:]]*return 0$' \
        'bootstrapAgent "\$newDomain" "\$dstPath" "\$agentName"'
      assertFileContains activate 'restoreAgent "$oldSrcPath" "$dstPath" "$oldDomain" "$agentName"'
      assertFileContains activate 'bootoutDomainIfAvailable "$newDomainName" "$agentName"'
      assertFileContains activate 'bootoutDomainIfAvailable "$staleDomainName" "$agentName"'
      assertFileContains activate 'has no active GUI session; skipping bootout'
      assertFileContains activate 'domainIsAvailable "$domainName"'
      assertFileContains activate 'bootoutAgent "$domain" "$agentName"'
      assertFileContains activate 'return 2'
      assertFileContains activate 'run rm -f $VERBOSE_ARG "$dstPath"'
      assertRegexOrder activate \
        '^[[:space:]]*bootoutDomainIfAvailable\(\)[[:space:]]*\{$' \
        'if domainIsAvailable "\$domainName"; then' \
        'bootoutAgent "\$domain" "\$agentName"' \
        'has no active GUI session; skipping bootout' \
        '^[[:space:]]*return 2$'
      assertRegexOrder activate \
        'bootoutDomainIfAvailable "\$domainName" "\$agentName"' \
        'if \[\[ "\$staleDomainName" != "\$domainName" \]\]; then' \
        'bootoutDomainIfAvailable "\$staleDomainName" "\$agentName"' \
        'Removing agent file' \
        'run rm -f \$VERBOSE_ARG "\$dstPath"'
      assertFileContains activate 'processAgent "$srcPath" "$dstDir" "$oldDir" "$oldDomainsDir" "$newDomainsDir" \'
      assertFileContains activate '|| launchdStatus=1'
      assertFileContains activate 'done < <(find -L "$newDir" -maxdepth 1 -name'
      assertFileContains activate 'done < <(find -L "$oldDir" -maxdepth 1 -name'
      assertFileContains activate 'if [[ "$launchdStatus" -ne 0 ]]; then'
      assertFileContains activate 'exit "$launchdStatus"'
    '';
  };
}
