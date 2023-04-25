let g:gpt#plugin_dir = expand('~/.gpt-vim/history')


" old api
function gpt#visual_assist(...) range
  let l:selection = gpt#utils#visual_selection()
  call gpt#assist(l:selection)
endfunction

function gpt#assist(...) range abort
  return gpt#Assist(a:0 > 0)
endfunction

" new api
function gpt#Assist(vmode) range abort
  " Prepare func args
  let l:selection = a:vmode ? gpt#utils#visual_selection() : v:null

  let Wchat = gpt#chat#register(funcref('s:timer_cb'))
  call gpt#sessions#register()

  " update the filetype according to the current buffer
  if !gpt#utils#ours(bufnr('%'))
    call Wchat.SetLang(&filetype)
  endif

  " Cancel if currently streaming
  if Wchat.IsStreaming()
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
    let b:lang = Wchat.GetLang()
    let l:prompt .= "\n```" . b:lang . "\n" . l:selection . "\n```"
  endif

  " Perform the request
  call Wchat.UserSay(l:prompt)

  let l:content = "\n\n" . gpt#utils#build_header("User")
  let l:content = l:content . l:prompt ."\n\n"
  let l:content = l:content . gpt#utils#build_header('Assistant')

  call Wchat.BufAppendString(l:content)
  call Wchat.Show()

  call Wchat.StreamStart()
endfunction


function s:timer_cb(id) abort
  let Wchat = gpt#widget#get("Chat")
  call timer_pause(a:id, 1)

  let chunk = Wchat.GetNextChunk()
  if empty(chunk)
    echoerr "Unexpected end of stream, aborting"
    " Collect the answer and a stop the streaming
    let content = Wchat.Collect()

    " commit memory
    let message =  { "role": "assistant", "content" : content }
    call Wchat.AssistUpdate(message)
    " TODO: implement retry before stop ?
    call Wchat.StreamStop()
    return
  endif

  let delta = chunk["delta"]
  let index = chunk["index"]

  if has_key(delta, "content")
    let l:content = delta["content"]->split('\n', 1)

    " update chat log
    " append to last line
    call Wchat.LineAppendString('$', l:content[0])

    " append to buffer if multiline
    if len(l:content) > 1
      call Wchat.BufAppendLines(l:content[1:])
    endif

    " Follow the answer
    let matching_windows = win_findbuf(Wchat.bufnr)
    for win in matching_windows
      :call win_execute(win, 'normal G$')
    endfor
  endif

  if has_key(chunk, "finish_reason") && index(["stop", "length"], chunk["finish_reason"]) >= 0
    let content = Wchat.Collect()

    " commit memory
    let message =  { "role": "assistant", "content" : content }
    call Wchat.AssistUpdate(message)

    " done
    if chunk["finish_reason"] == "stop"
      call Wchat.StreamStop()
      return
    endif

    " too many tokens, freeing a few tokens by memory loss. Replay will delete last
    " memory if not enought tokens are available
    call Wchat.AssistReplay()

  endif
  call timer_pause(a:id, 0)
endfunction

function gpt#terminate()
  let Wchat = gpt#widget#get("Chat")
  if !Wchat->empty() && !Wchat.GetStreamId()->empty()
    call timer_stop(Wchat.GetStreamId())
  endif
endfunction

"" vim: ft=vim sw=2 foldmethod=marker foldlevel=0
