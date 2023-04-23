
function gpt#task#create(name, context) abort
  let task = {
        \ "name":    a:name,
        \ "config":  {
        \   "stream":      v:false,
        \   "temperature": 1.0,
        \   "max_tokens":  4096,
        \ },
        \ "context" : a:context,
        \
        \ "Init":        function('gpt#task#Init'),
        \ "Update":      function('gpt#task#Update'),
        \ "Replay":      function('gpt#task#Replay'),
        \ "UserSay":     function('gpt#task#UserSay'),
        \ "SystemSay":   function('gpt#task#SystemSay'),
        \ "Reset":       function('gpt#task#Reset'),
        \ "SetConfig":   function('gpt#task#SetConfig'),
        \ "GetNextChunk":function('gpt#task#GetNextChunk'),
  \ }
  call task.Init()
  return task
endfunction

function gpt#task#Init() dict
  python3 gpt.GptCreateTask()
endfunction

function gpt#task#Update(message) dict
  return py3eval("gpt.GptUpdate()")
endfunction

function gpt#task#Replay() dict
  return py3eval("gpt.GptReplay()")
endfunction

function gpt#task#UserSay(message) dict
  return py3eval("gpt.GptUserSay()")
endfunction

function gpt#task#SystemSay(message) dict
  return py3eval("gpt.GptSystemSay()")
endfunction

function gpt#task#Reset() dict
  return py3eval("gpt.GptReset()")
endfunction

function gpt#task#SetConfig(config) dict
  let self.config = config
endfunction

function gpt#task#GetNextChunk() dict
  if self.config["stream"]
    return py3eval("gpt.GptGetNextChunk()")
  endif
  return v:null
endfunction

" vim: ft=vim sw=2 foldmethod=marker foldlevel=0
