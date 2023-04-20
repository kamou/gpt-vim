
fun! gpt#sessions#list()
  let bnr = bufadd("GPT Conversations")
  execute "vsplit" bufname(bnr)
  call setbufvar('$', "&number", v:false)
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
  call setbufline(bnr, 1, summaries)
  return !empty(summaries)
endfun

fun! gpt#sessions#save_conversation(id)
  python3 gpt.save_conversation(vim.eval("a:id"), vim.eval("g:gpt#plugin_dir"))
endfun

fun! gpt#sessions#update_conversation(id)
  python3 gpt.replace_conversation(vim.eval("a:id"), vim.eval("g:gpt#plugin_dir"))
endfun

fun! gpt#sessions#select_list()
  call gpt#init()
  let l:line = getline('.')
  let l:id = pyeval("gpt.get_conversation_id_from_summary(vim.eval(\"l:line\"))")
  let l:messages = pyeval("gpt.get_conversation(vim.eval(\"g:gpt#plugin_dir\"), vim.eval(\"l:line\"))")

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


  call deletebufline("GPT Log", 1 , '$')
  call appendbufline("GPT Log", '$', "SESSION ". l:id)

  for ln in split(l:content, "\n", 1)
    call appendbufline("GPT Log", '$', ln)
  endfor

  python3 gpt.set_conversation(vim.eval("g:gpt#plugin_dir"), vim.eval("l:id"), vim.eval("l:line"))
  let s:session_buffer = v:null
  :q
  call gpt#popup()
endfun

"" vim: ft=vim sw=2 foldmethod=marker foldlevel=0
