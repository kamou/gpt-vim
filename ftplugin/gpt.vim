" Extend the markdown plugin
runtime! ftplugin/markdown.vim

set scrolloff=999
augroup gpt
    autocmd!
  autocmd BufEnter * if getbufvar(bufnr('%'), "__GPT__") | setlocal wrap | endif
  autocmd BufEnter * if getbufvar(bufnr('%'), "__GPT__") | setlocal nonumber | endif
  autocmd BufEnter * if getbufvar(bufnr('%'), "__GPT__") | setlocal norelativenumber | endif
  autocmd BufEnter * if getbufvar(bufnr('%'), "__GPT__") | setlocal nomodifiable | endif
  autocmd BufEnter * if getbufvar(bufnr('%'), "__GPT__") | setlocal nocursorline | endif
  autocmd BufEnter * if getbufvar(bufnr('%'), "__GPT__") | setlocal nocursorcolumn | endif
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
