" Extend the markdown plugin
runtime! ftplugin/markdown.vim
hi GPTCursorline term=reverse cterm=reverse

function! RefreshCursorLine()
    let conv = gpt#utils#FromBuffer('%')
    let current_line = line('.')
    if conv.hmatch > 0
      call matchdelete(conv.hmatch)
    endif
    let conv.hmatch =  matchadd('GPTCursorline', '\%' .. current_line  .. 'l', 0, -1, {'window': win_getid(), 'containedin': 'ALL'})
    redraw
endfunction

augroup gpt_list
  autocmd!
  autocmd BufEnter,BufLeave,WinEnter,WinLeave * if bufname('%') == 'GPT Conversations' | setlocal nowrap | endif
  autocmd BufEnter,WinEnter,CursorMoved * if bufname('%') == 'GPT Conversations' | call RefreshCursorLine() | endif
augroup END


"" vim: ft=vim sw=2 foldmethod=marker foldlevel=0
