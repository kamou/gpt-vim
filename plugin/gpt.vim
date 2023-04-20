if !has('python3')
    echomsg ':python3 is not available, gpt will not be loaded.'
    finish
endif

python3 import gpt
python3 GptCreateSession = gpt.GptCreateSession

fun! gpt#build_header(username)
    let user = a:username . ":"
    let txt  = user . "\n"
    let txt  = txt . repeat("=", len(user)) . "\n\n"
    return txt
endfun

let s:timer_id = v:null

let s:session = {}
let s:id_to_session_name = {}
fun! Termination()
    for id in keys(s:id_to_session_name)
        call timer_stop(str2nr(id))
    endfor
endfun

fun! GptAssistNG(...) range

    " Prepare func args
    let l:session = "default"
    let l:selection = v:null
    if a:0 > 0
        let l:session = a:1
    end
    if a:0 > 1
        let l:selection = a:2
    end

    " Cancel if currently streaming
    if has_key(s:session, l:session)
        if has_key(s:session[l:session], "id")
            echomsg 'Be polite, let GPT finish its answer'
            return
        endif
    endif

    let s:session[l:session] = {}

    " Build system context
    let l:lang = &filetype
    if !empty(lang)
        let l:context = "You: " . l:lang . " assistant, Task: generate valid " . l:lang . " code. Answers: markdown formatted. " . l:lang . " code preceded with ```". l:lang .", indentation must always use tabs not spaces"
    else
        let l:context = "The user will ask you to generate code. Before generating code, Explain in details what steps need to be done in order to achieve the final result"
    endif

    " Create current session if needed
    if py3eval("\"". l:session . "\" in gpt.AM.assistants") == v:false
        python3 gpt.assistant = GptCreateSession()
    endif

    let l:prompt = input("> ")
    if empty(l:prompt)
        return
    endif

    " Append current selection to the prompt
    if !empty(l:selection)
        let l:prompt .= "\n```" . l:lang . "\n" . l:selection . "\n```"
    endif

    let l:content = "\n\n" . gpt#build_header("User")
    let l:content = l:content . l:prompt ."\n\n"

    " Perform the request
    python3 gpt.last_response = gpt.assistant.user_say(vim.eval("l:prompt"), stream=True)

    let l:content = l:content . gpt#build_header('Assistant')

    " buffer used to store the streamed content for GPT's short term memory
    if !bufexists("GPT STM - " . l:session)
        let bnr = bufadd("GPT STM - " . l:session)
        call setbufvar(bnr, "&buftype", "nofile")
        call setbufvar(bnr, "&filetype", "gpt")
        call setbufvar(bnr, "&syntax", "markdown")
        call bufload(bnr)
    endif

    " Chat transcript buffer
    if !bufexists("GPT Log - " . l:session)
        let bnr = bufadd("GPT Log - " . l:session)
        call setbufvar(bnr, "&buftype", "nofile")
        call setbufvar(bnr, "&filetype", "gpt")
        call setbufvar(bnr, "&syntax", "markdown")
        call bufload(bnr)
    else
        let bnr = bufadd("GPT Log - " . l:session)
    endif

    " Show the buffer if it is not displayed
    if bufwinnr(bnr) == -1
        call SplitWindow(bnr)
        call setwinvar(0, "&wrap", v:true)
    endif

    let l:content = split(l:content, '\n', 1)
    for line in l:content
        call appendbufline(bnr, '$', [line])
    endfor

    let l:id = timer_start(10, "GptUpdateNGFromVim", {'repeat': -1})
    let s:session[l:session]["id"] = id
    let s:id_to_session_name[id] = l:session
endfun

fun! GptUpdateNGFromVim(id)
    call timer_pause(a:id, 1)

    let l:session = s:id_to_session_name[a:id]
    let choice = py3eval("next(gpt.last_response)['choices'][0]")
    let delta = choice["delta"]
    let index = choice["index"]

    if has_key(delta, "content")
        let l:content = delta["content"]
        let l:content = split(l:content, '\n', 1)

        let streamnr = bufadd("GPT STM - " . l:session)
        let lognr = bufadd("GPT Log - " . l:session)

        " update Log buffer and short term memory buffer
        call setbufline(streamnr, '$', getbufline(streamnr, '$')[0] . l:content[0])
        call setbufline(lognr, '$', getbufline(lognr, '$')[0] . l:content[0])
        if len(l:content) > 1
            let log_lines = len(getbufline(lognr, 1, "$"))
            let stream_lines = len(getbufline(streamnr, 1, "$"))
            call setbufline(lognr, log_lines + 1, l:content[1:])
            call setbufline(streamnr, stream_lines + 1, l:content[1:])
        endif

        " Follow the answer
        let matching_windows = win_findbuf(lognr)
        for win in matching_windows
            :call win_execute(win, 'normal G$')
        endfor

    endif

    if has_key(choice, "finish_reason") && index(["stop", "length"], choice["finish_reason"]) >= 0
        let lines = getbufline(bufadd("GPT STM - " . l:session), 1, '$')  " get all lines in the buffer
        let all = join(lines, '\n')  " join the lines with a newline character

        " commit memory
        let pydict = "{\"role\": \"assistant\", \"content\": \"". escape(all, "\"") . "\"}"
        call py3eval("gpt.AM.assistants[\"" . l:session. "\"].update(".pydict .")")

        " done
        if choice["finish_reason"] == "stop"
            call timer_stop(a:id)
            call deletebufline(bufadd("GPT STM - " . l:session), 1 , '$')
            call remove(s:session[l:session], "id")
            return v:false
        endif

        " too many tokens, freeing a few tokens by memory loss. send will delete last
        " memory if not enought tokens are available
        python3 gpt.last_response = AM.assistants[vim.eval("l:session")].send(stream=True)

    endif
    call timer_pause(a:id, 0)
endfun

function! SplitWindow(bnr)
  if winwidth(0) > winheight(0) * 2
    execute "vsplit" bufname(a:bnr)
  else
    execute "split" bufname(a:bnr)
  endif
endfunction

fun! SaveConversation()
    let bname = bufname('%')
    let l:session = substitute(bname, "GPT Log - ", "", "")
    python3 gpt.SaveConversation(vim.eval("l:session"))
endfun

fun! ResetAssist()
    let bname = bufname('%')
    let l:session = substitute(bname, "GPT Log - ", "", "")
    python3 gpt.assistant = None
    python3 del gpt.AM.assistants[vim.eval("l:session")]
    let bnr = bufadd(bname)
    call deletebufline(bnr, 1, '$')
    let matching_windows = win_findbuf(bnr)
    for win in matching_windows
        :call win_execute(win, ':q')
    endfor
endfun

function! gpt#visual_selection() abort
  try
    let a_save = @a
    silent! normal! gv"ay
    return @a
  finally
    let @a = a_save
  endtry
endfunction


fun! VisGptAssistNG(...) range
    let l:selection = gpt#visual_selection()
    let l:session = "default"
    if a:0 > 0
        let l:session = a:1
    end

    call GptAssistNG(session, l:selection)
endfun

func! s:create_session(session)
    :py3 GptCreateSession()
endf


command! GptAssist python3 GptAssist()
command! -range=% GptAssist <line1>,<line2>call GptAssistNG(<f-args>)
command! -range=% VisGptAssistNG <line1>,<line2>call VisGptAssistNG(<f-args>)
command! -nargs=1 GptCreateSession call s:create_session(<f-args>)
command! -nargs=1 GptInsertLast call s:insert_last(<f-args>)
