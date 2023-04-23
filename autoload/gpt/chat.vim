
function gpt#chat#register(callback) abort
  let Wchat = gpt#widget#get("Chat")
  if (empty(Wchat))
    let Wchat = gpt#widget#GenericWidget("Chat")
    let Wchat = Wchat->extend({
          \ "callback": v:null,
          \ "lang":     v:null,
          \
          \ "Reset":                function('gpt#chat#Reset'),
          \ "GetLang":              function('gpt#chat#GetLang'),
          \ "SetLang":              function('gpt#chat#SetLang'),
          \ "UserSay":              function('gpt#chat#UserSay'),
          \ "Prepare":              function('gpt#chat#Prepare'),
          \ "GetSummary":           function('gpt#chat#GetSummary'),
          \ "SetSummary":           function('gpt#chat#SetSummary'),
          \ "StreamInit":           function('gpt#chat#StreamInit'),
          \ "AssistInit":           function('gpt#chat#AssistInit'),
          \ "StreamStop":           function('gpt#chat#StreamStop'),
          \ "StreamStart":          function('gpt#chat#StreamStart'),
          \ "IsStreaming":          function('gpt#chat#IsStreaming'),
          \ "GetStreamId":          function('gpt#chat#GetStreamId'),
          \ "SetStreamId":          function('gpt#chat#SetStreamId'),
          \ "AssistUpdate":         function('gpt#chat#AssistUpdate'),
          \ "GetNextChunk":         function('gpt#chat#GetNextChunk'),
          \ "GetLastAnswer":        function('gpt#chat#GetLastAnswer'),
          \ "SetStreamingCallback": function('gpt#chat#SetStreamingCallback')
          \ })
    call Wchat.SetAutoFocus(v:false)
    call Wchat.SetStreamingCallback(a:callback)
    call setbufvar(Wchat.bufnr, "&filetype", "gpt")
    call setbufvar(Wchat.bufnr, "&syntax", "markdown")
    call Wchat.SetStreamId(v:null)
    call Wchat.SetAxis("auto")
    call Wchat.SetSize(-1)
    call Wchat.Prepare()
  endif
  return Wchat
endfunction

function gpt#chat#Reset() abort dict
  python3 gpt.assistant.reset()
  call self.DeleteLines(1, '$')
  call self.SetVar("summary", v:null)
endfunction

function gpt#chat#GetLang() abort dict
  return self.lang
endfunction

function gpt#chat#SetLang(lang) abort dict
  let self.lang = a:lang
endfunction

function gpt#chat#UserSay(prompt) abort dict
  python3 gpt.last_response = gpt.assistant.user_say(vim.eval("a:prompt"), stream=True)
endfunction

function gpt#chat#Prepare() abort dict

  let b:lang = self.GetLang()
  if !empty(b:lang)
    let l:context = "You: " . b:lang . " assistant, Your task: generate valid " . b:lang . " code. Answers: markdown formatted. Multiline " . b:lang . " code should always be properly fenced like this:\n```". b:lang ."\n// your code goes here\n```\nAvoid useless details."
  else
    let l:context = "The user will ask you to generate code. Before generating code, Explain in details what steps need to be done in order to achieve the final result"
  endif
  call self.AssistInit(l:context)

  " Update DB if needed
  call py3eval("gpt.check_and_update_db(vim.eval('g:gpt#plugin_dir'))")
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

function gpt#chat#AssistInit(context) abort dict
  python3 gpt.GptInitSession()
endfunction

function gpt#chat#StreamStop() abort dict
  call timer_stop(self.GetStreamId())
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
  python3 gpt.GptUpdate()
endfunction

function gpt#chat#GetNextChunk() abort dict
  return py3eval("gpt.GptGetNextChunk()")
endfunction

function gpt#chat#GetLastAnswer() abort dict
  let answer_start = self.GetPos("'g")[1]
  let lines = getbufline(Wchat.bufnr, answer_start, '$')  " get all the new lines
  return join(lines, "\n")  " join the lines with a newline character
endfunction

function gpt#chat#SetStreamingCallback(callback) abort dict
  let self.callback = a:callback
endfunction
