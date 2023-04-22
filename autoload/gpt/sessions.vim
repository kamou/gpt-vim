
fun! gpt#sessions#init()
  let bnr = bufadd("GPT Conversations")
  call setbufvar(bnr, "&number", v:false)
  call setbufvar(bnr, "&modifiable", v:false)
  call setbufvar(bnr, "&relativenumber", v:false)
  call setbufvar(bnr, "&buftype", "nofile")
  call setbufvar(bnr, "&filetype", "gpt-list")
  call setbufvar(bnr, "&syntax", "markdown")
  call bufload(bnr)
  return bnr
endfun

fun! gpt#sessions#open()
  let bnr  = bufnr("GPT Conversations")
  if !(bnr >= 0)
      let bnr = gpt#sessions#init()
  end

  if !(gpt#sessions#update_list())
    echomsg "No session to display"
    return
  endif

  let tabpage_buffers = tabpagebuflist()
  if index(tabpage_buffers, bnr) == -1
    execute "vsplit" bufname(bnr)
    :vertical resize 40
  endif

  let winid = bufwinid(bnr)
  call win_gotoid(winid)
endfun

fun! gpt#sessions#update_list()
  let bnr = bufnr("GPT Conversations")
  if !(bnr >= 0)
    return
  end

  let summaries = pyeval("gpt.get_summary_list(vim.eval(\"g:gpt#plugin_dir\"))")

  call setbufvar(bnr, "&modifiable", v:true)
  call deletebufline("GPT Conversations", 1 , '$')

  if !empty(summaries)
    call setbufline(bnr, 1, summaries)
  end
  call setbufvar(bnr, "&modifiable", v:false)
  return !empty(summaries)
endfun

fun! gpt#sessions#save_conversation()
  python3 gpt.save_conversation(vim.eval("g:gpt#plugin_dir"))
  return pyeval("gpt.gen_summary()")
endfun

fun! gpt#sessions#update_conversation(summary)
  python3 gpt.replace_conversation(vim.eval("a:summary"), vim.eval("g:gpt#plugin_dir"))
endfun

fun! gpt#sessions#select_list()
  call gpt#init()
  let l:summary = getline('.')->trim(" ", 0)->split(' ')[1:]->join(" ")
  let l:messages = pyeval("gpt.get_conversation(vim.eval(\"g:gpt#plugin_dir\"), vim.eval(\"l:summary\"))")

  let l:content = ""
  for message in l:messages
    if message["role"] == "user"
      let l:content .= "\n\n" . gpt#utils#build_header("User")
    elseif message["role"] == "assistant"
      let l:content .= "\n\n" . gpt#utils#build_header("Assistant")
    else
      continue
    end
    let l:content .= message["content"]
  endfor


  call setbufvar(gpt#utils#bufnr(), "&modifiable", v:true)
  call deletebufline("GPT Log", 1 , '$')
  call setbufvar(gpt#utils#bufnr(),"summary", l:summary )

  for ln in split(l:content, "\n", 1)
    call appendbufline("GPT Log", '$', ln)
  endfor
  call setbufvar(gpt#utils#bufnr(), "&modifiable", v:false)

  python3 gpt.set_conversation(vim.eval("g:gpt#plugin_dir"), vim.eval("l:summary"))
  let s:session_buffer = v:null
  execute "silent close ". bufnr('%')
  call gpt#show()
endfun

function gpt#sessions#delete()
  let l:summary = getline('.')->trim(" ", 0)->split(' ')[1:]->join(" ")
  call pyeval("gpt.delete_conversation(vim.eval(\"g:gpt#plugin_dir\"), vim.eval(\"l:summary\"))")
  let closeit = !gpt#sessions#update_list()

  if getbufvar(gpt#utils#bufnr(), "summary") == l:summary
    call setbufvar(gpt#utils#bufnr(), "summary", v:null)
  end

  if closeit
    execute "silent close ". bufnr('%')
  end
endfunction

"" vim: ft=vim sw=2 foldmethod=marker foldlevel=0
