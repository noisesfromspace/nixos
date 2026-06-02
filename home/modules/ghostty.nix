{
  lib,
  config,
  ...
}:
with lib;
let
  cfg = config.maatwerk.ghostty;
in
{
  options.maatwerk.ghostty = {
    enable = mkEnableOption "Terminal emulator";
  };
  config = mkIf cfg.enable {
    programs.ghostty = {
      enable = true;
      enableZshIntegration = true;
      clearDefaultKeybinds = true;
      systemd.enable = true;

      settings = {
        gtk-tabs-location = "bottom";
        gtk-toolbar-style = "flat";
        gtk-titlebar-hide-when-maximized = true;

        scrollback-limit = 250 * 1024 * 1024;
        shell-integration-features = "ssh-env";
        confirm-close-surface = "false";

        notify-on-command-finish = "unfocused";
        notify-on-command-finish-action = "notify";
        notify-on-command-finish-after = "2m";

        keybind = [
          "ctrl+shift+page_down=move_tab:1"
          "ctrl+shift+page_up=move_tab:-1"
          "ctrl+shift+c=copy_to_clipboard"
          "ctrl+shift+v=paste_from_clipboard"
          "ctrl+shift+r=prompt_surface_title"
          "ctrl+shift+f=start_search"
          "ctrl+shift+a=select_all"
          "ctrl+shift+b=scroll_to_bottom"
          "ctrl+page_down=next_tab"
          "ctrl+shift+n=next_tab"
          "ctrl+page_up=previous_tab"
          "ctrl+shift+p=previous_tab"
          "ctrl+shift+t=new_tab"
          "ctrl+shift+w=close_tab:this"
          "ctrl+shift+j=jump_to_prompt:1"
          "ctrl+shift+k=jump_to_prompt:-1"
          "ctrl+1=goto_tab:1"
          "ctrl+2=goto_tab:2"
          "ctrl+3=goto_tab:3"
          "ctrl+4=goto_tab:4"
          "ctrl+5=goto_tab:5"
          "ctrl+9=decrease_font_size:1"
          "ctrl+0=increase_font_size:1"
          "ctrl+shift+0=reset_font_size"
        ];
      };
    };
  };
}
