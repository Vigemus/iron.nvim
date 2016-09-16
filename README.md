# iron.nvim

Interactive Repls Over Neovim

## What is it for?

Iron is a simple utility that helps you bringing repls for the current `ft`,
together with some mappings that allow you to quickly interact with it.

It provides commands below:
  - `IronRepl` to start a repl based on current buffer;
  - `IronPromptRepl` to prompt you for which repl type it should open;
  - `IronPromptCommand` to prompt for which command to run for current ft (if no definition for current ft, prompts for ft);
  - `IronDumpReplDefinition` to dump on the logfile the current definition for repls. Useful for debugging.
  - `IronClearReplDefinition` resets data to original state. If something gets messy, this should restore the behavior.

It also provides the following functions:
  - `IronSendSpecial` allows calling python functions for the current ft. See more below.
  - `IronSendMotion` gets a chunk of text from current buffer based on the motion sent. Used by `ctr`.
  - `IronSend` is a general function for sending text to the repl.

## Language special mappings

Iron allows that you add some commonly used tasks as special mappings for each
language. Currently, only clojure has several of those implemented. Those
mappings allow you the get chunks of text from the currenty buffer and issue
commands specifically for the current ft, such as calling a test for that
file/namespace, importing a dependency, toggling debugging state or whatever
makes sense for the language/repl.

If you think you are repeating yourself too
much, feel free to open a PR implementing one of those.

## Installing

As iron.nvim is a remote plugin, it requires you to `:UpdateRemotePlugins` after installing or upgrading it.

To install, simply do as follows:

```vim
  Plug 'hkupty/iron.nvim'

  "remember to update
  UpdateRemotePlugins
```

## Using

After opening a repl for current buffer, iron has defined a general mapping to
send text to it: `ctr`.

`ctr` operates on text objects, so you can `ctr3j`, `ctrap`, `0ctr$`, and any
other combination of commands/mappings you may need to send text to the repl.

It also have 'special' commands defined for each language. Please refer to
`./rplugin/python3/iron/repls/` to see what is defined for each language.

Iron also can have special, language/repl based mappings as defined per-repl.
Refer to Language Special Mappings above for more information.

## Status

Although iron is currently experimental/beta and may have bugs and/or missing
functionality, it has already a nice range of languages implemented and quite a
nice support for clojure already. Other languages may be lacking support, but
reportedly work ok.

Feel free to fork and extend iron. It is completely open source and community
driven.

*Please* report any bugs by opening issues and/or PRs.
