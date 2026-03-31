" Vim plugin to handle async rsync synchronisation between hosts
" Title: vim-arsync
" Author: Ken Hasselmann
" Date: 08/2019
" License: MIT

if exists('g:loaded_vim_arsync')
    finish
endif
let g:loaded_vim_arsync = 1

function! ShouldSync()
    return !empty(findfile('.vim-arsync', '.;'))
endfunction

function! LoadConf()
    let l:conf_dict = {}
    let l:config_file = findfile('.vim-arsync', '.;')

    if strlen(l:config_file) > 0
        let l:conf_options = readfile(l:config_file)
        for i in l:conf_options
            " Skip blank lines and lines starting with #
            let l:trimmed = substitute(i, '^\s*\(.\{-}\)\s*$', '\1', '')
            if empty(l:trimmed) || l:trimmed[0] ==# '#'
                continue
            endif
            let l:sep = stridx(l:trimmed, ' ')
            " l:sep == -1: no separator; l:sep == 0: empty key — both invalid
            if l:sep <= 0
                continue
            endif
            let l:var_name = l:trimmed[0:l:sep-1]
            let l:raw_value = substitute(l:trimmed[l:sep+1:], '^\s*\(.\{-}\)\s*$', '\1', '')
            if l:var_name ==# 'ignore_path' || l:var_name ==# 'include_path'
                let l:var_value = eval(l:raw_value)
            else
                let l:var_value = escape(l:raw_value, '%#!')
            endif
            let l:conf_dict[l:var_name] = l:var_value
        endfor
    endif
    if !has_key(l:conf_dict, 'local_path')
        let l:conf_dict['local_path'] = fnamemodify(l:config_file, ':p:h')
    endif
    if !has_key(l:conf_dict, 'remote_port')
        let l:conf_dict['remote_port'] = 22
    endif
    if !has_key(l:conf_dict, 'remote_or_local')
        let l:conf_dict['remote_or_local'] = 'remote'
    endif
    if !has_key(l:conf_dict, 'local_options')
        let l:conf_dict['local_options'] = '-var'
    endif
    if !has_key(l:conf_dict, 'remote_options')
        let l:conf_dict['remote_options'] = '-vazr'
    endif
    return l:conf_dict
endfunction

function! JobHandler(job_id, data, event_type)
    if a:event_type ==# 'stdout' || a:event_type ==# 'stderr'
        if has_key(getqflist({'id' : g:arsync_qfid}), 'id')
            call setqflist([], 'a', {'id' : g:arsync_qfid, 'lines' : a:data})
        endif
    elseif a:event_type ==# 'exit'
        if a:data != 0
            copen
        else
            echo 'vim-arsync: sync completed successfully.'
        endif
    endif
endfunction

function! ShowConf()
    if !ShouldSync()
        echoerr 'vim-arsync: No .vim-arsync config file found in this directory tree.'
        return
    endif
    let l:conf_dict = LoadConf()
    echo l:conf_dict
endfunction

function! ARsync(direction)
    let l:conf_dict = LoadConf()
    if !has_key(l:conf_dict, 'remote_host')
        if empty(findfile('.vim-arsync', '.;'))
            echoerr 'vim-arsync: No .vim-arsync config file found. Aborting...'
        else
            echoerr 'vim-arsync: .vim-arsync is missing required field: remote_host. Aborting...'
        endif
        return
    endif

    let l:user_passwd = ''
    if has_key(l:conf_dict, 'remote_user')
        let l:user_passwd = l:conf_dict['remote_user'] . '@'
    endif
    if has_key(l:conf_dict, 'remote_passwd')
        if !executable('sshpass')
            echoerr 'vim-arsync: sshpass is required for plain-text password auth. Install sshpass or use SSH key auth.'
            return
        endif
        let l:sshpass_passwd = l:conf_dict['remote_passwd']
    endif

    let l:remote_opts = split(l:conf_dict['remote_options'])
    let l:local_opts = split(l:conf_dict['local_options'])
    let l:ssh_cmd = 'ssh -p ' . l:conf_dict['remote_port']
    let l:remote = l:user_passwd . l:conf_dict['remote_host'] . ':' . l:conf_dict['remote_path']

    if l:conf_dict['remote_or_local'] ==# 'remote'
        if a:direction ==# 'down'
            let l:cmd = ['rsync', '--prune-empty-dirs'] + l:remote_opts + ['-e', l:ssh_cmd, l:remote . '/', l:conf_dict['local_path'] . '/']
        elseif a:direction ==# 'up'
            let l:cmd = ['rsync'] + l:remote_opts + ['-e', l:ssh_cmd, l:conf_dict['local_path'] . '/', l:remote . '/']
        elseif a:direction ==# 'upDelete'
            let l:cmd = ['rsync', '--delete'] + l:remote_opts + ['-e', l:ssh_cmd, l:conf_dict['local_path'] . '/', l:remote . '/']
        elseif a:direction ==# 'downDelete'
            let l:cmd = ['rsync', '--delete', '--prune-empty-dirs'] + l:remote_opts + ['-e', l:ssh_cmd, l:remote . '/', l:conf_dict['local_path'] . '/']
        endif
    elseif l:conf_dict['remote_or_local'] ==# 'local'
        if a:direction ==# 'down'
            let l:cmd = ['rsync'] + l:local_opts + [l:conf_dict['remote_path'], l:conf_dict['local_path']]
        elseif a:direction ==# 'up'
            let l:cmd = ['rsync'] + l:local_opts + [l:conf_dict['local_path'], l:conf_dict['remote_path']]
        elseif a:direction ==# 'upDelete'
            let l:cmd = ['rsync', '--delete'] + l:local_opts + [l:conf_dict['local_path'], l:conf_dict['remote_path'] . '/']
        elseif a:direction ==# 'downDelete'
            let l:cmd = ['rsync', '--delete'] + l:local_opts + [l:conf_dict['remote_path'], l:conf_dict['local_path'] . '/']
        endif
    endif

    if has_key(l:conf_dict, 'include_path')
        for file in l:conf_dict['include_path']
            let l:cmd = l:cmd + ['--include', file]
        endfor
    endif
    if has_key(l:conf_dict, 'ignore_path')
        for file in l:conf_dict['ignore_path']
            let l:cmd = l:cmd + ['--exclude', file]
        endfor
    endif
    if has_key(l:conf_dict, 'ignore_dotfiles') && l:conf_dict['ignore_dotfiles'] == 1
        let l:cmd = l:cmd + ['--exclude', '.*']
    endif
    if has_key(l:conf_dict, 'remote_passwd')
        let l:cmd = ['sshpass', '-p', l:sshpass_passwd] + l:cmd
    endif

    call setqflist([], ' ', {'title' : 'vim-arsync'})
    let g:arsync_qfid = getqflist({'id' : 0}).id
    let l:job_id = arsync#job#start(l:cmd, {
                \ 'on_stdout': function('JobHandler'),
                \ 'on_stderr': function('JobHandler'),
                \ 'on_exit': function('JobHandler'),
                \ })
endfunction

function! AutoSync()
    " Always reset the auto-sync group first to prevent duplicate autocmds
    " when AutoSync() is called multiple times (VimEnter, DirChanged, etc.)
    augroup vimarsync_auto
        autocmd!
    augroup END

    if !ShouldSync()
        return
    endif

    let l:conf_dict = LoadConf()
    if has_key(l:conf_dict, 'auto_sync_up') && l:conf_dict['auto_sync_up'] == 1
        augroup vimarsync_auto
            if has_key(l:conf_dict, 'sleep_before_sync') && l:conf_dict['sleep_before_sync'] > 0
                let g:arsync_sleep_time = l:conf_dict['sleep_before_sync'] * 1000
                autocmd BufWritePost,FileWritePost * call timer_start(g:arsync_sleep_time, { -> execute("call ARsync('up')", "")})
            else
                autocmd BufWritePost,FileWritePost * call ARsync('up')
            endif
        augroup END
    endif
endfunction

if !executable('rsync')
    echoerr 'vim-arsync: rsync is required but not found in PATH.'
    finish
endif

command! ARsyncUp call ARsync('up')
command! ARsyncUpDelete call ARsync('upDelete')
command! ARsyncDown call ARsync('down')
command! ARsyncDownDelete call ARsync('downDelete')
command! ARshowConf call ShowConf()

augroup vimarsync
    autocmd!
    autocmd VimEnter * call AutoSync()
    autocmd DirChanged * call AutoSync()
augroup END
