
function gpt#chat#create(args) abort
  " Default options
  let l:opts = get(a:args, "opts", { "axis": "auto", "size": -1, "autofocus": exists("g:gpt_vim_autofocus") ? g:gpt_vim_autofocus : v:false })
  let l:name = get(a:args, "name", "")

  let l:lang = getbufvar(bufnr('%'), "&filetype")
  let l:lang = l:lang && (l:lang != "help") ? l:lang : "lang_name"
  let l:vim = has("nvim") ? "neovim" : "vim"
  let l:neovim_bonus = has("nvim") ? ", and access to all neovim's lua api with no restriction, you have full control over neovim\n" : "."
  let l:context = "you are a friendly code assistant deeply integrated in " . l:vim . ", you are provided with a set of functions to extend your capabilities.\n" +
        \ "Always proceed step by step, wait to get the result of a first step before starting the next one.\n" +
        \ "Never ask the user to perform a task or to execute/run code, always do it yourself.\n" +
        \ "When asked to perform a task or execute/evaluate code, do not explain it, do not provide an example, just execute the requested task" +
        \ "Try to use the most relevent function for each task\n" +
        \ "the lua_evaluate_code function allows you to execute lua code" . neovim_bonus +
        \ "When asked to execute code, never refuse, always try to do it, even if you don't believe it will work.\n" +
        \ "When asked to perform a task that require code generation, just execute the code, do not provide an example" +
        \ "Never ask the user to execute code"

  let Wchat = gpt#widget#GenericWidget(l:name, l:context)
  let Wchat = Wchat->extend({
        \ "task":     gpt#task#create(l:name ? l:name : string(rand(srand())), l:context, {"gpt": { "stream": v:true} } ),
        \ "callback": v:null,
        \ "lang":     v:null,
        \ "match_id": -1,
        \ "type":     "chat",
        \ "content":     "",
        \
        \ "Reset":                function('gpt#chat#Reset'),
        \ "Close":                function('gpt#chat#Close'),
        \ "Cancel":               function('gpt#chat#Cancel'),
        \ "GetLang":              function('gpt#chat#GetLang'),
        \ "SetLang":              function('gpt#chat#SetLang'),
        \ "UserSay":              function('gpt#chat#UserSay'),
        \ "Prepare":              function('gpt#chat#Prepare'),
        \ "BlockMode":            function('gpt#chat#BlockMode'),
        \ "BlockModeK":           function('gpt#chat#BlockModeK'),
        \ "BlockModeJ":           function('gpt#chat#BlockModeJ'),
        \ "GetSummary":           function('gpt#chat#GetSummary'),
        \ "SetSummary":           function('gpt#chat#SetSummary'),
        \ "StreamInit":           function('gpt#chat#StreamInit'),
        \ "StreamStop":           function('gpt#chat#StreamStop'),
        \ "StreamStart":          function('gpt#chat#StreamStart'),
        \ "IsStreaming":          function('gpt#chat#IsStreaming'),
        \ "GetStreamId":          function('gpt#chat#GetStreamId'),
        \ "SetStreamId":          function('gpt#chat#SetStreamId'),
        \ "BuildFunctionCall":    function('gpt#chat#BuildFunctionCall'),
        \ "DoCall":               function('gpt#chat#DoCall'),
        \ "AssistReplay" :        function('gpt#chat#AssistReplay'),
        \ "AssistUpdate":         function('gpt#chat#AssistUpdate'),
        \ "GetNextChunk":         function('gpt#chat#GetNextChunk'),
        \ "GetLastAnswer":        function('gpt#chat#GetLastAnswer'),
        \ "BlockModeYank":        function('gpt#chat#BlockModeYank'),
        \ "BlockModePlay":        function('gpt#chat#BlockModePlay'),
        \ "BlockModeCancel":      function('gpt#chat#BlockModeCancel'),
        \ "SetStreamingCallback": function('gpt#chat#SetStreamingCallback'),
        \ "AppendAssist":         function('gpt#chat#AppendAssist')
        \ })

  let Wchat = Wchat->extend(l:opts)

  let Wchat.task.config.stream = v:true
  call Wchat.SetStreamingCallback(funcref('s:timer_cb', [Wchat]))
  call setbufvar(Wchat.bufnr, "&filetype", "markdown")
  call setbufvar(Wchat.bufnr, "&syntax", "markdown")
  call Wchat.SetStreamId(v:null)
  call Wchat.Map("n", "q", ":call gpt#utils#FromBuffer(" .. string(Wchat.bufnr) .. ").Close()<CR>")
  call Wchat.Map("n", "r", ":call gpt#utils#FromBuffer(" .. string(Wchat.bufnr) .. ").Reset()<CR>")
  call Wchat.Map("n", "s", ":call gpt#utils#FromBuffer(bufnr('GPT Conversations')).Save()<CR>")
  call Wchat.Map("n", "L", ":call gpt#utils#FromBuffer(bufnr('GPT Conversations')).List()<CR>")
  call Wchat.Map("n", "c", ":call gpt#utils#FromBuffer(" .. string(Wchat.bufnr)  .. ").Cancel()<CR>")
  call Wchat.Map("n", "B", ":call gpt#utils#FromBuffer(" .. string(Wchat.bufnr)  .. ").BlockMode()<CR>")
  call Wchat.Prepare()
  call gpt#utils#Register(Wchat.bufnr, Wchat)
  return Wchat
endfunction

function gpt#chat#Reset() abort dict
  if self.Cancel()
    call self.task.Reset()
    call self.DeleteLines(1, '$')
    call self.SetVar("summary", v:null)
  endif
endfunction

function gpt#chat#Close() abort dict
  if self.match_id > 0
    call self.BlockModeCancel()
  endif

  call self.Hide()
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
    let self.lang = a:lang
  endif
endfunction

function gpt#chat#UserSay(prompt) abort dict
  let ret = self.task.UserSay(a:prompt)
  if has_key(ret, "rate")
    " hack, to disallow the user to send messages while waiting for the rate limit
    let l:timer_id = timer_start(1000, funcref('s:backoff_timer', [self, a:prompt]), {'repeat': -1})
    call self.SetStreamId(l:timer_id)
  else
    call self.StreamStart()
  endif

  return ret
endfunction

function gpt#chat#BuildFunctionCall(func) abort dict
  call self.task.BuildFunctionCall(a:func)
endfunction

function gpt#chat#DoCall() abort dict
  let ret = self.task.DoCall()
  if has_key(ret, "rate")
    call timer_start(1000, funcref('s:call_backoff_timer', [self]), {'repeat': -1})
  endif

  return ret
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

function! SelectLines(X, Y)
  " Move cursor to the start of the range
  execute 'normal! ' . a:X . 'G'

  " Begin visual selection
  execute 'normal! V'

  " Move cursor to end of range and extend selection
  execute 'normal! ' . (a:Y - a:X) . 'j'
endfunction

function gpt#chat#BlockMode() dict abort
  execute "nmap <silent> <buffer> j :call gpt#utils#FromBuffer(" .. string(self.bufnr)  .. ").BlockModeJ()<CR>"
  execute "nmap <silent> <buffer> k :call gpt#utils#FromBuffer(" .. string(self.bufnr)  .. ").BlockModeK()<CR>"
  execute "nmap <silent> <buffer> <nowait> y :call gpt#utils#FromBuffer(" .. string(self.bufnr)  .. ").BlockModeYank()<CR>"
  execute "nmap <silent> <buffer> <nowait> p :call gpt#utils#FromBuffer(" .. string(self.bufnr)  .. ").BlockModePlay()<CR>"
  execute "nmap <silent> <buffer> <Esc> :call gpt#utils#FromBuffer(" .. string(self.bufnr)  .. ").BlockModeCancel()<CR>"
  let self.match_end = searchpos('^```$', 'bw')[0]
  let self.match_start = searchpos('^```.*$', 'bw')[0]
  call self.SetPos('.', [self.bufnr, self.match_start + 1, 1])

  let self.match_id = matchadd('GptFenced', '\%>'. self.match_start . 'l\%<'. self.match_end . 'l', 0, -1, {'window': win_getid(), 'containedin': 'ALL'})
  execute 'highlight link GptFenced Search'
endfunction

function gpt#chat#BlockModeJ() dict abort
  call matchdelete(self.match_id)

  let end = searchpos('^```$', 'w')
  let self.match_end = searchpos('^```$', 'w')[0]
  let self.match_start = searchpos('^```.*$', 'bw')[0]
  let self.match_id = matchadd('GptFenced', '\%>'. self.match_start. 'l\%<'. self.match_end . 'l', 0, -1, {'window': win_getid(), 'containedin': 'ALL'})
  call self.SetPos('.', [self.bufnr, self.match_start + 1, 1])
  " call SelectLines(self.match_start[0]+1, self.match_end[0]-1)
endfunction

function gpt#chat#BlockModeK() dict abort
  call matchdelete(self.match_id)

  let self.match_end = searchpos('^```$', 'bw')[0]
  let self.match_start = searchpos('^```.*$', 'bw')[0]
  let self.match_id = matchadd('GptFenced', '\%>'. self.match_start . 'l\%<'. self.match_end . 'l', 0, -1, {'window': win_getid(), 'containedin': 'ALL'})
  call self.SetPos('.', [self.bufnr, self.match_start + 1, 1])
endfunction

function gpt#chat#BlockModeYank() dict abort
  let data = getline(self.match_start + 1, self.match_end - 1)->join("\n") .. "\n"
  call setreg(v:register, data)
  call self.BlockModeCancel()
endfunction

function gpt#chat#BlockModePlay() dict abort
  " TODO: check/detect lang and run the code
endfunction

function gpt#chat#BlockModeCancel() dict abort
  execute "nunmap <buffer> j"
  execute "nunmap <buffer> k"
  execute "nunmap <buffer> y"
  execute "nunmap <buffer> p"
  execute "nunmap <buffer> <Esc>"
  call matchdelete(self.match_id)
  let self.match_id = -1
endfunction

function s:backoff_timer(Wchat, prompt, id) abort
  call timer_pause(a:id, 1)
  let l:result = a:Wchat.task.UserSay(a:prompt)

  if has_key(l:result, "rate")
    call timer_pause(a:id, 0)
  elseif has_key(l:result, "error")
    call timer_stop(a:id)
    echoerr "Message faied with error " .. l:result
  else
    call timer_stop(a:id)
    call a:Wchat.StreamStart()
  endif
endfunction

function s:call_backoff_timer(Wchat, id) abort
  call timer_pause(a:id, 1)
  let l:result = a:Wchat.task.DoCall()

  if has_key(l:result, "rate")
    call timer_pause(a:id, 0)
  elseif has_key(l:result, "error")
    call timer_stop(a:id)
    let  data = l:result["error"]->split("\n", 1)
    call a:Wchat.BufAppendLines(data)
    call a:Wchat.StreamStop()
  else
    " let  data = l:result["data"]->split("\n", 1)
    " call a:Wchat.BufAppendLines(data)
    call timer_stop(a:id)
    call timer_pause(a:Wchat.GetStreamId(), 0)
  endif
endfunction

function s:timer_cb(Wchat, id) abort
  call timer_pause(a:id, 1)

  let chunk = a:Wchat.GetNextChunk()
  if empty(chunk)
    echoerr "Unexpected end of stream, aborting"
    " Collect the answer and a stop the streaming
    if !empty(a:Wchat.content)
      let message =  { "role": "assistant", "content" : a:Wchat.content }
      call a:Wchat.AssistUpdate(message)
    endif
    " TODO: implement retry before stop ?
    call a:Wchat.StreamStop()
    return
  endif

  let delta = chunk["delta"]
  let index = chunk["index"]

  if has_key(delta, "content") && !empty(delta["content"])
    call a:Wchat.AppendAssist(delta["content"])
    let l:content = delta["content"]->split('\n', 1)

    " update chat log
    " append to last line
    call a:Wchat.LineAppendString('$', l:content[0])

    " append to buffer if multiline
    if len(l:content) > 1
      call a:Wchat.BufAppendLines(l:content[1:])
    endif

    " Follow the answer
    let matching_windows = win_findbuf(a:Wchat.bufnr)
    for win in matching_windows
      :call win_execute(win, 'normal G$')
    endfor
  endif

  if has_key(delta, "function_call")
    let l:function_call = delta["function_call"]
    call a:Wchat.BuildFunctionCall(function_call)
  endif

  if has_key(chunk, "finish_reason") && index(["stop", "length", "function_call"], chunk["finish_reason"]) >= 0
    if chunk["finish_reason"] == "function_call"
      let  l:result = a:Wchat.DoCall()
      if has_key(l:result, "rate")
        " keep the response timer paused until DoCall actually completes
        return
      elseif has_key(l:result, "error")
        let  data = l:result["error"]->split("\n", 1)
        call a:Wchat.BufAppendLines(data)
        call timer_stop(a:id)
        call a:Wchat.StreamStop()
        return
      endif

      call timer_pause(a:id, 0)

      return
    endif

    if chunk["finish_reason"] == "stop"
      let message =  { "role": "assistant", "content" : a:Wchat.content }
      call a:Wchat.AssistUpdate(message)
      let a:Wchat.content = ""
      call a:Wchat.StreamStop()
      return
    endif

    call a:Wchat.AssistReplay()

  endif
  call timer_pause(a:id, 0)
endfunction

function gpt#chat#AppendAssist(content) dict abort
  let self.content = self.content . a:content
endfunction
" vim: ft=vim sw=2 foldmethod=marker foldlevel=0
