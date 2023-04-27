let s:__GPT__Object__ = {}

fun! gpt#utils#build_header(username)
  let user = a:username . ":"
  let txt  = user . "\n"
  let txt  = txt . repeat("=", len(user)) . "\n\n"
  return txt
endfun

function gpt#utils#visual_selection() abort
  try
    let a_save = @a
    silent! normal! gv"ay
    return @a
  finally
    let @a = a_save
  endtry
endfunction

function gpt#utils#switchwin(bnr)
  let cur_bnr = bufnr("%")

  let winid = bufwinid(a:bnr)
  call win_gotoid(winid)
  return cur_bnr
endfunction


function gpt#utils#ours(bnr)
  return getbufvar(a:bnr, "__GPT__")
endfunction

function gpt#utils#Register(bnr, obj) abort
  let s:__GPT__Object__[a:bnr] = a:obj
endfunction

function gpt#utils#FromBuffer(bnr) abort
  let l:bnr = bufnr(a:bnr)
  if bufnr(l:bnr) > 0
    if s:__GPT__Object__->has_key(l:bnr)
      return s:__GPT__Object__[l:bnr]
    endif
  endif
  return v:null
endfunction


"" vim: ft=vim sw=2 foldmethod=marker foldlevel=0
