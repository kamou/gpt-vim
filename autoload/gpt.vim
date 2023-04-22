
let g:gpt#plugin_dir = expand('~/.gpt-vim/history')

fun! gpt#build(...) abort
  let Wchat = gpt#widget#GenericWidget("Chat")
  call Wchat.set_autofocus(v:false)

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
    let l:timer_id = timer_start(10, "s:timer_cb", {'repeat': -1})
    call self.set_stream_id(l:timer_id)
  endfunction

  function Wchat.stream_init() abort
    " save current buffer
    let cur_bnr = gpt#utils#switchwin(self.bufnr)

    call setpos("'g", [self.bufnr, line("%"), 1]) " set mark '.' to end of buffer

    " go back to original buffer
    call gpt#utils#switchwin(cur_bnr)
  endfunction

  function Wchat.stream_start() abort
    call self.stream_init()
    call self.timer_start()
  endfunction

  function Wchat.append_line(line) abort
    call setbufvar(self.bufnr, "&modifiable", v:true)
    call appendbufline(self.bufnr, '$', [a:line])
    call setbufvar(self.bufnr, "&modifiable", v:false)
  endfunction

  function Wchat.append_lines(lines) abort
    for line in a:lines
      call self.append_line(line)
    endfor
  endfunction

  function Wchat.append_text(text) abort
    let l:text = split(a:text, '\n', 1)
    call self.append_lines(l:text)
  endfunction

  function Wchat.prepare() abort

    let b:lang = self.get_lang("lang")
    if !empty(b:lang)
      let l:context = "You: " . b:lang . " assistant, Your task: generate valid " . b:lang . " code. Answers: markdown formatted. Multiline " . b:lang . " code should always be properly fenced like this:\n```". b:lang ."\n// your code goes here\n```\nAvoid useless details."
    else
      let l:context = "The user will ask you to generate code. Before generating code, Explain in details what steps need to be done in order to achieve the final result"
    endif
    python3 gpt.GptInitSession()

    " Update DB if needed
    call py3eval("gpt.check_and_update_db(vim.eval('g:gpt#plugin_dir'))")
  endfunction

  call setbufvar(Wchat.bufnr, "&filetype", "gpt")
  call setbufvar(Wchat.bufnr, "&syntax", "markdown")
  call Wchat.set_stream_id(v:null)
  return Wchat.configure_axis("auto")
endfunction


fun! gpt#assist(...) range abort
  " Prepare func args
  let l:selection = a:0 > 0 ? a:1 : v:null

  let Wchat = gpt#widget#get("Chat")
  if empty(Wchat)
    let Wchat = gpt#build()
    call Wchat.prepare()
  endif


  " update the filetype according to the current buffer
  if !gpt#utils#ours(bufnr('%'))
    call Wchat.set_lang(&filetype)
  endif

  let l:gptbufnr = gpt#utils#bufnr()

  " Cancel if currently streaming
  if Wchat.is_streaming()
    echomsg 'Be polite, let GPT finish its answer'
    return
  endif

  execute 'delmarks g'

  let l:prompt = input("> ")
  if empty(l:prompt)
    return
  endif

  " Append current selection to the prompt
  if !empty(l:selection)
    let l:prompt .= "\n```" . b:lang . "\n" . l:selection . "\n```"
  endif

  " Perform the request
  python3 gpt.last_response = gpt.assistant.user_say(vim.eval("l:prompt"), stream=True)

  let l:content = "\n\n" . gpt#utils#build_header("User")
  let l:content = l:content . l:prompt ."\n\n"
  let l:content = l:content . gpt#utils#build_header('Assistant')

  call Wchat.append_text(l:content)
  call Wchat.show()

  call Wchat.stream_start()
endfun

fun! gpt#visual_assist(...) range
  let l:selection = gpt#utils#visual_selection()
  call gpt#assist(l:selection)
endfun

fun! s:timer_cb(id) abort
  let Wchat = gpt#widget#get("Chat")
  call timer_pause(a:id, 1)

  let choice = py3eval("next(gpt.last_response)['choices'][0]")
  let delta = choice["delta"]
  let index = choice["index"]

  if has_key(delta, "content")
    let l:content = delta["content"]
    let l:content = split(l:content, '\n', 1)


    " update Log buffer and short term memory buffer
    call setbufvar(Wchat.bufnr, "&modifiable", v:true)
    call setbufline(Wchat.bufnr, '$', getbufline(Wchat.bufnr, '$')[0] . l:content[0])

    if len(l:content) > 1
      let log_lines = getbufline(Wchat.bufnr, 1, "$")->len()
      call setbufline(Wchat.bufnr, log_lines + 1, l:content[1:])
    endif
    call setbufvar(Wchat.bufnr, "&modifiable", v:false)

    " Follow the answer
    let matching_windows = win_findbuf(Wchat.bufnr)
    for win in matching_windows
      :call win_execute(win, 'normal G$')
    endfor
  endif

  if has_key(choice, "finish_reason") && index(["stop", "length"], choice["finish_reason"]) >= 0
    let answer_start = gpt#utils#getpos(Wchat.bufnr, "'g")[1]
    let lines = getbufline(Wchat.bufnr, answer_start, '$')  " get all the new lines
    let all = join(lines, '\n')  " join the lines with a newline character

    " commit memory
    let pydict = "{\"role\": \"assistant\", \"content\": \"". escape(all, "\"") . "\"}"
    call py3eval("gpt.assistant.update(".pydict .")")

    " done
    if choice["finish_reason"] == "stop"
      call timer_stop(a:id)
      call setbufvar(Wchat.bufnr, "timer_id", v:null)
      call setbufvar(Wchat.bufnr, "&modifiable", v:true)
      call gpt#utils#trim(Wchat.bufnr, "'g", "$")
      call setbufvar(Wchat.bufnr, "&modifiable", v:false)
      return v:false
    endif

    " too many tokens, freeing a few tokens by memory loss. send will delete last
    " memory if not enought tokens are available
    python3 gpt.last_response = gpt.assistant.send(stream=True)

  endif
  call timer_pause(a:id, 0)
endfun

fun! gpt#terminate()
  let gptbufnr = gpt#utils#bufnr()
  let l:timer_id = getbufvar(gptbufnr, "timer_id")
  if !getbufvar(gptbufnr, "timer_id")->empty()
    call timer_stop(l:timer_id)
    end
  endfun

  fun! gpt#save()
    let b:summary = getbufvar(gpt#utils#bufnr(), "summary")
    if empty(b:summary)
      let summary = gpt#sessions#save_conversation()
      call setbufvar(gpt#utils#bufnr(), "summary", l:summary)
    else
      call gpt#sessions#update_conversation(b:summary)
      end
      call gpt#sessions#update_list()
    endfun

    fun! gpt#list()
      if gpt#sessions#update_list()
        call gpt#sessions#list()
      else
        echomsg "No sessions to display"
        end
      endfun

      fun! gpt#close()
        let bname = bufname('%')
        let bnr = bufnr(bname)
        execute "silent close " .  bnr
      endfun

      fun! gpt#reset()
        let bname = bufname('%')
        python3 gpt.assistant.reset()
        let bnr = bufnr(bname)

        call setbufvar(bnr, "&modifiable", v:true)
        call deletebufline(bnr, 1, '$')
        call setbufvar(bnr, "&modifiable", v:false)
        call setbufvar(bnr, "summary", v:null)
      endfun

      "" vim: ft=vim sw=2 foldmethod=marker foldlevel=0
