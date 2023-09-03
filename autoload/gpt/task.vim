
function gpt#task#create(name, context, ...) abort
  let l:model = exists("g:gpt_vim_user_model") ? g:gpt_vim_user_model : "gpt-3.5-turbo-16k"
  let l:config = a:0 > 0 ? a:1 : {}
  let l:gptconfig = has_key(config, "gpt") ? config["gpt"] : {}
  let l:memory = has_key(config, "memory") ? config["memory"] : 0
  let task = {
        \ "name":    a:name,
        \ "model": l:model,
        \ "config" : l:gptconfig,
        \ "memory" : l:memory,
        \ "context": a:context,
        \
        \ "Init":        function('gpt#task#Init'),
        \ "Update":      function('gpt#task#Update'),
        \ "Replay":      function('gpt#task#Replay'),
        \ "UserSay":     function('gpt#task#UserSay'),
        \ "SystemSay":   function('gpt#task#SystemSay'),
        \ "Reset":       function('gpt#task#Reset'),
        \ "SetConfig":   function('gpt#task#SetConfig'),
        \ "GetMessages": function('gpt#task#GetMessages'),
        \ "SetMessages": function('gpt#task#SetMessages'),
        \ "GetNextChunk":function('gpt#task#GetNextChunk'),
        \ "BuildFunctionCall":function('gpt#task#BuildFunctionCall'),
        \ "DoCall":function('gpt#task#DoCall'),
        \ "FunctionSay":function('gpt#task#FunctionSay'),
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

function gpt#task#GetMessages() dict
  return py3eval("gpt.GptGetMessages()")
endfunction

function gpt#task#SetMessages(messages) dict
  return py3eval("gpt.GptSetMessages()")
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

function gpt#task#BuildFunctionCall(func) dict
  return py3eval("gpt.GptBuildFunctionCall()")
endfunction

function gpt#task#DoCall() dict
  return py3eval("gpt.GptDoCall()")
endfunction

function gpt#task#FunctionSay() dict
  return py3eval("gpt.GptFunctionSay()")
endfunction
" vim: ft=vim sw=2 foldmethod=marker foldlevel=0
