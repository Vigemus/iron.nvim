# iron.nvim

Interactive Repls Over Neovim

## What is it for?

iron is a simple utility that helps you bringing repls for the current `ft`, together with some mappings that allow you to quickly interact with it.

It provides two commands:
  - `IronRepl` to start a repl based on current buffer;
  - `IronPromptRepl` to prompt you for which repl type it should open;

## Installing

As iron.nvim is a remote plugin, it requires you to `:UpdateRemotePlugins` after installing or upgrading it.

To install, simply do as follows:

```vim
  Plug 'hkupty/iron.nvim'

  "remember to update
  UpdateRemotePlugins
```

## Using

After opening a repl for current buffer, iron has defined a general mapping to send text to it: `ctr`.
`ctr` operates on text objects, so you can `ctr3j`, `ctrap`, `0ctr$`, and any other combination of commands/mappings you may need to send text to the repl.
It also have 'special' commands defined for each language. Please refer to `./rplugin/python3/iron/repls/` to see what is defined for each language.

## Status

iron is currently experimental/beta and may have bugs and/or missing functionality. *Please* report any bugs by opening issues and/or PRs.
