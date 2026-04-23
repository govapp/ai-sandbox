{
  description = "AI Sandbox environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    llm-agents.url = "github:numtide/llm-agents.nix";
  };

  outputs = { self, nixpkgs, llm-agents }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      llm = llm-agents.packages.${system};
      claude-sandbox = pkgs.writeShellScriptBin "claude-sandbox" ''
        exec claude \
          --permission-mode acceptEdits \
          --allowedTools \
            "Read" "Edit" "Write" "MultiEdit" \
            "Glob" "Grep" "LS" "Task" \
            "WebFetch" "WebSearch" \
            "Bash(*)" \
          --disallowedTools \
            "Bash(sudo:*)" \
            "Bash(su:*)" \
            "Bash(rm -rf /)" \
            "Bash(rm -rf /*)" \
          "$@"
      '';

      # Headless Chromium needs fontconfig to find fonts. Without them it
      # renders every glyph at 0x0px, which silently breaks Playwright
      # visibility assertions (the DOM node exists but has no height).
      fonts = with pkgs; [
        dejavu_fonts
        liberation_ttf
        noto-fonts
        noto-fonts-color-emoji
      ];
      fontsConf = pkgs.makeFontsConf { fontDirectories = fonts; };
      # Expose the generated fonts.conf at a stable path inside the profile
      # so FONTCONFIG_FILE in the container can point at it.
      fontsConfPkg = pkgs.runCommand "sandbox-fonts-conf" { } ''
        mkdir -p $out/etc/fonts
        cp ${fontsConf} $out/etc/fonts/fonts.conf
      '';
    in {
      packages.${system}.default = pkgs.buildEnv {
        name = "ai-sandbox-env";
        paths = [
          # System tools
          pkgs.gh
          pkgs.jq
          pkgs.yq
          pkgs.fzf
          pkgs.gnupg
          pkgs.ripgrep
          pkgs.python3
          pkgs.unzip
          pkgs.vim
          pkgs.chromium

          # Fontconfig + fonts for headless Chromium text rendering.
          pkgs.fontconfig
          fontsConfPkg

          # Direnv support
          pkgs.direnv
          pkgs.nix-direnv

          # AI tools from llm-agents.nix
          llm.claude-code
          llm.claude-plugins
          llm.opencode

          # Convenience wrapper
          claude-sandbox
        ] ++ fonts;
      };
    };
}
