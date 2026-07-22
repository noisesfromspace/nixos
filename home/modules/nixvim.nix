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

      package =
        (import ../../pkgs/neovim-ghostty.nix {
          inherit pkgs;
          inherit (pkgs)
            lib
            stdenv
            fetchFromGitHub
            callPackage
            zig_0_15
            ;
        }).neovim-unwrapped;

      globals = {
        mapleader = " ";
        maplocalleader = "\\";
      };
      opts = {
        termguicolors = true; # 24-bit color
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
        wildoptions = "pum,fuzzy,exacttext"; # Popup menu, fuzzy match, exact text in / search
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
          code = # lua
            ''
              local bufnr = function(item)
                return type(item) == 'number' and item
                  or (type(item) == 'table' and (item.bufnr or item.buf_id or item.buf))
                  or (type(item) == 'string' and tonumber(item))
              end

              local show_buffers = function(buf_id, items, query)
                local active_win = MiniPick.get_picker_state().windows.target
                local active_buf = active_win and vim.api.nvim_win_get_buf(active_win)
                local has_modified = false
                for _, item in ipairs(items) do
                  local b = bufnr(item)
                  if b and vim.api.nvim_buf_is_valid(b) and vim.bo[b].modified then has_modified = true; break end
                end
                local display_items = {}
                for _, item in ipairs(items) do
                  local b = bufnr(item)
                  local is_active, is_mod = b == active_buf, b and vim.api.nvim_buf_is_valid(b) and vim.bo[b].modified
                  local prefix = ""
                  if not has_modified then
                    prefix = is_active and "> " or "  "
                  elseif is_mod then
                    prefix = "[+] "
                  elseif is_active then
                    prefix = " >  "
                  else
                    prefix = "    "
                  end
                  if type(item) == 'table' then
                    local copy = vim.deepcopy(item)
                    copy.text = prefix .. (copy.text or copy.path or "")
                    display_items[#display_items + 1] = copy
                  else
                    display_items[#display_items + 1] = prefix .. tostring(item)
                  end
                end
                MiniPick.default_show(buf_id, display_items, query)
              end

              local wipeout_cur = function()
                local matches = MiniPick.get_picker_matches()
                local cur_pos = matches.current_ind
                local target = matches.current
                if not cur_pos or not target or not target.bufnr then return end

                MiniBufremove.wipeout(target.bufnr)

                -- Find and remove the deleted buffer by bufnr match
                local items = MiniPick.get_picker_items()
                local removed_idx = nil
                for i, item in ipairs(items) do
                  if item.bufnr == target.bufnr then
                    removed_idx = i
                    break
                  end
                end
                if not removed_idx then return end

                table.remove(items, removed_idx)

                -- Recalculate match indices, shifting indices after the removed item
                local new_all = {}
                for _, idx in ipairs(matches.all_inds) do
                  if idx < removed_idx then
                    new_all[#new_all + 1] = idx
                  elseif idx > removed_idx then
                    new_all[#new_all + 1] = idx - 1
                  end
                end

                -- Update items without re-matching (preserves search query)
                MiniPick.set_picker_items(items, { do_match = false })
                MiniPick.set_picker_match_inds(new_all, "all")
                if #new_all > 0 then
                  local new_cur = math.min(math.max(1, cur_pos), #new_all)
                  MiniPick.set_picker_match_inds({ new_all[new_cur] }, "current")
                end
              end
              local buffer_mappings = { wipeout = { char = '<C-d>', func = wipeout_cur } }
              MiniPick.builtin.buffers(nil, { mappings = buffer_mappings, source = { show = show_buffers } })
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
            notify.enable = true; # vim.notify capture
            surround.enable = true; # surround words with something

            bufremove = {
              enable = true;
              silent = true;
            };

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
              vim.opt_local.textwidth = 120
              -- notes use 2-space list nesting; core ftplugin forces 4
              vim.opt_local.shiftwidth = 2
              vim.opt_local.tabstop = 2
              vim.opt_local.softtabstop = 2
              vim.b.md_list_fold = function()
                local line = vim.fn.getline(vim.v.lnum)
                local indent = #line:match("^(%s*)")
                if line:match("^%s*[-*+]%s") then
                  return ">" .. (indent + 1)
                end
                return "="
              end
              vim.wo.foldexpr = "v:lua.vim.b.md_list_fold()"
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

      extraPlugins = [
        (pkgs.vimUtils.buildVimPlugin {
          name = "touchup";
          src = pkgs.fetchFromRadicle {
            seed = "seed.boers.email";
            repo = "z3idaVuBJSG4LUD3zbP2PoXfry3xX";
            rev = "951f0335136ae44a16d079d7347d874baeab38be";
            hash = "sha256-RlP0iBzHwv2XUGARjFGaB4QysXO13s428vemEz2UYTQ=";
          };
        })
      ];

      extraConfigLua = ''
        _G.Maatwerk = _G.Maatwerk or {}
        vim.cmd.packadd('nvim.undotree'); 
        vim.cmd.packadd('nvim.tohtml'); 
        require('vim._core.ui2').enable()
        require('touchup').setup()


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
