
function gpt#chat#create(callback, name) abort

  let l:lang = getbufvar(bufnr('%'), "&filetype")
  let l:lang = l:lang && (l:lang != "help") ? l:lang : "lang_name"
  let l:context = "You are a code generation assistant, Your task: generate valid commented code. Answers should be markdown formatted. Multiline code should always be properly fenced like this:\n```".. l:lang .. "\n// your code goes here\n```\nAlways provide meaningful but short explanations."
  let Wchat = gpt#widget#GenericWidget(a:name, l:context)
  let Wchat = Wchat->extend({
        \ "task":     gpt#task#create(a:name, l:context, {"stream": v:true}),
        \ "callback": v:null,
        \ "lang":     v:null,
        \
        \ "Reset":                function('gpt#chat#Reset'),
        \ "Cancel":               function('gpt#chat#Cancel'),
        \ "GetLang":              function('gpt#chat#GetLang'),
        \ "SetLang":              function('gpt#chat#SetLang'),
        \ "UserSay":              function('gpt#chat#UserSay'),
        \ "Prepare":              function('gpt#chat#Prepare'),
        \ "Collect":              function('gpt#chat#Collect'),
        \ "GetSummary":           function('gpt#chat#GetSummary'),
        \ "SetSummary":           function('gpt#chat#SetSummary'),
        \ "StreamInit":           function('gpt#chat#StreamInit'),
        \ "StreamStop":           function('gpt#chat#StreamStop'),
        \ "StreamStart":          function('gpt#chat#StreamStart'),
        \ "IsStreaming":          function('gpt#chat#IsStreaming'),
        \ "GetStreamId":          function('gpt#chat#GetStreamId'),
        \ "SetStreamId":          function('gpt#chat#SetStreamId'),
        \ "AssistReplay" :        function('gpt#chat#AssistReplay'),
        \ "AssistUpdate":         function('gpt#chat#AssistUpdate'),
        \ "GetNextChunk":         function('gpt#chat#GetNextChunk'),
        \ "GetLastAnswer":        function('gpt#chat#GetLastAnswer'),
        \ "SetStreamingCallback": function('gpt#chat#SetStreamingCallback')
        \ })
  let Wchat.task.config.stream = v:true
  call Wchat.SetAutoFocus(v:false)
  call Wchat.SetStreamingCallback(a:callback)
  call setbufvar(Wchat.bufnr, "&filetype", "markdown")
  call setbufvar(Wchat.bufnr, "&syntax", "markdown")
  call Wchat.SetStreamId(v:null)
  call Wchat.SetAxis("auto")
  call Wchat.SetSize(-1)
  call Wchat.Map("n", "q", ":call gpt#utils#FromBuffer('" .. a:name .. "').Hide()<CR>")
  call Wchat.Map("n", "r", ":call gpt#utils#FromBuffer('" .. a:name .. "').Reset()<CR>")
  call Wchat.Map("n", "s", ":call gpt#utils#FromBuffer('Conversations').Save()<CR>")
  call Wchat.Map("n", "L", ":call gpt#utils#FromBuffer('Conversations').List()<CR>")
  call Wchat.Map("n", "c", ":call gpt#utils#FromBuffer('" .. a:name .. "').Cancel()<CR>")
  call Wchat.Prepare()
  call gpt#utils#Register(a:name, Wchat)
  return Wchat
endfunction

function gpt#chat#Reset() abort dict
  if self.Cancel()
    call self.task.Reset()
    call self.DeleteLines(1, '$')
    call self.SetVar("summary", v:null)
  endif
endfunction

function gpt#chat#Cancel() abort dict
  if self.GetVar("timer_id")
    if confirm("Are you sure you want to cancel the streaming ?", "&yes\n&no") == 1
      call self.StreamStop()
    endif
  endif
  return !self.IsStreaming()
endfunction

function gpt#chat#GetLang() abort dict
  return self.lang
endfunction

function gpt#chat#SetLang(lang) abort dict
  if a:lang != self.lang && !empty(a:lang) && a:lang != "help"
    call self.task.SystemSay("The user have switched to a new " .. a:lang .. " file. Unless asked otherwise, from now on, the genered code should be in " .. a:lang .. ". Do not forget to fence multiline code with ```" ..a:lang .. ".")
    let self.lang = a:lang
  endif
endfunction

function gpt#chat#UserSay(prompt) abort dict
  return self.task.UserSay(a:prompt)
endfunction

function gpt#chat#Prepare() abort dict
  let l:lang = self.GetLang()
  " Update DB if needed
  call py3eval("gpt.check_and_update_db(vim.eval('g:gpt#plugin_dir') + '/history.db')")
endfunction

function gpt#chat#GetSummary() abort dict
  return self.GetVar("summary")
endfunction

function gpt#chat#SetSummary(summary) abort dict
  return self.SetVar("summary", a:summary)
endfunction

function gpt#chat#StreamInit() abort dict
  " save current buffer
  let cur_bnr = gpt#utils#switchwin(self.bufnr)

  call setpos("'g", [self.bufnr, line("$"), 1]) " set mark 'g' to end of buffer

  " go back to original buffer
  call gpt#utils#switchwin(cur_bnr)
endfunction

function gpt#chat#StreamStop() abort dict
  call timer_stop(self.GetStreamId())
  call self.SetVar("timer_id", v:null)
endfunction

function gpt#chat#AssistReplay() abort dict
  call self.task.Replay()
endfunction

function gpt#chat#StreamStart() abort dict
  if (empty(self.callback))
    throw "No callback registered"
  endif
  call self.StreamInit()
  let l:timer_id = timer_start(10, self.callback, {'repeat': -1})
  call self.SetStreamId(l:timer_id)
endfunction

function gpt#chat#IsStreaming() abort dict
  return getbufvar(self.bufnr, "timer_id")
endfunction

function gpt#chat#GetStreamId() abort dict
  return  self.GetVar("timer_id")
endfunction

function gpt#chat#SetStreamId(id) abort dict
  return  self.SetVar("timer_id", a:id)
endfunction

function gpt#chat#AssistUpdate(message) abort dict
  call self.task.Update(a:message)
endfunction

function gpt#chat#GetNextChunk() abort dict
  return self.task.GetNextChunk()
endfunction

function gpt#chat#GetLastAnswer() abort dict
  let answer_start = self.GetPos("'g")[1]
  let lines = getbufline(Wchat.bufnr, answer_start, '$')  " get all the new lines
  return join(lines, "\n")  " join the lines with a newline character
endfunction

function gpt#chat#SetStreamingCallback(callback) abort dict
  let self.callback = a:callback
endfunction

function gpt#chat#Collect() dict abort
  let answer_start = self.GetPos("'g")[1]
  let lines = getbufline(self.bufnr, answer_start, '$')  " get all the new lines
  return join(lines, "\n")  " join the lines with a newline character
endfunction
" vim: ft=vim sw=2 foldmethod=marker foldlevel=0
