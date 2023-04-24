
function gpt#summarizer#create() abort
  let  context = "in no more than five words, provide a meaningful description of the topic for the following conversation."
  let summarizer = {
              \ "task": gpt#task#create("summarizer", l:context),
              \
              \ "Gen": function('gpt#summarizer#Gen')
  \ }
  return summarizer
endfunction

function gpt#summarizer#Gen(messages) dict abort
    let l:messages = ""
    for message in a:messages
        if message["role"] != "system"
            let l:messages ..= message["role"] .. ":\n"..
                        \ repeat("=", len(message["role"])) ..  "\n\n" ..
                        \ message["content"] .. "\n\n" ..
                        \ "==========\n\n"
        endif
    endfor
    return self.task.UserSay(l:messages)["choices"][0]["message"]["content"]
endfunction
" vim: ft=vim sw=2 foldmethod=marker foldlevel=0
