# vim-arsync :octopus:
vim plugin for asynchronous synchronisation of remote files and local files using rsync

## Main features
- sync up or down project folder using rsync (with compression options etc. -> -avzhe ssh )
- ignore certain files or folders based on configuration file
- asynchronous operation
- project based configuration file
- auto sync up on file save
- works with ssh-keys (recommended) or plaintext password in config file

## Installation
### Dependencies
- rsync
- *vim8* or *neovim*
- sshpass (optional: only needed when using plaintext password in config file)


### Using vim-plug
Place this in your .vimrc:

```vim
Plug 'kenn7/vim-arsync'
```

... then run the following in Vim:

```vim
:source %
:PlugInstall
```

### Using Packer

```lua
use { 'kenn7/vim-arsync' }
```

... then run the following in Vim:

```vim
:source %
:PackerSync
```

### Configuration
Create a ```.vim-arsync``` file on the root of your project that contains the following:

```
remote_host     example.com
remote_user     john
remote_port     22
remote_passwd   secret
remote_path     ~/temp/
local_path      /home/ken/temp/vuetest/
ignore_path     ["build/","test/"]
ignore_dotfiles 1
auto_sync_up    0
remote_or_local remote
sleep_before_sync 0
```

Required fields are:
- ```remote_host```     remote host to connect (must have ssh enabled)
- ```remote_path```     remote folder to be synced

Optional fields are:
- ```remote_user```     username to connect with
- ```remote_passwd```   password to connect with (requires sshpass) (not needed with SSH keys)
- ```remote_port```     remote SSH port (default: 22)
- ```local_path```      local folder to be synced (defaults to the directory containing `.vim-arsync`)
- ```ignore_path```     list of ignored files/folders e.g. `["build/","test/"]`
- ```ignore_dotfiles``` set to 1 to exclude dotfiles (e.g. `.vim-arsync` itself)
- ```auto_sync_up```    set to 1 to automatically upload on every file save
- ```remote_or_local``` set to `local` to sync between two local filesystem paths instead of over SSH
- ```sleep_before_sync``` delay in seconds before syncing — must be a positive integer (e.g. to wait for a build to finish); `0` or unset means sync immediately
- ```local_options```   overrides the default rsync flags used when `remote_or_local` is `local` (default: `-var`)
- ```remote_options```  overrides the default rsync flags used when `remote_or_local` is `remote` (default: `-vazr`; do **not** include `-e` as it is added automatically). To pass custom SSH options (e.g. identity file, ciphers), configure the host in `~/.ssh/config` instead.

**Notes:**
- Lines starting with `#` are treated as comments and ignored.
- Blank lines are ignored.
- For remote syncing, `-e 'ssh -p PORT'` is always added automatically — do not include `-e` in `remote_options`.

## Usage
If ```auto_sync_up``` is set to 1, the plugin will automatically run `:ARsyncUp` every time a
buffer is saved. The auto-sync hook is registered exactly once per project/directory, so opening
many buffers will not cause repeated or duplicated syncs.

### Commands

- ```:ARshowConf``` shows the detected configuration for the current project
- ```:ARsyncUp``` uploads local files to the remote
- ```:ARsyncUpDelete``` uploads local files to the remote and **deletes remote files** that do not exist locally (use with care)
- ```:ARsyncDown``` downloads remote files to local
- ```:ARsyncDownDelete``` downloads remote files to local and **deletes local files** that do not exist on the remote — use this to fully mirror the remote and clean the local project state

Commands can be mapped to keyboard shortcuts to enhance operations:

```vim
nnoremap <leader>su :ARsyncUp<CR>
nnoremap <leader>sd :ARsyncDown<CR>
nnoremap <leader>sD :ARsyncDownDelete<CR>
```

## TODO

- [ ] run more tests
- [ ] deactivate auto sync on error

## Acknowledgements

This plugin was inspired by [vim-hsftp](https://github.com/hesselbom/vim-hsftp) but vim-arsync offers more (rsync, ignore, async...).

This plugin ships with the [async.vim](https://github.com/prabirshrestha/async.vim) library for async operation with vim and neovim.

## Similar projects

- [coffebar/transfer.nvim](https://github.com/coffebar/transfer.nvim)
- [OscarCreator/rsync.nvim](https://github.com/OscarCreator/rsync.nvim)
