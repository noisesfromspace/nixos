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
        Pi = {
          command = helpers.mkRaw ''
            function()
              local cwd = vim.fn.getcwd()
              vim.cmd("terminal pi")
            end
          '';
          desc = "Open a terminal running pi";
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
              local function preserve_cursor_index_and_operate(operation)
                -- Get current cursor index
                local index = MiniPick.get_picker_matches().current_ind
                operation()
                -- Re-obtain items and attempt to restore the cursor position
                MiniPick.set_picker_items(_G.Maatwerk.buffers.get_items())
                local new_items = MiniPick.get_picker_matches().all
                if index and new_items and index <= #new_items then
                  -- Restore the cursor position if within bounds
                  MiniPick.set_picker_match_inds({index}, 'current')
                else
                  -- Fallback if index is out of range
                  MiniPick.set_picker_match_inds({1}, 'current')
                end
              end

              local wipeout_cur = function()
                preserve_cursor_index_and_operate(function()
                  local item = MiniPick.get_picker_matches().current
                  if item then
                    -- Force for terminal buffers
                    vim.api.nvim_buf_delete(item.bufnr, {force = true})
                  end
                end)
              end

              local buffer_mappings = {
                wipeout = { char = '<C-d>', func = wipeout_cur },
              }
              MiniPick.start({
                source = {
                  items = _G.Maatwerk.buffers.get_items(),
                  name = 'Buffers',
                  show = _G.Maatwerk.buffers.show,
                  choose = MiniPick.default_choose,
                },
                mappings = buffer_mappings,
              })
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
        # Edit quickfix like buffer
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
        _G.Maatwerk.ui = _G.Maatwerk.ui or {}
        _G.Maatwerk.buffers = _G.Maatwerk.buffers or {}

        vim.cmd.packadd('nvim.undotree')
        require('vim._core.ui2').enable()

        _G.Maatwerk.yank_file_line_range = function(use_visual)
          local file = vim.fn.expand('%:p')
          if file == "" then
            return vim.notify('Current buffer has no file path', vim.log.levels.WARN)
          end

          local result = file

          if use_visual then
            -- Check if currently in any Visual mode (v, V, or Ctrl-V)
            local in_visual = vim.fn.mode():match('^[vV\22]')
            
            -- Grab dynamic visual marks or fallback to last-used visual marks
            local l1 = vim.fn.line(in_visual and 'v' or "'<")
            local l2 = vim.fn.line(in_visual and '.' or "'>")

            if l1 > 0 and l2 > 0 then
              result = string.format('%s:%d-%d', file, math.min(l1, l2), math.max(l1, l2))
            end
          end

          vim.fn.setreg('+', result)
          vim.notify('Yanked to clipboard: ' .. result)
        end

        _G.Maatwerk.buffers.get_items = function(local_opts)
          local_opts = vim.tbl_deep_extend('force', { include_current = true, include_unlisted = false }, local_opts or {})
          local buffers_output = vim.api.nvim_exec('buffers' .. (local_opts.include_unlisted and '!' or ""), true)
          local cur_buf_id = vim.api.nvim_get_current_buf()
          local items = {}

          for _, l in ipairs(vim.split(buffers_output, '\n')) do
            local buf_str, name = l:match('^%s*(%d+)'), l:match('"(.*)"')
            local buf_id = tonumber(buf_str)
            if buf_id then
              local path = vim.api.nvim_buf_get_name(buf_id)
              local item = {
                text = name,
                bufnr = buf_id,
                path = path,
                is_current = buf_id == cur_buf_id
              }
              if buf_id ~= cur_buf_id or local_opts.include_current then
                table.insert(items, item)
              end
            end
          end
          return items
        end

        _G.Maatwerk.buffers.show = function(buf_id, items, query)
          local decorated_items = {}
          for i, item in ipairs(items) do
            local prefix = " "
            if item.is_current then prefix = ">" end

            -- Create a proxy table so default_show sees the prefixed text but we keep original metadata
            decorated_items[i] = setmetatable({ text = prefix .. item.text }, { __index = item })
          end
          return MiniPick.default_show(buf_id, decorated_items, query, { show_icons = true })
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
