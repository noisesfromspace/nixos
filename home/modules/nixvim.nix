{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
let
  cfg = config.maatwerk.nixvim;
  helpers = config.lib.nixvim;

  keymaps =
    let
      mk = args: {
        key = args.key;
        action = args.action;
        mode = args.modes;
        options = {
          inherit (args) desc;
          silent = true;
        };
      };
    in
    {
      inherit mk;
      cmd =
        args:
        mk (
          {
            modes = [
              "n"
              "v"
            ];
          }
          // args
          // {
            action = "<cmd>${args.command}<cr>";
          }
        );

      lua =
        args:
        mk (
          {
            modes = [
              "n"
              "v"
            ];
          }
          // args
          // {
            action = helpers.mkRaw "function() ${args.code} end";
          }
        );
    };
in
{

  options.maatwerk.nixvim = {
    enable = mkEnableOption "Full nixvim install";
  };

  imports = [
    ./dap.nix
    ./lsp.nix
    ./snip.nix
  ];

  config = mkIf cfg.enable {
    programs.nixvim = {
      enable = true;

      globals = {
        mapleader = " ";
        maplocalleader = "\\";
      };
      opts = {
        number = true; # Show line numbers
        relativenumber = true; # Show relative line numbers
        ignorecase = true; # Ignore case in search patterns
        smartcase = true; # Override ignorecase if search contains capitals
        swapfile = false; # Don't create cluttering .swp files
        undofile = true; # Save undo history
        sessionoptions = "blank,buffers,curdir,folds,help,tabpages,winsize,winpos,terminal,globals";
        nrformats = "unsigned"; # Ctrl+a always treated as positive number

        # Indentation
        expandtab = true; # Use spaces instead of tabs
        shiftwidth = 2; # Size of an indent
        tabstop = 2; # Number of spaces tabs count for
        softtabstop = 2; # Number of spaces a <Tab> inserts in insert mode
        scrolloff = 2; # always have 2 lines margin

        # Spelling
        spell = false;
        spelllang = "nl,en_gb";
        spellsuggest = "best,9";

        # Folding
        foldenable = true;
        foldlevel = 20;
        foldmethod = "expr";
        foldexpr = "v:lua.vim.lsp.foldexpr()";

        # Completion
        wildoptions = "pum"; # Popup menu for wildmenu
        wildmode = "longest:full,full"; # Complete longest common string, then each full match
        winborder = "single";
        completeopt = "menu,menuone,noinsert"; # Show menu, autoselect first, don't auto-insert
        complete = ".,w"; # Current buffer and windows
        infercase = true; # Infer case for completion
        pumheight = 15; # Max items in completion menu
        pumwidth = 30; # Minimum width of completion menu
      };

      userCommands = {
        Scratch = {
          command = helpers.mkRaw ''
            function()
              vim.cmd("enew")
              vim.bo.buftype = "nofile"
              vim.bo.bufhidden = "hide"
              vim.bo.swapfile = false
            end
          '';
          desc = "Create a new scratch buffer";
        };
        Pi = {
          command = helpers.mkRaw ''
            function()
              local cwd = vim.fn.getcwd()
              vim.cmd("terminal pi")
            end
          '';
          desc = "Open a terminal running pi";
        };
        Binary = {
          command = helpers.mkRaw ''
            function()
              if vim.bo.binary then
                vim.cmd("%!xxd -r")
                vim.bo.binary = false
                vim.notify("Binary mode off")
              else
                vim.bo.binary = true
                vim.cmd("%!xxd")
                vim.notify("Binary mode on — edit hex, then :Binary to convert back")
              end
            end
          '';
          desc = "Toggle binary file editing via xxd hex dump";
        };
      };

      keymaps = with keymaps; [
        # Picker / Fuzzy Finding
        (lua {
          key = "<Leader>f";
          desc = "Find";
          code = "MiniPick.builtin.grep_live()";
          modes = [
            "n"
            "v"
          ];
        })
        (lua {
          key = "<Leader>l";
          desc = "Last picker";
          code = "MiniPick.builtin.resume()";
          modes = [
            "n"
            "v"
          ];
        })
        (lua {
          key = "<Leader>o";
          desc = "Files";
          code = "MiniPick.builtin.files()";
        })
        (lua {
          key = "<BS>";
          desc = "Overview of buffers";
          code = "MiniPick.builtin.buffers()";
        })
        (lua {
          key = "<Leader>h";
          desc = "Find help pages";
          code = "MiniPick.builtin.help()";
        })
        (lua {
          key = "<Leader>x";
          desc = "Find errors";
          code = "MiniExtra.pickers.diagnostic()";
          modes = [
            "n"
            "v"
          ];
        })
        (lua {
          key = "<Leader>s";
          desc = "Find symbols";
          code = "MiniExtra.pickers.lsp({scope = 'document_symbol'})";
        })
        (lua {
          key = "<Leader>r";
          desc = "Show registers";
          code = "MiniExtra.pickers.registers()";
        })

        # Terminal rebinds
        {
          mode = "t";
          key = "<esc>";
          # :tnoremap <Esc> <C-\><C-N>
          action = "<C-\\><C-n>";
          options = {
            silent = true;
            desc = "Exit terminal mode";
          };
        }
        {
          mode = "t";
          key = "<C-esc>";
          # :tnoremap <S-Esc> <Esc>
          action = "<Esc>";
          options = {
            silent = true;
            desc = "Sent real Esc";
          };
        }

        # File Explorer
        (lua {
          key = "<Leader>e";
          desc = "Toggle MiniFiles";
          code = "MiniFiles.open()";
          modes = [
            "n"
            "v"
          ];
        })
        (lua {
          key = "-";
          desc = "Toggle MiniFiles";
          code = "MiniFiles.open(vim.api.nvim_buf_get_name(0))";
          modes = [
            "n"
            "v"
          ];
        })

        # Git actions
        (cmd {
          key = "<leader>u";
          desc = "Undotree";
          command = "Undotree";
          modes = [
            "n"
            "v"
          ];
        })
        (cmd {
          key = "gb";
          desc = "Git blame";
          command = "Git log --patch --max-count=40 -- %";
        })
        (lua {
          key = "gb";
          desc = "Git blame";
          code = "MiniGit.show_at_cursor()";
          modes = [ "v" ];
        })
        (cmd {
          key = "gl";
          desc = "Commit log";
          command = "Git log --patch --max-count=25";
          modes = [ "n" ];
        })
        (lua {
          key = "g\\";
          desc = "Show buffer changes";
          code = "MiniDiff.toggle_overlay()";
        })
        (cmd {
          key = "gs";
          desc = "Open neogit status";
          command = "Neogit kind=split";
        })
        (lua {
          key = "gL";
          desc = "All branches log";
          code = "require('neogit').action('log', 'log_all_branches', { '--graph', '--decorate', '--show-signature' })()";
          modes = [ "n" ];
        })

        # Clipboard
        (lua {
          key = "gy";
          desc = "Yank file:full-range";
          code = "_G.Maatwerk.yank_file_line_range(false)";
          modes = [ "n" ];
        })
        (lua {
          key = "gy";
          desc = "Yank file:selected-range";
          code = "_G.Maatwerk.yank_file_line_range(true)";
          modes = [ "v" ];
        })

        # Tab management
        (cmd {
          key = "<C-t>n";
          desc = "New tab";
          command = "tabnew";
          modes = [ "n" ];
        })
        (cmd {
          key = "<C-t>q";
          desc = "Close tab";
          command = "tabclose";
          modes = [ "n" ];
        })
        (cmd {
          key = "<C-t>o";
          desc = "Only this tab";
          command = "tabonly";
          modes = [ "n" ];
        })

        # Window resizing with bigger steps
        (cmd {
          key = "<C-w>+";
          desc = "Increase window height";
          command = "resize +5";
          modes = [ "n" ];
        })
        (cmd {
          key = "<C-w>-";
          desc = "Decrease window height";
          command = "resize -5";
          modes = [ "n" ];
        })
        (cmd {
          key = "<C-w>>";
          desc = "Increase window width";
          command = "vertical resize +10";
          modes = [ "n" ];
        })
        (cmd {
          key = "<C-w><";
          desc = "Decrease window width";
          command = "vertical resize -10";
          modes = [ "n" ];
        })
      ];

      diagnostic.settings = {
        virtual_text = false;
        signs = false;
        virtual_lines = {
          enable = true;
          current_line = true;
        };
      };

      highlight = {
        YankHighlight = {
          bg = config.lib.stylix.colors.withHashtag.yellow;
          fg = config.lib.stylix.colors.withHashtag.base00;
        };
      };

      highlightOverride = {
        LineNr = {
          fg = config.lib.stylix.colors.withHashtag.yellow;
        };
        LineNrAbove = {
          fg = config.lib.stylix.colors.withHashtag.base03;
        };
        LineNrBelow = {
          fg = config.lib.stylix.colors.withHashtag.base03;
        };
        Comment = {
          # subtle comments
          fg = config.lib.stylix.colors.withHashtag.base04;
          italic = true;
        };
      };

      plugins = {
        quicker.enable = true;
        image.enable = true;

        neogit = {
          enable = true;
          settings = {
            disable_commit_confirmation = true;
            disable_hint = true;
            graph_style = "kitty";
            integrations = {
              mini_pick = true;
              diffview = false;
            };
            mappings = {
              status = {
                "?" = false;
              };
              popup = {
                "?" = false;
                "g?" = "HelpPopup";
              };
            };
          };
        };

        mini = {
          enable = true;
          mockDevIcons = true;
          modules = {
            extra.enable = true; # more picker sources
            icons.enable = true; # icons support for extensions
            git.enable = true; # git log/blame file
            diff.enable = true; # gitsigns replacement
            completion.enable = true; # autocomplete
            notify.enable = true; # vim.notify capture
            surround.enable = true; # surround words with something

            files = {
              enable = true; # file explorer
              options.lsp_timeout = 0;
            };

            pick = {
              enable = true;
              options = {
                use_cache = true;
              };
              source = {
                preview = helpers.mkRaw ''
                  function(buf_id, item, opts)
                    opts = opts or {}
                    opts.line_position = "center"
                    return MiniPick.default_preview(buf_id, item, opts)
                  end
                '';
              };
            };

            move = {
              mappings = {
                up = "<C-S-Up>";
                down = "<C-S-Down>";
                line_up = "<C-S-Up>";
                line_down = "<C-S-Down>";
              };
            };
          };
        };
      };

      autoCmd = [
        {
          event = [
            "TermOpen"
            "BufEnter"
          ];
          callback = helpers.mkRaw ''
            function()
              if vim.bo.buftype == "terminal" then
                vim.opt_local.number = true
                vim.opt_local.relativenumber = true
                vim.opt_local.scrollback = 100000
              end
            end
          '';
        }
        {
          event = [ "FileType" ];
          pattern = [
            "markdown"
            "latex"
            "text"
          ];
          callback = helpers.mkRaw ''
            function()
              vim.opt_local.linebreak = true
              vim.opt_local.textwidth = 80
            end
          '';
        }
        {
          event = "User";
          pattern = [ "MiniFilesBufferCreate" ];
          callback = helpers.mkRaw ''
            function(args)
              local buf_id = args.data.buf_id

              -- Set focused directory as current working directory
              local set_cwd = function()
                local path = (MiniFiles.get_fs_entry() or {}).path
                if path == nil then return vim.notify('Cursor is not on valid entry') end
                local dir = vim.fs.dirname(path)
                vim.fn.chdir(dir)
                vim.notify('Changed cwd to ' .. dir)
              end

              vim.keymap.set('n', '~', set_cwd, { buffer = buf_id, desc = 'Set cwd' })
            end
          '';
        }
        {
          event = "TextYankPost";
          callback = helpers.mkRaw ''
            function()
              vim.highlight.on_yank({ higroup = "YankHighlight", timeout = 150 })
            end
          '';
        }
        {
          event = [ "VimLeavePre" ];
          callback = helpers.mkRaw ''
            function()
              if vim.v.this_session ~= "" then
                vim.cmd("mksession! " .. vim.fn.fnameescape(vim.v.this_session))
              end
            end
          '';
        }
      ];

      extraConfigLua = ''
        _G.Maatwerk = _G.Maatwerk or {}
        vim.cmd.packadd('nvim.undotree'); 
        require('vim._core.ui2').enable()

        _G.Maatwerk.yank_file_line_range = function(use_visual)
          local file = vim.fn.expand('%:p')
          if file == ''' then return vim.notify('No file path', vim.log.levels.WARN) end
          local result = file
          if use_visual then
            local mode = vim.fn.mode():match('[vV\22]')
            local start_line = vim.fn.line(mode and 'v' or "'<")
            local end_line = vim.fn.line(mode and '.' or "'>")
            if start_line > 0 then
              result = file .. ':' .. math.min(start_line, end_line) .. '-' .. math.max(start_line, end_line)
            end
          end
          vim.fn.setreg('+', result); vim.fn.setreg('"', result); vim.notify('Yanked: ' .. result)
          if use_visual then vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<Esc>', true, false, true), 'n', true) end
        end
      '';

      clipboard = {
        providers.wl-copy.enable = true;
      };

    };
  };
}
