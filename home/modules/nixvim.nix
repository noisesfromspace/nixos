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
      };
      opts = {
        number = true; # Show line numbers
        relativenumber = true; # Show relative line numbers
        ignorecase = true; # Ignore case in search patterns
        smartcase = true; # Override ignorecase if search contains capitals
        swapfile = false; # Don't create cluttering .swp files
        undofile = true; # Save undo history
        cmdheight = 0; # Hide command line
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
              vim.api.nvim_buf_set_name(0, "[scratch]")
            end
          '';
          desc = "Create a new scratch buffer";
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
          code = # lua
            ''
              local wipeout_cur = function()
                vim.api.nvim_buf_delete(MiniPick.get_picker_matches().current.bufnr, {})
              end
              local buffer_mappings = { wipeout = { char = '<C-d>', func = wipeout_cur } }
              MiniPick.builtin.buffers(local_opts, { mappings = buffer_mappings })
            '';
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

        # Quality of life
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
          key = "<Leader>E";
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
          command = "Git log --patch --max-count=50 -- %";
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
          command = "Git log --patch --max-count=50";
          modes = [ "n" ];
        })
        (cmd {
          key = "go";
          desc = "Open file in source control";
          command = "GitPortal";
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

        # Clipboard
        (mk {
          key = "<Leader>y";
          desc = "Add to sytem clipboard";
          action = ''"+y'';
          modes = [ "v" ];
        })
        (cmd {
          key = "<Leader>y";
          desc = "Add whole file to sytem clipboard";
          command = "%y+";
          modes = [ "n" ];
        })

        # Terminal
        (cmd {
          key = "<C-w>t";
          desc = "Terminal split";
          command = "split | terminal";
          modes = [ "n" ];
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
        StatuslineErrorIcon = {
          fg = config.lib.stylix.colors.withHashtag.red;
        };
        StatuslineNormalIcon = {
          fg = config.lib.stylix.colors.withHashtag.green;
        };
        YankHighlight = {
          bg = config.lib.stylix.colors.withHashtag.yellow;
          fg = config.lib.stylix.colors.withHashtag.base00;
        };
      };

      highlightOverride = {
        StatusLineNC = {
          bg = config.lib.stylix.colors.withHashtag.base00;
        };
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

        gitportal = {
          enable = true; # open gh or gitlab web
          package = pkgs.vimPlugins.gitportal-nvim.overrideAttrs {
            src = pkgs.fetchFromCodeberg {
              owner = "martijnboers";
              repo = "gitportal.nvim";
              rev = "154c4b9633aebb9a0c588f0870a1a6107f870b78";
              hash = "sha256-rmHKGNea1JNjkEwfkHShAgUWnuiqFbFZ4DjkiqYcYWA=";
            };
          };
          settings.always_use_commit_hash_in_url = true;
        };

        mini = {
          enable = true;
          mockDevIcons = true;
          modules = {
            files.enable = true; # file explorer
            extra.enable = true; # more picker sources
            icons.enable = true; # icons support for extensions
            git.enable = true; # git log/blame file
            diff.enable = true; # gitsigns replacement
            completion.enable = true; # autocomplete
            notify.enable = true; # vim.notify capture
            surround.enable = true; # surround words with something

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

            statusline = {
              use_icons = true;
              content = {
                active = helpers.mkRaw ''
                  function()
                    local mode, mode_hl = MiniStatusline.section_mode({ trunc_width = 200 })
                    local full_filename = vim.fn.pathshorten(vim.fn.expand('%:~:.'))
                    if full_filename == "" then full_filename = "[No Name]" end

                    local n_errors = #vim.diagnostic.get(0, { severity = vim.diagnostic.severity.ERROR })
                    local n_warns  = #vim.diagnostic.get(0, { severity = vim.diagnostic.severity.WARN })
                    local s_rec = vim.fn.reg_recording() ~= "" and ( vim.fn.reg_recording()) .. "  " or ""

                    local n_unwritten = 0
                    local n_unnamed_unwritten = 0
                    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
                      if vim.bo[buf].modified and vim.bo[buf].buflisted and vim.bo[buf].buftype ~= "nofile" then 
                        if vim.api.nvim_buf_get_name(buf) == "" then
                          n_unnamed_unwritten = n_unnamed_unwritten + 1
                        else
                          n_unwritten = n_unwritten + 1 
                        end
                      end
                    end

                    local root = _G.Maatwerk.git.get_git_root(0)
                    local dirty = root and (vim.g.git_dirty or {})[root]
                    
                    local s_git = ""
                    if n_unwritten > 0 then
                      s_git = "●"
                    elseif n_unnamed_unwritten > 0 then
                      s_git = "○"
                    elseif dirty then
                      s_git = "◌"
                    end
                    
                    local total_lines = vim.fn.line('$')
                    local percentage = total_lines > 0 and math.floor((vim.fn.line('.') / total_lines) * 100) or 0

                    local location_str = full_filename

                    local groups = {
                        { hl = mode_hl,                  strings = { mode } },
                        { hl = 'MiniStatuslineDevinfo',  strings = { percentage .. '%%' } },
                        { hl = 'MiniStatuslineLocation', strings = { location_str } },
                        '%=', '%<',
                        { hl = 'MiniStatuslineDevinfo',  strings = { s_rec } },
                    }
                    
                    if s_git ~= "" then table.insert(groups, { hl = 'MiniStatuslineDevinfo', strings = { s_git } }) end
                    
                    local icon_hl = (n_errors > 0) and 'StatuslineErrorIcon' or 'StatuslineNormalIcon'
                    local icon_str = (n_errors > 0) and ("󰈸 " .. n_errors) or " "
                    table.insert(groups, { hl = icon_hl, strings = { icon_str } })

                    return MiniStatusline.combine_groups(groups)
                  end
                '';
              };
            };
          };
        };
      };

      autoCmd = [
        {
          event = "User";
          pattern = [
            "NeogitStatusRefreshed"
            "NeogitCommitComplete"
            "NeogitPushComplete"
            "NeogitPullComplete"
          ];
          callback = helpers.mkRaw "_G.Maatwerk.git.update_status";
        }
        {
          event = [
            "BufWritePost"
            "BufEnter"
            "FocusGained"
          ];
          callback = helpers.mkRaw "_G.Maatwerk.git.update_status";
        }
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
              vim.opt_local.spell = true
              vim.opt_local.linebreak = true
              vim.opt_local.textwidth = 80
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
          event = "CursorMoved";
          callback = helpers.mkRaw "_G.Maatwerk.ui.update_search_count";
        }
        {
          event = "CmdlineLeave";
          callback = helpers.mkRaw "_G.Maatwerk.ui.clear_search_count";
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
        _G.Maatwerk.git = _G.Maatwerk.git or {}
        _G.Maatwerk.ui = _G.Maatwerk.ui or {}

        vim.cmd.packadd('nvim.undotree')

        local neogit = require('neogit')
        vim.keymap.set(
          'n',
          'gL',
          neogit.action('log', 'log_all_branches', { '--graph', '--decorate', '--show-signature' })
        )

        _G.Maatwerk.git.get_git_root = function(bufnr)
          if bufnr == 0 then bufnr = vim.api.nvim_get_current_buf() end
          local name = vim.api.nvim_buf_get_name(bufnr)
          if name == "" then return nil end
          return vim.fs.root(name, ".git")
        end

        local checking = {}

        _G.Maatwerk.git.update_status = function()
          local root = _G.Maatwerk.git.get_git_root(0)
          if not root then return end
          if checking[root] then return end

          checking[root] = true
          vim.system(
            { "git", "status", "--porcelain" },
            { text = true, cwd = root },
            function(obj)
              checking[root] = nil
              local dirty = obj.code == 0 and obj.stdout and obj.stdout ~= ""
              vim.schedule(function()
                local d = vim.g.git_dirty or {}
                d[root] = dirty
                vim.g.git_dirty = d
                vim.cmd("redrawstatus")
              end)
            end
          )
        end

        _G.Maatwerk.ui.update_search_count = function()
          if vim.v.hlsearch == 0 then return end
          local bufnr = vim.api.nvim_get_current_buf()
          local ns = vim.api.nvim_create_namespace('searchcount')
          vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)

          local pattern = vim.fn.getreg('/')
          local cursor = vim.api.nvim_win_get_cursor(0)
          local cursor_line, cursor_col = cursor[1], cursor[2] + 1

          local match_line, match_col = unpack(vim.fn.searchpos(pattern, 'bcn'))
          if match_line == 0 then return end
          if cursor_line ~= match_line then return end

          local saved_pos = vim.api.nvim_win_get_cursor(0)
          vim.api.nvim_win_set_cursor(0, {match_line, match_col - 1})
          local count = vim.fn.searchcount({maxcount = 1000, timeout = 100})
          vim.api.nvim_win_set_cursor(0, saved_pos)

          if count.current > 0 and count.total > 0 then
            local text = string.format(" -- [%d/%d]", count.current, count.total)
            vim.api.nvim_buf_set_extmark(bufnr, ns, match_line - 1, match_col - 1, {
              virt_text = {{text, "Question"}},
              virt_text_pos = "eol",
              priority = 100,
            })
          end
        end

        _G.Maatwerk.ui.clear_search_count = function()
          local cmd = vim.fn.getcmdline()
          if cmd == "noh" or cmd == "nohlsearch" then
            local ns = vim.api.nvim_create_namespace('searchcount')
            vim.api.nvim_buf_clear_namespace(0, ns, 0, -1)
          end
        end
      '';

      clipboard = {
        providers.wl-copy.enable = true;
      };

    };
  };
}
