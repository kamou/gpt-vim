
fun! gpt#utils#build_header(username)
  let user = a:username . ":"
  let txt  = user . "\n"
  let txt  = txt . repeat("=", len(user)) . "\n\n"
  return txt
endfun

fun! gpt#utils#get_session_id()
  if bufexists(gpt#utils#bufname())
    let lognr = gpt#utils#bufnr()
    let fl=getbufline(lognr, 2)[0]

    if fl[0:len("SESSION")-1] == "SESSION"
      let sp = split(fl)
      return sp[1]
    end
  end
  return "default"
endfun

function gpt#utils#split_win(...)
  if a:0 > 0
    let l:bnr = a:1
  end
  if winwidth(0) > winheight(0) * 2
    execute "vsplit" bufname(l:bnr)
  else
    execute "split" bufname(l:bnr)
  endif
endfunction

function gpt#utils#bufnr() abort
  return bufnr("GPT Chat")
endfunction

function gpt#utils#bufname() abort
  return "GPT Log"
endfunction

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

function gpt#utils#Register(name, obj) abort
  let bufnr = bufnr(a:name)
  if bufnr >= 0
    call setbufvar(bufnr, "__obj__", a:obj)
  else
    throw "No such buffer: " .. a:name
  endif
endfunction

function gpt#utils#FromBuffer(name) abort
  let bufnr = bufnr(a:name)
  if bufnr >= 0
    return getbufvar(bufnr, "__obj__")
  endif
  return v:null
endfunction


"" vim: ft=vim sw=2 foldmethod=marker foldlevel=0
