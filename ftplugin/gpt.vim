" Extend the markdown plugin
runtime! ftplugin/markdown.vim

set scrolloff=999
augroup gpt
    autocmd!
  autocmd BufEnter,BufLeave * if getbufvar(bufnr('%'), "__GPT__") | set wrap | endif
  autocmd BufEnter,BufLeave * if getbufvar(bufnr('%'), "__GPT__") | set nonumber | endif
  autocmd BufEnter,BufLeave * if getbufvar(bufnr('%'), "__GPT__") | set norelativenumber | endif
  autocmd BufEnter,BufLeave * if getbufvar(bufnr('%'), "__GPT__") | set nomodifiable | endif
  autocmd BufEnter,BufLeave * if getbufvar(bufnr('%'), "__GPT__") | set nocursorline | endif
  autocmd BufEnter,BufLeave * if getbufvar(bufnr('%'), "__GPT__") | set nocursorcolumn | endif
  autocmd VimLeave * call gpt#terminate()
augroup END

" Define new key mappings
" TODO: actualy implement OpenOptions
nnoremap <silent> <buffer> o :py3 gpt_nvim.gpt.OpenOptions()<CR>
nnoremap <silent> <buffer> q :call gpt#widget#get("Chat").Hide()<CR>
nnoremap <silent> <buffer> r :call gpt#widget#get("Chat").Reset()<CR>
nnoremap <silent> <buffer> s :call gpt#widget#get("Conversations").Save()<CR>
nnoremap <silent> <buffer> L :call gpt#widget#get("Conversations").List()<CR>
setlocal syntax=markdown

"" vim: ft=vim sw=2 foldmethod=marker foldlevel=0
