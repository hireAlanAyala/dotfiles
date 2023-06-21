{
  programs.helix = {
    enable = true;
    settings = {
      theme = "mytheme";
      editor = {
        line-number = "relative";
        true-color = true;
        bufferline = "multiple";
        gutters = ["diagnostics" "spacer" "line-numbers" "spacer" "diff"];

        cursor-shape = {
          insert = "bar";
          normal = "block";
          select = "underline";
        };

        lsp.display-messages = true;
        soft-wrap = {
          enable = true;
        };
      };

      # In Helix you can use minor modes to create extra
      # layers of functionality that won't clash with your other bindings
      
      keys = {
        insert = {
          j = { k = "normal_mode"; };
          # TODO: bind switching betweem buffers (might conflict with zellij)
        };
        normal = {
          C-j = ["extend_to_line_bounds" "delete_selection" "paste_after"];
          C-k = ["extend_to_line_bounds" "delete_selection" "move_line_up" "paste_before"];
        };
      };
    };
    themes = {
      mytheme = let
        background = "white";
      in {
        "inherits"= "fleet_dark";
        "ui.background" = background;
      };
    };
  };
}