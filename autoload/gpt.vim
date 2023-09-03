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

  " first check if the current window is a chat window
  let Wchat = gpt#utils#FromBuffer('%')
  if Wchat->empty() || Wchat.type != "chat"
    " otherwise locate the default main chat window
    let Wchat = gpt#utils#FromBuffer(bufnr("GPT Chat"))
    if Wchat->empty()
      " otherwise create a new main chat window
      let Wchat = gpt#chat#create({"name": "GPT Chat"})
    endif
  endif

  if gpt#utils#FromBuffer(bufnr("GPT Conversations"))->empty()
    call gpt#sessions#create()
  endif

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
  let answer = Wchat.UserSay(l:prompt)
  if has_key(answer, "error")
    echoerr "Message failed with error: " .. answer["error"]
    return
  endif

  let l:content = "\n\n" . gpt#utils#build_header("User")
  let l:content = l:content . l:prompt ."\n\n"
  let l:content = l:content . gpt#utils#build_header('Assistant')

  call Wchat.BufAppendString(l:content)
  call Wchat.Show()

endfunction

function gpt#terminate()
  let Wchat = gpt#utils#FromBuffer("GPT Chat")
  if !Wchat->empty() && !Wchat.GetStreamId()->empty()
    call timer_stop(Wchat.GetStreamId())
  endif
endfunction

function gpt#List()
  " first check if the current window is a chat window
  if gpt#utils#FromBuffer('%')->empty()
    " otherwise locate the default main chat window
    if gpt#utils#FromBuffer(bufnr("GPT Chat"))->empty()
      " otherwise create a new main chat window
      call gpt#chat#create({"name": "GPT Chat"})
    endif
  endif

  let Wconv = gpt#utils#FromBuffer(bufnr("GPT Conversations"))
  if Wconv->empty()
    let Wconv = gpt#sessions#create()
  endif
  call Wconv.List()
endfunction

"" vim: ft=vim sw=2 foldmethod=marker foldlevel=0
