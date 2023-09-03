" Extend the markdown plugin
runtime! ftplugin/markdown.vim
hi GPTCursorline term=reverse cterm=reverse

function! RefreshCursorLine()
    let conv = gpt#utils#FromBuffer('%')
    let current_line = line('.')
    call conv.SetPos('.', [conv.bufnr, current_line, 1])
    call clearmatches(win_getid())
    let conv.hmatch =  matchadd('GPTCursorline', '\%' .. current_line  .. 'l', 0, -1, {'window': win_getid(), 'containedin': 'ALL'})
    redraw
endfunction

augroup gpt_list
  autocmd!
  autocmd BufEnter,BufLeave,WinEnter,WinLeave * if bufname('%') == 'GPT Conversations' | setlocal nowrap nocursorline nocursorcolumn | endif
  autocmd BufEnter,WinEnter,CursorMoved * if bufname('%') == 'GPT Conversations' | call RefreshCursorLine() | endif
augroup END


"" vim: ft=vim sw=2 foldmethod=marker foldlevel=0
