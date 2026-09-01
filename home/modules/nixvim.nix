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

  config = mkIf cfg.enable {
    programs.nixvim = {
      enable = true;

      package =
        (import ../../pkgs/neovim-ghostty.nix {
          inherit pkgs;
          inherit (pkgs)
            lib
            stdenv
            fetchFromGitHub
            callPackage
            zig_0_16
            ;
        }).neovim-unwrapped;

      globals = {
        mapleader = " ";
        maplocalleader = "\\";

        # netrw
        netrw_liststyle = 3; # tree view
        netrw_banner = 0; # hide the top banner
        netrw_winsize = 25; # fix the left split width
        netrw_browse_split = 0; # open files in the previous window
        netrw_altfile = 1; # keep the alternate file correct
      };
      opts = {
        termguicolors = true; # 24-bit color
        number = true; # Show line numbers
        relativenumber = true; # Show relative line numbers
        ignorecase = true; # Ignore case in search patterns
        smartcase = true; # Override ignorecase if search contains capitals
        swapfile = false; # Don't create cluttering .swp files
        undofile = true; # Save undo history
        nrformats = "unsigned"; # Ctrl+a always treated as positive number
        splitright = true;

        # Indentation
        expandtab = true; # Use spaces instead of tabs
        shiftwidth = 2; # Size of an indent
        tabstop = 2; # Number of spaces tabs count for
        softtabstop = 2; # Number of spaces a <Tab> inserts in insert mode
        scrolloff = 2; # always have 2 lines margin
        updatetime = 30; # CursorHold fires after x-ms

        # Spelling
        spell = false;
        spelllang = "nl,en_gb";
        spellsuggest = "best,9";

        # Folding
        foldenable = true;
        foldlevel = 20;
        foldmethod = "expr";
        foldexpr = "v:lua.vim.lsp.foldexpr()";

        # Cmdline completion (:e, :find, /search)
        wildoptions = "pum,exacttext"; # Popup menu
        wildmode = "longest:full,full"; # <Tab>: first inserts longest prefix+menu, then cycles full matches
        wildignorecase = true; # Ignore case in cmdline file completion

        # Insert-mode completion
        completeopt = "menu,noinsert,menuone,popup,fuzzy";
        # menu     = show popup menu
        # noinsert = don't auto-insert first match; always <C-y> to accept
        # menuone  = show popup even if only 1 match
        # popup    = floating doc window for selected item
        # fuzzy    = type to filter by skipping chars (no need for exact prefix)
        complete = ".,w"; # <C-n>/<C-p> sources: . = buffer, w = other windows
        infercase = true; # Match case of typed prefix when inserting completion
        pumwidth = 20; # Minimum popup menu width
        pummaxwidth = 65; # Maximum popup menu width (truncated text shows fillchars.trunc "…")
        pumheight = 15; # Max items in popup menu
        pumborder = "single"; # Border around popup menu
        fillchars = {
          trunc = "…"; # Shown when menu text is truncated
        };
        winborder = "single";
      };

      userCommands = {
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
        })
        (lua {
          key = "<Leader>l";
          desc = "Last picker";
          code = "MiniPick.builtin.resume()";
        })
        (lua {
          key = "<Leader>o";
          desc = "Files";
          code = "MiniPick.builtin.files()";
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

        # Notes
        (lua {
          key = "<C-j>";
          desc = "Insert note frontmatter (snippet)";
          modes = [ "i" ];
          code = ''
            local date = os.date("%Y-%m-%d")
            local snip = "---\n"
              .. "title: ''${1}\n"
              .. "tags: ''${2}\n"
              .. "date: ''${3:" .. date .. "}\n"
              .. "---\n"
              .. "''${0}"
            vim.snippet.expand(snip)
          '';
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
          key = "<M-Esc>";
          # :tnoremap <M-Esc> <Esc>
          action = "<Esc>";
          options = {
            silent = true;
            desc = "Sent real Esc";
          };
        }

        # Fruit.nvim
        (lua {
          key = "<leader>p";
          desc = "PI sessions";
          code = "require('fruit').Sessions()";
        })

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
        (lua {
          key = "g\\";
          desc = "Show buffer changes";
          code = "MiniDiff.toggle_overlay()";
        })
        (cmd {
          key = "gs";
          desc = "Open neogit status";
          command = "Neogit";
        })
        (lua {
          key = "gl";
          desc = "Git log";
          code = "require('neogit').action('log', 'log_all_branches', { '--graph', '--decorate', '--show-signature' })()";
          modes = [ "n" ];
        })
        (cmd {
          key = "gb";
          desc = "File history (current file)";
          command = "NeogitLogCurrent";
          modes = [ "n" ];
        })
        (mk {
          key = "gb";
          desc = "File history (selection)";
          action = ":NeogitLogCurrent<cr>";
          modes = [ "v" ];
        })
        (lua {
          key = "g/";
          desc = "Search commits for string";
          modes = [ "n" ];
          code = ''
            vim.ui.input({ prompt = "Search commits for: " }, function(query)
              if query and query ~= "" then
                require("neogit").action("log", "log_current", { "-S" .. query, "--all" })()
              end
            end)
          '';
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
        YankHighlight.link = "IncSearch";
      };

      highlightOverride = {
        LineNr.link = "WarningMsg";
        LineNrAbove.link = "NonText";
        LineNrBelow.link = "NonText";
        Comment = {
          italic = true;
        };
      };

      plugins = {
        neogit = {
          enable = true;
          package = (
            pkgs.vimUtils.buildVimPlugin {
              pname = "neogit";
              version = "3.0.0-unstable-2026-07-27";
              doCheck = false;
              src = pkgs.fetchFromGitHub {
                owner = "noisesfromspace";
                repo = "neogit";
                rev = "69045935e7473da514889f9e397754ea962d5421";
                hash = "sha256-DHKzSqvT1O/B+3OSa3/2wzUJIu6bkahAo7v3Lw27HsA=";
              };
            }
          );

          settings = {
            disable_commit_confirmation = true;
            disable_hint = true;
            prompt_amend_commit = false;
            graph_style = "kitty";
            integrations = {
              mini_pick = true;
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
            diff.enable = true; # gitsigns replacement

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
                vim.opt_local.scrolloff = 0
                vim.opt_local.sidescrolloff = 0
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
              -- notes use 2-space list nesting; core ftplugin forces 4
              vim.opt_local.shiftwidth = 2
              vim.opt_local.tabstop = 2
              vim.opt_local.softtabstop = 2
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
              vim.hl.hl_op({ higroup = "YankHighlight", timeout = 150 })
            end
          '';
        }
      ];

      extraPlugins = [
        (pkgs.vimUtils.buildVimPlugin {
          pname = "touchup";
          version = "0.1";
          src = pkgs.fetchFromGitHub {
            owner = "noisesfromspace";
            repo = "touchup.nvim";
            rev = "efc7df43515aeb29c84ef088f0197bde83e9ce12";
            hash = "sha256-T9x6zLsPmpZn8yTwzN4+TXgWb2RuZP2OIX8UNV8W0sU=";
          };
        })
        (pkgs.vimUtils.buildVimPlugin {
          pname = "fruit";
          version = "0.1";
          # src = pkgs.fetchFromRadicle {
          #   seed = "seed.boers.email";
          #   repo = "zfLRpRmAn1WGArvCFTjnrwMn1ZKr";
          #   rev = "70a52eb349572292a99d522fc9a8c235e357d78f";
          #   hash = "sha256-IV/5OyZxMKah+ANpvr87o0N6ydx39X5FN2qm8P3adVE=";
          # };
          src = /opt/code/fruit.nvim;
        })
      ];

      extraConfigLua = ''
        _G.Maatwerk = _G.Maatwerk or {}
        require('vim._core.ui2').enable()
        require('touchup').setup()
        require('fruit').setup()

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
          vim.fn.setreg('+', result); vim.fn.setreg('"', result);
          if use_visual then vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<Esc>', true, false, true), 'n', true) end
        end
      '';

      clipboard = {
        providers.wl-copy.enable = true;
      };

    };
  };
}
