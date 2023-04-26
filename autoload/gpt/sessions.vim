
function gpt#sessions#create()
  let l:name = "Conversations"
  let Wconv = gpt#widget#GenericWidget(l:name)
  let Wconv = Wconv->extend({
        \ "summarizer":           gpt#summarizer#create(),
        \ "db":                   gpt#db#create(g:gpt#plugin_dir .. "/history.db"),
        \ "List":                 function('gpt#sessions#List'),
        \ "Save":                 function('gpt#sessions#Save'),
        \ "Select":               function('gpt#sessions#Select'),
        \ "Delete":               function('gpt#sessions#Delete'),
        \ "SaveConv":             function('gpt#sessions#SaveConv'),
        \ "UpdateConv":           function('gpt#sessions#UpdateConv'),
        \ "UpdateList":           function('gpt#sessions#UpdateList'),
        \ "GetSummaries":         function('gpt#sessions#GetSummaries'),
        \ })
  call Wconv.SetAutoFocus(v:true)
  call Wconv.SetAxis("vertical")
  call Wconv.SetSize(40)
  call setbufvar(Wconv.bufnr, "&filetype", "gpt-list")
  call setbufvar(Wconv.bufnr, "&syntax", "markdown")

  call Wconv.Map("n", "<CR>"      , ":call gpt#widget#get('Conversations').Select()<CR>")
  call Wconv.Map("n", "<nowait> d", ":call gpt#widget#get('Conversations').Delete()<CR>")
  call Wconv.Map("n", "q"         , ":call gpt#widget#get('Conversations').Hide()<CR>")
  call gpt#utils#Register(l:name, Wconv)
  return Wconv
endfunction

function gpt#sessions#GetSummaries() dict
  return self.db.List()
endfunction

function gpt#sessions#UpdateList(summaries) dict
  call setbufvar(self.bufnr, "&modifiable", v:true)
  call deletebufline(bufname(self.bufnr), 1 , '$')
  call setbufvar(self.bufnr, "&modifiable", v:false)
  if !empty(a:summaries)
    call self.SetLines(1, a:summaries)
  endif
endfunction

function gpt#sessions#List() dict
  let summaries = self.GetSummaries()
  if empty(summaries)
    echomsg "No sessions to display"
  else
    call self.UpdateList(summaries)
    call self.Show()
  endif
endfun

function gpt#sessions#SaveConv(summary, messages) dict
  if !empty(a:messages)
    return self.db.Save(a:summary, a:messages)
  endif
  return v:null
endfunction

function gpt#sessions#UpdateConv(summary, messages) dict
  call self.db.Update(a:summary, a:messages)
endfunction

function gpt#sessions#Save() dict
  let Wchat =  gpt#widget#get("Chat")
  if !Wchat.IsStreaming()
    let summary =  Wchat.GetSummary()
    let l:messages = Wchat.task.GetMessages()
    if empty(summary)
      let summary = self.summarizer.Gen(l:messages)
      call self.SaveConv(summary, l:messages)
      call Wchat.SetSummary(summary)
    else
      call self.UpdateConv(summary, l:messages)
    endif
  else
    echomsg "You can't save during streaming, wait for the end or press `c` to cancel the stream"
  endif
endfunction

fun! gpt#sessions#Select() dict
  let Wchat = gpt#widget#get("Chat")
  if Wchat.Cancel() 
    let l:summary = getline('.')->trim(" ", 0)->split(' ')[1:]->join(" ")

    let l:messages = self.db.Get(l:summary)
    call Wchat.task.SetMessages(l:messages)

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


    call Wchat.SetVar("&modifiable", v:true)
    call deletebufline(bufname(Wchat.bufnr), 1 , '$')
    call Wchat.SetSummary(l:summary)

    for ln in split(l:content, "\n", 1)
      call appendbufline(bufname(Wchat.bufnr), '$', ln)
    endfor
    call Wchat.SetVar("&modifiable", v:false)

    call self.Hide()
    call Wchat.Show()
  endif
endfun

function gpt#sessions#Delete() dict
  let l:summary = getline('.')->trim(" ", 0)->split(' ')[1:]->join(" ")
  call self.db.Delete(summary)
  let summaries = self.GetSummaries()
  let closeit = empty(summaries)

  let Wchat =  gpt#widget#get("Chat")
  if Wchat.GetSummary() == l:summary
    call Wchat.SetSummary(v:null)
  endif

  call self.UpdateList(summaries)

  if closeit
    call self.Hide()
  endif
endfunction



" vim: ft=vim sw=2 foldmethod=marker foldlevel=0
