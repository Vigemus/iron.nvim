# iron.nvim

Interactive Repls Over Neovim

## Lua porting build status

[![CircleCI](https://circleci.com/gh/hkupty/iron.nvim.svg?style=shield&circle-token=debdaf36972c979be9ab014b325aa91da3ca0c1c)]()

### Important notice!

Python support is frozen as of ead377f and will be kept in a legacy branch after migration ends.
After this commit, python code is considered legacy and soon-to-be removed.

Migrating to lua will allow things to be easier to hack and maintain. It will solve sync/async issues and
will allow a much easier to extend and maintain system.

Feel free to open issues or pull requests if the migration path is unclear, missing something or dropping a feature you rely on.

Also, feel free to contribute with ideas.

## Support iron.nvim
Support iron.nvim development by sending me some bitcoins at `1Dnb3onNAc4XK4FL8cp7NAQ2NFspTZLNRi`.
Cheers!

## Lua roadmap

- [x] Creating REPLs with lua
- [x] Sending data to REPLs
- [x] User-defined REPL configuration
- [x] Focus on repl
- [x] Debug
- [x] Migration of python definitions to lua
- [ ] VimL counterpart (commands and functions)
- [ ] Documentation

## Dropped features

- Repl specific bindings (`IronSendSpecial`)
  - This increased the complexity of the python implementation by some extent.
  - It can depend on user configuration/installed plugins
  - [https://github.com/Vigemus/trex.nvim](trex.nvim) can provide similar feature in the future
- `IronPromptRepl`/`IronPromptCommand`
  - trex.nvim provides `TrexInvoke`, which allows ft to be passed;
    - If prompting is required, it can be chained to that command.
  - Iron might end up providing a command, but `lua require("iron").core.repl_for(<ft>)` does the trick;
  - Same thing can be accomplished for the underlying repl command, though trickier:
    ```lua
    -- create this file in your ~/.config/nvim/ as iron.lua
    -- in your init.vim, run `luafile $HOME/.config/nvim/iron.lua`

    local iron = require("iron")
    _G.create_repl = function(ft, command, tp)
      local repl_definition = {
        command = command,
        type = tp or 'bracketed'
      }
      return iron.ll.create_new_repl(ft, repl_definition)
    end

    vim.api.nvim_command([[command! -nargs=+ PromptMyRepl lua create_repl(&ft, <f-args>)]])
    ```
