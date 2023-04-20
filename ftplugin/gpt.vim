" Extend the markdown plugin
runtime! ftplugin/markdown.vim

set scrolloff=999
augroup gpt_syntax
    autocmd!
    autocmd OptionSet * if &filetype == 'gpt' | set filetype=markdown | endif
    autocmd VimLeave *  call Termination()
augroup END

" Define new key mappings
" TODO: actualy implement OpenOptions
nnoremap <silent> <buffer> o :py3 gpt_nvim.gpt.OpenOptions()<CR>
nnoremap <silent> <buffer> q :q<CR>
nnoremap <silent> <buffer> r :call ResetAssist()<CR>
nnoremap <silent> <buffer> s :call SaveConversation()<CR>
setlocal syntax=markdown
