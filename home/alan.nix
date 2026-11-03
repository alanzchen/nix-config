{
  pkgs,
  username,
  homeDirectory,
  ...
}:

{
  home = {
    inherit username homeDirectory;
    stateVersion = "25.05";

    sessionVariables = {
      EDITOR = "code --wait";
      VISUAL = "code --wait";
      PAGER = "less -R";
    };

    sessionPath = [
      "$HOME/.local/bin"
      "$HOME/.elan/bin"
      "$HOME/.codeium/windsurf/bin"
      "/opt/homebrew/bin"
      "/opt/homebrew/sbin"
      "/opt/homebrew/opt/postgresql@17/bin"
    ];
  };

  programs.home-manager.enable = true;

  # Finicky is the macOS HTTP(S) router. Keep the rule source in this flake so
  # its DeepLink behaviour is reproducible after a new-machine activation.
  home.file.".finicky.js".source = ../config/finicky/finicky.js;

  programs.git = {
    enable = true;
    lfs.enable = true;
    settings = {
      user = {
        name = "Alan Chen";
        email = "github@zenan.ch";
        signingkey = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDSBLUX++J242uAxn+/6eKnRZk7UBmipWWJK2TCeGAKQJ6HeHnMa+h3B/ZE7+K0uKlkwJmzS8tE4Veaubb4iZ4B4G2T2rq33x1u6cYrXdgmwO/17y6rpZjCSeh58TpUThioP0y5tjIi+MTxOCplcBQ2AyA8O9SzDht1LLIF5MbLhbIpbAbSZV4N74bx0ElgNFT2eYxQ0FZG9JtgbEmljMO/lh62ilTTfG/4nVVFFTU6PGgq9fI9G8YHrijrNLHmqdDIKpS5X+FLmKi6tqDEwIvnDSinkvPDEwvr9OU/YKFHRb8X8Uts0zAnqzJjQI3+5DheCQ1e1m9zoukk3ZM/WkLHRilH5DPXG+Zjc/oFDMJEDiMouMW5OqQNVzCj3hNq+oO6IohPTVxKB/ZeDp5hTdqjiZ5vPwkiKBHHfEHpZLn/Dur3+rXBY/nz671dRd86TvhW0WTdhxRGIG3fFFdIfuOaJFNsgVRHAJ7mQaZ0V+ALmy136XUfBzqshYalCGcHD/q4lFWCW9BVEV14UBi0rUkuzeSSq0AKatdQNzvCIifbLkr4p1h+dXV6sMIgKhdTW54CkgoN2hCXg0cJ8IHyIKvvKVKPTO15Cd82bAybrCqI6dBhk2IgjnlB5WDlTuE6hPuLApRJl+cx0r7dds33cQdlSyfJV93cgIOO+UwJICWNlQ==";
      };
      gpg.format = "ssh";
      gpg.ssh.program = "/Applications/1Password.app/Contents/MacOS/op-ssh-sign";
      commit.gpgsign = false;
      tag.gpgsign = false;
      credential = {
        "https://dev.azure.com".useHttpPath = true;
      };
    };
    ignores = [
      ".DS_Store"
      ".direnv/"
      ".envrc.local"
    ];
  };

  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    enableCompletion = true;
    syntaxHighlighting.enable = true;
    oh-my-zsh = {
      enable = true;
      plugins = [ "git" ];
      theme = "robbyrussell";
    };
    shellAliases = {
      ll = "ls -lah";
      gs = "git status --short --branch";
      gcd = "git rev-parse --show-toplevel 2>/dev/null && cd $(git rev-parse --show-toplevel)";
      wmt = "wm-toggle";
    };
    initContent = ''
      # Keep secrets out of Nix. Put private exports in ~/.config/shell/secrets.zsh.
      [[ -f "$HOME/.config/shell/secrets.zsh" ]] && source "$HOME/.config/shell/secrets.zsh"

      fpath+=("${pkgs.pure-prompt}/share/zsh/site-functions")
      autoload -U promptinit; promptinit
      prompt pure

      [[ "$TERM_PROGRAM" == "kiro" ]] && command -v kiro >/dev/null && . "$(kiro --locate-shell-integration-path zsh)"

      gh_comments() {
        local no_bots=false
        local reviewer=""
        local repo=""
        local pr_number=""

        if [ "$1" = "--no-bots" ]; then
          no_bots=true
          shift
        fi

        reviewer="$1"
        repo="$2"
        pr_number="$3"

        if [ -z "$repo" ]; then
          repo=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null)
          if [ -z "$repo" ]; then
            echo "Error: could not detect repository. Usage: gh_comments [--no-bots] [reviewer] [owner/repo] [pr_number]"
            return 1
          fi
        fi

        if [ -z "$pr_number" ]; then
          pr_number=$(gh pr view --json number -q .number 2>/dev/null)
          if [ -z "$pr_number" ]; then
            echo "Error: could not detect PR number. Usage: gh_comments [--no-bots] [reviewer] [owner/repo] [pr_number]"
            return 1
          fi
        fi

        local jq_filter
        if [ "$no_bots" = true ]; then
          if [ -n "$reviewer" ]; then
            jq_filter='[ .[] | select(.user.type == "User" and .user.login == $user) | { user: .user.login, diff_hunk, line, start_line, body } ]'
          else
            jq_filter='[ .[] | select(.user.type == "User") | { user: .user.login, diff_hunk, line, start_line, body } ]'
          fi
        else
          if [ -n "$reviewer" ]; then
            jq_filter='[ .[] | select(.user.login == $user) | { user: .user.login, diff_hunk, line, start_line, body } ]'
          else
            jq_filter='[ .[] | { user: .user.login, diff_hunk, line, start_line, body } ]'
          fi
        fi

        if [ -n "$reviewer" ]; then
          gh api "repos/$repo/pulls/$pr_number/comments" --paginate | jq --arg user "$reviewer" "$jq_filter"
        else
          gh api "repos/$repo/pulls/$pr_number/comments" --paginate | jq "$jq_filter"
        fi
      }
    '';
  };

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  programs.gh.enable = true;
  programs.jq.enable = true;
  programs.zoxide.enable = true;
  programs.starship.enable = false;
}
