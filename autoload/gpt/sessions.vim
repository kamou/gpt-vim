
function gpt#sessions#register()
  let l:name = "Conversations"
  let Wconv = gpt#widget#get(l:name)
  if empty(Wconv)
    let Wconv = s:gpt_conv_build(l:name)
    call Wconv.set_autofocus(v:true)
    call Wconv.configure_axis("vertical", 40)
    call setbufvar(Wconv.bufnr, "&filetype", "gpt-list")
    call setbufvar(Wconv.bufnr, "&syntax", "markdown")
  endif
  return Wconv
endfunction

function s:gpt_conv_build(name) abort
  let Wconv = gpt#widget#GenericWidget(a:name)

  function Wconv.get_summaries()
    return pyeval("gpt.get_summary_list(vim.eval(\"g:gpt#plugin_dir\"))")
  endfunction

  function Wconv.update_list(summaries)
    call setbufvar(self.bufnr, "&modifiable", v:true)
    call deletebufline(bufname(self.bufnr), 1 , '$')
    call setbufvar(self.bufnr, "&modifiable", v:false)
    if !empty(a:summaries)
      call self.set_lines(1, a:summaries)
    endif
  endfunction

  function Wconv.list()
    let summaries = self.get_summaries()
    if empty(summaries)
      echomsg "No sessions to display"
    else
      call self.update_list(summaries)
      call self.show()
    endif
  endfun

  function Wconv.save_conv()
    if pyeval("len(gpt.assistant.history)")
      python3 gpt.save_conversation(vim.eval("g:gpt#plugin_dir"))
      return pyeval("gpt.gen_summary()")
    endif
    return v:null
  endfunction

  function Wconv.update_conv(summary)
    python3 gpt.replace_conversation(vim.eval("a:summary"), vim.eval("g:gpt#plugin_dir"))
  endfunction

  function Wconv.save()
    let Wchat =  gpt#widget#get("Chat")
    let summary =  Wchat.get_summary()
    if empty(summary)
      call Wchat.set_summary(self.save_conv())
    else
      call self.update_conv(summary)
    endif
  endfunction

  fun! Wconv.select()
    let Wchat = gpt#widget#get("Chat")
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
      endif
      let l:content .= message["content"]
    endfor


    call Wchat.setvar("&modifiable", v:true)
    call deletebufline(bufname(Wchat.bufnr), 1 , '$')
    call Wchat.setvar("summary", l:summary)

    for ln in split(l:content, "\n", 1)
      call appendbufline(bufname(Wchat.bufnr), '$', ln)
    endfor
    call Wchat.setvar("&modifiable", v:false)

    python3 gpt.set_conversation(vim.eval("g:gpt#plugin_dir"), vim.eval("l:summary"))
    let s:session_buffer = v:null

    call self.hide()
    call Wchat.show()
  endfun

function Wconv.delete()
  let l:summary = getline('.')->trim(" ", 0)->split(' ')[1:]->join(" ")
  call pyeval("gpt.delete_conversation(vim.eval(\"g:gpt#plugin_dir\"), vim.eval(\"l:summary\"))")
  let summaries = self.get_summaries()
  let closeit = empty(summaries)

  let Wchat =  gpt#widget#get("Chat")
  if Wchat.getvar("summary") == l:summary
    call Wchat.setvar("summary", v:null)
  end

  call self.update_list(summaries)

  if closeit
    call self.hide()
  end
endfunction

  return Wconv

endfunction


" vim: ft=vim sw=2 foldmethod=marker foldlevel=0
