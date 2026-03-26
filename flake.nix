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

          # Direnv support
          pkgs.direnv
          pkgs.nix-direnv

          # AI tools from llm-agents.nix
          llm.claude-code
          llm.claude-plugins
          llm.opencode

          # Convenience wrapper
          claude-sandbox
        ];
      };
    };
}
