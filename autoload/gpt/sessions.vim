
function gpt#sessions#register()
  let l:name = "Conversations"
  let Wconv = gpt#widget#get(l:name)
  if empty(Wconv)
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
  endif
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

function gpt#sessions#SaveConv() dict
  let Wchat =  gpt#widget#get("Chat")
  let l:messages = Wchat.task.GetMessages()

  if !empty(l:messages)
    let summary = self.summarizer.Gen(l:messages)
    return self.db.Save(summary, messages)
  endif
  return v:null
endfunction

function gpt#sessions#UpdateConv(summary) dict
  let Wchat =  gpt#widget#get("Chat")
  let l:messages = Wchat.task.GetMessages()
  call self.db.Update(a:summary, l:messages)
endfunction

function gpt#sessions#Save() dict
  let Wchat =  gpt#widget#get("Chat")
  let summary =  Wchat.GetSummary()
  if empty(summary)
    let l:messages = Wchat.task.GetMessages()
    let summary = self.summarizer.Gen(l:messages)
    call self.SaveConv()
    call Wchat.SetSummary(summary)
  else
    call self.UpdateConv(summary)
  endif
endfunction

fun! gpt#sessions#Select() dict
  let Wchat = gpt#widget#get("Chat")
  let l:summary = getline('.')->trim(" ", 0)->split(' ')[1:]->join(" ")
  let l:messages = Wchat.task.GetMessages()

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

  let l:messages = self.db.Get(l:summary)
  call Wchat.task.SetMessages(l:messages)

  let s:session_buffer = v:null

  call self.Hide()
  call Wchat.Show()
endfun

function gpt#sessions#Delete() dict
  let l:summary = getline('.')->trim(" ", 0)->split(' ')[1:]->join(" ")
  call self.cb.Delete(summary)
  let summaries = self.GetSummaries()
  let closeit = empty(summaries)

  let Wchat =  gpt#widget#get("Chat")
  if Wchat.GetSummary() == l:summary
    call Wchat.SetSummary(v:null)
    end

    call self.UpdateList(summaries)

    if closeit
      call self.Hide()
      end
    endfunction



" vim: ft=vim sw=2 foldmethod=marker foldlevel=0
