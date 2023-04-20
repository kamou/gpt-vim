if !has('python3')
    echomsg ':python3 is not available, gpt will not be loaded.'
    finish
endif

let s:plugin_dir = expand('~/.gpt-vim/history')
call mkdir(s:plugin_dir, 'p')

python3 import gpt
python3 GptInitSession = gpt.GptInitSession

fun! gpt#build_header(username)
    let user = a:username . ":"
    let txt  = user . "\n"
    let txt  = txt . repeat("=", len(user)) . "\n\n"
    return txt
endfun

let s:timer_id = v:null
let s:id_to_session_name = {}
fun! gpt#terminate()
    if s:timer_id != v:null
        call timer_stop(s:timer_id)
    end
endfun

fun! gpt#get_session_id()
    if bufexists("GPT Log")

        let lognr = bufnr("GPT Log")
        let fl=getbufline(lognr, 2)[0]
        echo "line2:" . fl

        if fl[0:len("SESSION")-1] == "SESSION"
            let sp = split(fl)
            echo sp
            return sp[1]
        end
    end
    return "default"
endfun

let s:last_lang = v:null
fun! gpt#init(...) range
    if index(["GPT Log", "GPT Conversations"], bufname('%')) >= 0
        let l:lang = s:last_lang
    else
        let l:lang = &filetype
        let s:last_lang = &filetype
    end

    if !bufexists("GPT STM")
        let bnr = bufadd("GPT STM")
        call setbufvar(bnr, "&buftype", "nofile")
        call setbufvar(bnr, "&filetype", "gpt")
        call setbufvar(bnr, "&syntax", "markdown")
        call bufload(bnr)
    endif

    " Chat transcript buffer
    if !bufexists("GPT Log")
        let bnr = bufadd("GPT Log")
        call setbufvar(bnr, "&buftype", "nofile")
        call setbufvar(bnr, "&filetype", "gpt")
        call setbufvar(bnr, "&syntax", "markdown")
        call bufload(bnr)
    end

    if !empty(lang)
        let l:context = "You: " . l:lang . " assistant, Task: generate valid " . l:lang . " code. Answers: markdown formatted. " . l:lang . " code preceded with ```". l:lang .", indentation must always use tabs not spaces"
    else
        let l:context = "The user will ask you to generate code. Before generating code, Explain in details what steps need to be done in order to achieve the final result"
    endif
    python3 GptInitSession()
endfun

fun! gpt#popup(...) range
    let orig = bufnr("%")

    let bnr = bufnr("GPT Log")
    let tabpage_buffers = tabpagebuflist()
    if index(tabpage_buffers, bnr) == -1
        echomsg 'split loading'
        call s:split_win(bnr)
        call setbufvar(bnr, "&cursorline", v:false)
        call setbufvar(bnr, "&cursorcolumn", v:false)
    endif

    let winid = bufwinid(orig)
    call win_gotoid(winid)
endfun

fun! gpt#assist(...) range
    " Prepare func args
    let l:selection = v:null
    if a:0 > 0
        let l:selection = a:1
    end

    call gpt#init()
    " Cancel if currently streaming
    if s:timer_id != v:null
        echomsg 'Be polite, let GPT finish its answer'
        return
    endif

    let l:prompt = input("> ")
    if empty(l:prompt)
        return
    endif

    " Append current selection to the prompt
    if !empty(l:selection)
        let l:prompt .= "\n```" . s:last_lang . "\n" . l:selection . "\n```"
    endif

    let l:content = "\n\n" . gpt#build_header("User")
    let l:content = l:content . l:prompt ."\n\n"

    " Perform the request
    python3 gpt.last_response = gpt.assistant.user_say(vim.eval("l:prompt"), stream=True)

    let l:content = l:content . gpt#build_header('Assistant')


    let l:content = split(l:content, '\n', 1)
    for line in l:content
        call appendbufline(bufnr("GPT Log"), '$', [line])
    endfor

    call gpt#popup()
    let s:timer_id = timer_start(10, "gpt#update", {'repeat': -1})
endfun

fun! gpt#update(id)
    call timer_pause(a:id, 1)

    let choice = py3eval("next(gpt.last_response)['choices'][0]")
    let delta = choice["delta"]
    let index = choice["index"]

    if has_key(delta, "content")
        let l:content = delta["content"]
        let l:content = split(l:content, '\n', 1)

        let streamnr = bufnr("GPT STM")
        let lognr = bufnr("GPT Log")

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
        let lines = getbufline(bufnr("GPT STM"), 1, '$')  " get all lines in the buffer
        let all = join(lines, '\n')  " join the lines with a newline character

        " commit memory
        let pydict = "{\"role\": \"assistant\", \"content\": \"". escape(all, "\"") . "\"}"
        call py3eval("gpt.assistant.update(".pydict .")")

        " done
        if choice["finish_reason"] == "stop"
            call timer_stop(a:id)
            let s:timer_id = v:null
            call deletebufline(bufnr("GPT STM"), 1 , '$')
            return v:false
        endif

        " too many tokens, freeing a few tokens by memory loss. send will delete last
        " memory if not enought tokens are available
        python3 gpt.last_response = gpt.assistant.send(stream=True)

    endif
    call timer_pause(a:id, 0)
endfun

function! s:split_win(...)
  if a:0 > 0
      let l:bnr = a:1
  end
  if winwidth(0) > winheight(0) * 2
      execute "vsplit" bufname(l:bnr)
  else
      execute "split" bufname(l:bnr)
  endif
endfunction

fun! gpt#save()
    let l:session = gpt#get_session_id()
    if l:session == "default"
        python3 gpt.save_conversation(vim.eval("l:session"), vim.eval("s:plugin_dir"))
    else
        python3 gpt.replace_conversation(vim.eval("l:session"), vim.eval("s:plugin_dir"))
    end
endfun

fun! gpt#reset()
    let bname = bufname('%')
    let l:session = gpt#get_session_id()
    " python3 gpt.assistant = None
    python3 gpt.assistant.reset()
    let bnr = bufnr(bname)
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

fun! gpt#visual_assist(...) range
    let l:selection = gpt#visual_selection()
    call gpt#assist(l:selection)
endfun

fun! gpt#list()
    let bnr = bufadd("GPT Conversations")
    call setbufvar(bnr, "&buftype", "nofile")
    call bufload(bnr)
    let summaries = pyeval("gpt.get_summary_list(vim.eval(\"s:plugin_dir\"))")
    call setbufline(bnr, 1, summaries)
    execute "vsplit" bufname(bnr)
    call setbufvar('$', "&number", v:false)
    call setbufvar('$', "&relativenumber", v:false)
    call setbufvar('$', "&buftype", "nofile")
    call setbufvar('$', "&filetype", "gpt-list")
    call setbufvar('$', "&syntax", "markdown")
    :vertical resize 40
endfun

fun! gpt#select_list()

    call gpt#init()
    let l:line = getline('.')
    let l:id = pyeval("gpt.get_conversation_id_from_summary(vim.eval(\"l:line\"))")
    let l:messages = pyeval("gpt.get_conversation(vim.eval(\"s:plugin_dir\"), vim.eval(\"l:line\"))")

    let l:content = ""
    for message in l:messages
        if message["role"] == "user"
            let l:content .= "\n\n" . gpt#build_header("User")
        elseif message["role"] == "assistant"
            let l:content .= "\n\n" . gpt#build_header("Assistant")
        else
            continue
        end
        let l:content .= message["content"]
    endfor


    call deletebufline("GPT Log", 1 , '$')
    call appendbufline("GPT Log", '$', "SESSION ". l:id)

    for ln in split(l:content, "\n", 1)
        call appendbufline("GPT Log", '$', ln)
    endfor

    python3 gpt.set_conversation(vim.eval("s:plugin_dir"), vim.eval("l:id"), vim.eval("l:line"))
    let s:session_buffer = v:null
    :q
    call gpt#popup()
endfun
