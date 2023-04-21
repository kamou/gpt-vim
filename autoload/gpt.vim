
let g:gpt#plugin_dir = expand('~/.gpt-vim/history')

fun! gpt#init(...) range

  " Chat transcript buffer
  if !bufexists("GPT Log")
    let bnr = bufadd("GPT Log")
    call setbufvar(bnr, "&buftype", "nofile")
    call setbufvar(bnr, "&filetype", "gpt")
    call setbufvar(bnr, "&syntax", "markdown")
    call setbufvar(bnr, "timer_id", v:null)
    call bufload(bnr)
  end

  if !(index(["GPT Log", "GPT Conversations"], bufname('%')) >= 0)
    call setbufvar(gpt#utils#bufnr(), "lang", &filetype)
  end

  let b:lang = getbufvar(gpt#utils#bufnr(), "lang")
  if !empty(b:lang)
      let l:context = "You: " . b:lang . " assistant, Your task: generate valid " . b:lang . " code. Answers: markdown formatted. Multiline " . b:lang . " code should always be properly fenced like this:\n```". b:lang ."\n// your code goes here\n```\nAvoid useless details."
  else
      let l:context = "The user will ask you to generate code. Before generating code, Explain in details what steps need to be done in order to achieve the final result"
  endif
  python3 gpt.GptInitSession()
endfun

fun! gpt#show(...) range
  let cur_bnr = bufnr("%")

  let gptbufnr = gpt#utils#bufnr()
  let tabpage_buffers = tabpagebuflist()
  if index(tabpage_buffers, gptbufnr) == -1
    call gpt#utils#split_win(gptbufnr)
    call setbufvar(gptbufnr, "&cursorline", v:false)
    call setbufvar(gptbufnr, "&cursorcolumn", v:false)
  endif

  let winid = bufwinid(cur_bnr)
  call win_gotoid(winid)
endfun

fun! gpt#assist(...) range
  " Prepare func args
  let l:selection = a:0 > 0 ? a:1 : v:null

  call gpt#init()
  let l:gptbufnr = gpt#utils#bufnr()

  " Cancel if currently streaming
  if ! getbufvar(gptbufnr, "timer_id")->empty()
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


  let l:content = split(l:content, '\n', 1)
  for line in l:content
    call appendbufline(gptbufnr, '$', [line])
  endfor

  call gpt#show()

  call gpt#utils#setpos(gptbufnr,"'g", [gpt#utils#line('$', gptbufnr), 1]) " set mark '.' to end of buffer
  let l:timer_id = timer_start(10, "s:timer_cb", {'repeat': -1})
  call setbufvar(gptbufnr, "timer_id", l:timer_id)
endfun

fun! gpt#visual_assist(...) range
  let l:selection = gpt#utils#visual_selection()
  call gpt#assist(l:selection)
endfun

fun! s:timer_cb(id)
  let gptbufnr = gpt#utils#bufnr()
  call timer_pause(a:id, 1)

  let choice = py3eval("next(gpt.last_response)['choices'][0]")
  let delta = choice["delta"]
  let index = choice["index"]

  if has_key(delta, "content")
    let l:content = delta["content"]
    let l:content = split(l:content, '\n', 1)


    " update Log buffer and short term memory buffer
    call setbufline(gptbufnr, '$', getbufline(gptbufnr, '$')[0] . l:content[0])

    if len(l:content) > 1
      let log_lines = getbufline(gptbufnr, 1, "$")->len()
      call setbufline(gptbufnr, log_lines + 1, l:content[1:])
    endif

    " Follow the answer
    let matching_windows = win_findbuf(gptbufnr)
    for win in matching_windows
      :call win_execute(win, 'normal G$')
    endfor
  endif

  if has_key(choice, "finish_reason") && index(["stop", "length"], choice["finish_reason"]) >= 0
   let answer_start = gpt#utils#getpos(gptbufnr, "'g")[1]
   let lines = getbufline(gptbufnr, answer_start, '$')  " get all the new lines
   let all = join(lines, '\n')  " join the lines with a newline character

   " commit memory
   let pydict = "{\"role\": \"assistant\", \"content\": \"". escape(all, "\"") . "\"}"
   call py3eval("gpt.assistant.update(".pydict .")")

   " done
   if choice["finish_reason"] == "stop"
     call timer_stop(a:id)
     call setbufvar(gptbufnr, "timer_id", v:null)
     call gpt#utils#trim(gptbufnr, "'g", "$")
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
  echomsg "timer id: " .l:timer_id
  if !getbufvar(gptbufnr, "timer_id")->empty()
    call timer_stop(l:timer_id)
  end
endfun

fun! gpt#save()
  let l:session = gpt#utils#get_session_id()
  if l:session == "default"
    call gpt#sessions#save_conversation(l:session)
  else
    call gpt#sessions#update_conversation(l:session)
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
  let matching_windows = win_findbuf(bnr)
  for win in matching_windows
    :call win_execute(win, ':close')
  endfor
endfun

fun! gpt#reset()
  let bname = bufname('%')
  python3 gpt.assistant.reset()
  let bnr = bufnr(bname)
  call deletebufline(bnr, 1, '$')
  let matching_windows = win_findbuf(bnr)
  for win in matching_windows
    :call win_execute(win, ':close')
  endfor
endfun

"" vim: ft=vim sw=2 foldmethod=marker foldlevel=0
