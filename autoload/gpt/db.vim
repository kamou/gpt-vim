function gpt#db#create(path) abort
  let db = {
        \ "path": a:path,
        \
        \ "Get": function('gpt#db#Get'),
        \ "List": function('gpt#db#List'),
        \ "Save": function('gpt#db#Save'),
        \ "Delete": function('gpt#db#Delete'),
        \ "Update": function('gpt#db#Update'),
        \ "GetVers": function('gpt#db#GetVers'),
        \ "SetVers": function('gpt#db#SetVers'),
  \ }
  return db
endfunction

function gpt#db#Get(summary) dict
  return py3eval("gpt.GptDBGet()")
endfunction

function gpt#db#List() dict
  return py3eval("gpt.GptDBList()")
endfunction

function gpt#db#Save(summary, messages) dict
  return py3eval("gpt.GptDBSave()")
endfunction

function gpt#db#Delete(summary) dict
  return py3eval("gpt.GptDBDelete()")
endfunction

function gpt#db#Update(summary, messages) dict
  return py3eval("gpt.GptDBUpdate()")
endfunction

function gpt#db#GetVers() dict
  return py3eval("gpt.GptDBGetVers()")
endfunction

function gpt#db#SetVers(version) dict
  return py3eval("gpt.GptDBSetVers()")
endfunction

" vim: ft=vim sw=2 foldmethod=marker foldlevel=0
