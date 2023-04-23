
let g:gpt#plugin_dir = expand('~/.gpt-vim/history')



function gpt#assist(...) range abort
  " Prepare func args
  let l:selection = a:0 > 0 ? a:1 : v:null

  let Wchat = gpt#chat#register(funcref('s:timer_cb'))
  call gpt#sessions#register()

  " update the filetype according to the current buffer
  if !gpt#utils#ours(bufnr('%'))
    call Wchat.set_lang(&filetype)
  endif

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
    let b:lang = Wchat.get_lang("lang")
    let l:prompt .= "\n```" . b:lang . "\n" . l:selection . "\n```"
  endif

  " Perform the request
  python3 gpt.last_response = gpt.assistant.user_say(vim.eval("l:prompt"), stream=True)

  let l:content = "\n\n" . gpt#utils#build_header("User")
  let l:content = l:content . l:prompt ."\n\n"
  let l:content = l:content . gpt#utils#build_header('Assistant')

  call Wchat.buf_append_text(l:content)
  call Wchat.show()

  call Wchat.stream_start()
endfunction

function gpt#visual_assist(...) range
  let l:selection = gpt#utils#visual_selection()
  call gpt#assist(l:selection)
endfunction

function s:timer_cb(id) abort
  let Wchat = gpt#widget#get("Chat")
  call timer_pause(a:id, 1)

  let chunk = Wchat.assist_get_chunk()
  let delta = chunk["delta"]
  let index = chunk["index"]

  if has_key(delta, "content")
    let l:content = delta["content"]->split('\n', 1)

    " update chat log
    " append to last line
    call Wchat.line_append_string('$', l:content[0])

    " append to buffer if multiline
    if len(l:content) > 1
      call Wchat.buf_append_lines(l:content[1:])
    endif

    " Follow the answer
    let matching_windows = win_findbuf(Wchat.bufnr)
    for win in matching_windows
      :call win_execute(win, 'normal G$')
    endfor
  endif

  if has_key(chunk, "finish_reason") && index(["stop", "length"], chunk["finish_reason"]) >= 0
    let answer_start = Wchat.getpos("'g")[1]
    let lines = getbufline(Wchat.bufnr, answer_start, '$')  " get all the new lines
    let content = join(lines, "\n")  " join the lines with a newline character

    " commit memory
    let message =  { "role": "assistant", "content" : content }
    call Wchat.assist_update(message)

    " done
    if chunk["finish_reason"] == "stop"
      call timer_stop(a:id)
      call setbufvar(Wchat.bufnr, "timer_id", v:null)
      return v:false
    endif

    " too many tokens, freeing a few tokens by memory loss. send will delete last
    " memory if not enought tokens are available
    python3 gpt.last_response = gpt.assistant.send(stream=True)

  endif
  call timer_pause(a:id, 0)
endfunction

function gpt#terminate()
  let Wchat = gpt#widget#get("Chat")
  if !Wchat.get_stream_id()->empty()
    call timer_stop(l:timer_id)
  endif
endfunction

"" vim: ft=vim sw=2 foldmethod=marker foldlevel=0
