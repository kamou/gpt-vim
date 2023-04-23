
function gpt#chat#register(callback) abort
  let Wchat = gpt#widget#get("Chat")
  if empty(Wchat)
    let Wchat = s:gpt_chat_build()
    call Wchat.set_autofocus(v:false)
    call Wchat.register_streaming_callback(a:callback)
    call setbufvar(Wchat.bufnr, "&filetype", "gpt")
    call setbufvar(Wchat.bufnr, "&syntax", "markdown")
    call Wchat.set_stream_id(v:null)
    call Wchat.configure_axis("auto")
    call Wchat.prepare()
  endif
  return Wchat
endfunction

function s:gpt_chat_build() abort
  let Wchat = gpt#widget#GenericWidget("Chat")

  function Wchat.register_streaming_callback(callback) abort
      let self.callback = a:callback
  endfunction

  function Wchat.assist_get_chunk() abort
    return py3eval("gpt.GptGetNextChunk()")
  endfunction

  function Wchat.assist_init(context) abort
    python3 gpt.GptInitSession()
  endfunction

  function Wchat.assist_update(message) abort
    python3 gpt.GptUpdate()
  endfunction

  function Wchat.assist_user_say(prompt) abort
    python3 gpt.last_response = gpt.assistant.user_say(vim.eval("a:prompt"), stream=True)
  endfunction

  function Wchat.set_lang(lang) abort
    call setbufvar(self.bufnr, "lang", a:lang)
  endfunction

  function Wchat.get_lang(lang) abort
    return getbufvar(self.bufnr, "lang")
  endfunction

  function Wchat.is_streaming() abort
    return getbufvar(self.bufnr, "timer_id")
  endfunction

  function Wchat.set_stream_id(id) abort
    return  setbufvar(self.bufnr, "timer_id", a:id)
  endfunction

  function Wchat.timer_start() abort
    let l:timer_id = timer_start(10, self.callback, {'repeat': -1})
    call self.set_stream_id(l:timer_id)
  endfunction

  function Wchat.stream_init() abort
    " save current buffer
    let cur_bnr = gpt#utils#switchwin(self.bufnr)

    call setpos("'g", [self.bufnr, line("$"), 1]) " set mark 'g' to end of buffer

    " go back to original buffer
    call gpt#utils#switchwin(cur_bnr)
  endfunction

  function Wchat.stream_start() abort
    call self.stream_init()
    call self.timer_start()
  endfunction

  function Wchat.prepare() abort

    let b:lang = self.get_lang("lang")
    if !empty(b:lang)
      let l:context = "You: " . b:lang . " assistant, Your task: generate valid " . b:lang . " code. Answers: markdown formatted. Multiline " . b:lang . " code should always be properly fenced like this:\n```". b:lang ."\n// your code goes here\n```\nAvoid useless details."
    else
      let l:context = "The user will ask you to generate code. Before generating code, Explain in details what steps need to be done in order to achieve the final result"
    endif
    call self.assist_init(l:context)

    " Update DB if needed
    call py3eval("gpt.check_and_update_db(vim.eval('g:gpt#plugin_dir'))")
  endfunction

  function Wchat.get_last_answer() abort
    let answer_start = self.getpos("'g")[1]
    let lines = getbufline(Wchat.bufnr, answer_start, '$')  " get all the new lines
    return join(lines, "\n")  " join the lines with a newline character
  endfunction

  function Wchat.get_summary() abort
      return self.getvar("summary")
  endfunction

  function Wchat.set_summary(summary) abort
      return self.setvar("summary", a:summary)
  endfunction

  function Wchat.close() abort
      call self.hide()
  endfunction

  function Wchat.reset() abort
    python3 gpt.assistant.reset()
    call self.delete_lines(1, '$')
    call self.setvar("summary", v:null)
  endfunction

  return Wchat

endfunction
