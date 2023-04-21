
fun! gpt#sessions#list()
  let bnr = bufadd("GPT Conversations")
  execute "vsplit" bufname(bnr)
  call setbufvar('$', "&number", v:false)
  call setbufvar('$', "&modifiable", v:false)
  call setbufvar('$', "&relativenumber", v:false)
  call setbufvar('$', "&buftype", "nofile")
  call setbufvar('$', "&filetype", "gpt-list")
  call setbufvar('$', "&syntax", "markdown")
  :vertical resize 40
endfun

fun! gpt#sessions#update_list()
  let bnr = bufadd("GPT Conversations")
  call setbufvar(bnr, "&buftype", "nofile")
  call bufload(bnr)
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
  :q
  call gpt#show()
endfun

function gpt#sessions#delete()
  let l:line = getline('.')
  if !empty(l:line)
    call pyeval("gpt.delete_conversation(vim.eval(\"g:gpt#plugin_dir\"), vim.eval(\"l:line\"))")
  end
  call gpt#sessions#update_list()
endfunction

"" vim: ft=vim sw=2 foldmethod=marker foldlevel=0
