
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

function! gpt#utils#split_win(...)
  if a:0 > 0
    let l:bnr = a:1
  end
  if winwidth(0) > winheight(0) * 2
    execute "vsplit" bufname(l:bnr)
  else
    execute "split" bufname(l:bnr)
  endif
endfunction


function! gpt#utils#bufnr() abort
  return bufnr("GPT Log")
endfunction

function! gpt#utils#bufname() abort
  return "GPT Log"
endfunction

function! gpt#utils#visual_selection() abort
  try
    let a_save = @a
    silent! normal! gv"ay
    return @a
  finally
    let @a = a_save
  endtry
endfunction

function gpt#utils#getpos(bnr, mark)
  " save current buffer
  let cur_bnr = bufnr("%")

  " go to target buffer
  let winid = bufwinid(a:bnr)
  call win_gotoid(winid)
  let pos = getpos(a:mark) " set mark '.' to end of buffer

  " go back to original buffer
  let winid = bufwinid(cur_bnr)
  call win_gotoid(winid)
  return pos
endfunction

function gpt#utils#setpos(bnr, mark, pos)
  " save current buffer
  let cur_bnr = bufnr("%")

  " go to target buffer
  let winid = bufwinid(a:bnr)
  call win_gotoid(winid)
  let ret = setpos(a:mark, [a:bnr, a:pos[0], a:pos[1]]) " set mark '.' to end of buffer

  " go back to original buffer
  let winid = bufwinid(cur_bnr)
  call win_gotoid(winid)
  return ret
endfunction

function gpt#utils#line(pos, bnr)
  " save current buffer
  let cur_bnr = bufnr("%")

  " go to target buffer
  let winid = bufwinid(a:bnr)
  call win_gotoid(winid)
  let lines = line(a:pos)

  " go back to original buffer
  let winid = bufwinid(cur_bnr)
  call win_gotoid(winid)
  return lines
endfun

"" vim: ft=vim sw=2 foldmethod=marker foldlevel=0
