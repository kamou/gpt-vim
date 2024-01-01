function gpt#widget#GenericWidget(name, ...) abort
  if (!empty(a:name) && bufnr(a:name) >= 0)
    throw "A Buffer named " .. a:name .. " already exists"
  endif

  let w = {
        \ 'size':             -1,
        \ 'maps':             {},
        \ 'axis':             "auto",
        \ 'bufnr':            bufadd(a:name),
        \ 'autofocus':        v:true,
        \
        \ 'Map':              function('gpt#widget#Map'),
        \ 'Hide':             function('gpt#widget#Hide'),
        \ 'Show':             function('gpt#widget#Show'),
        \ 'Resize':           function('gpt#widget#Resize'),
        \ 'GetPos':           function('gpt#widget#GetPos'),
        \ 'SetPos':           function('gpt#widget#SetPos'),
        \ 'GetVar':           function('gpt#widget#GetVar'),
        \ 'SetVar':           function('gpt#widget#SetVar'),
        \ 'GetLine':          function('gpt#widget#GetLine'),
        \ 'SetLine':          function('gpt#widget#SetLine'),
        \ 'GetAxis':          function('gpt#widget#GetAxis'),
        \ 'SetAxis':          function('gpt#widget#SetAxis'),
        \ 'GetSize':          function('gpt#widget#GetSize'),
        \ 'SetSize':          function('gpt#widget#SetSize'),
        \ 'GetLines':         function('gpt#widget#GetLines'),
        \ 'SetLines':         function('gpt#widget#SetLines'),
        \ 'DeleteLines':      function('gpt#widget#DeleteLines'),
        \ 'GetAutoFocus':     function('gpt#widget#GetAutoFocus'),
        \ 'SetAutoFocus':     function('gpt#widget#SetAutoFocus'),
        \ 'BufAppendLine':    function('gpt#widget#BufAppendLine'),
        \ 'BufAppendLines':   function('gpt#widget#BufAppendLines'),
        \ 'BufAppendString':  function('gpt#widget#BufAppendString'),
        \ 'LineAppendString': function('gpt#widget#LineAppendString'),
        \ }

  " default overridable config.
  " default non overridable config should land in ftplugin
  call w.SetVar("&number", v:false)
  call w.SetVar("&modifiable", v:false)
  call w.SetVar("&relativenumber", v:false)
  call w.SetVar("&buftype", "nofile")
  call w.SetVar("__GPT__", v:true)

  " TODO add function to set opts and vars
  " override
  if has_key(w, "bufopts")
      for [k, v] in items(w["bufopts"])
        call w.SetVar(key, value)
      endfor
  endif

  if has_key(w, "vars")
      for [k, v] in items(w["vars"])
        call w.SetVar(key, value)
      endfor
  endif

  call bufload(w.bufnr)

  if exists('*airline#add_statusline_func') && !exists("g:__vim_gpt_airline_hook_set")
    function! GptAirlineHook(...)
      " TODO: add configuration information ?
      if getbufvar(bufnr('%'), "__GPT__")
        let w:airline_section_a = '%f'
        let w:airline_section_b = ''
        let w:airline_section_c = ''
        " let g:airline_variable_referenced_in_statusline = 'foo'
      endif
    endfunction

    call airline#add_statusline_func('GptAirlineHook')
    let g:__vim_gpt_airline_hook_set = v:true
  endif

  return w

endfunction

function gpt#widget#Map(mode, binding, command) dict
  if !has_key(self.maps, a:mode)
    let self.maps[a:mode] = {}
  endif
  if !has_key(self.maps[a:mode], a:binding)
    let self.maps[a:mode][a:binding] = {}
  endif

  let self.maps[a:mode][a:binding] = a:command
endfunction

function gpt#widget#Hide() dict
  let cur_bnr = bufnr("%")

  let winid = bufwinid(self.bufnr)
  call win_gotoid(winid)

  execute "hide "

  let winid = bufwinid(cur_bnr)
  call win_gotoid(winid)
endfunction

" function gpt#widget#Show() dict
"   lua vim.api.nvim_open_win(0, false, {relative='win', width=12, height=3, bufpos={100,10}})
" endfunciton

function gpt#widget#Show() dict
  let cur_bnr = bufnr("%")

  " let the widget know who launced it
  call self.SetVar("from", cur_bnr)
  let tabpage_buffers = tabpagebuflist()

  if index(tabpage_buffers, self.bufnr) == -1
    if (self.size != -1)
      execute self.GetAxis() .. " "  .. self.size .. "split "
    else
      execute self.GetAxis() .. " "  .. "split "
    endif
    execute "buffer " ..  self.bufnr
    for mode in keys(self.maps)
      for binding in keys(self.maps[mode])
        execute mode .."map <silent> <buffer> " .. binding .. " " .. self.maps[mode][binding]
      endfor
    endfor
  endif

  if self.autofocus
    let winid = bufwinid(self.bufnr)
    call win_gotoid(winid)
  else
    let winid = bufwinid(cur_bnr)
    call win_gotoid(winid)
  endif
endfunction

function gpt#widget#Resize() dict
  let axis = self.GetAxis()
  if axis != "auto"
    execute axis .. ' resize ' .. self.GetSize()
  endif
endfunction

function gpt#widget#GetPos(mark) dict
  " save current buffer
  let cur_bnr = gpt#utils#switchwin(self.bufnr)

  let pos = getpos(a:mark) " set mark '.' to end of buffer

  " go back to original buffer
  let cur_bnr = gpt#utils#switchwin(cur_bnr)

  return pos
endfunction

function gpt#widget#SetPos(mark, pos) dict
  " save current buffer
  let cur_bnr = gpt#utils#switchwin(self.bufnr)

  call setpos(a:mark, a:pos) " set mark '.' to end of buffer

  " go back to original buffer
  let cur_bnr = gpt#utils#switchwin(cur_bnr)

endfunction

function gpt#widget#GetVar(name) dict
  return getbufvar(self.bufnr, a:name)
endfunction

function gpt#widget#SetVar(name, value) dict
  call setbufvar(self.bufnr, a:name, a:value)
endfunction

function gpt#widget#GetLine(pos) abort dict
  return getbufline(self.bufnr, a:pos)[0]
endfunction

function gpt#widget#SetLine(pos, line) abort dict
  call self.SetLines(a:pos, [ a:line ])
endfunction

function gpt#widget#GetAxis() dict

  let vert = winwidth(0) > winheight(0) * 2

  if self.axis == "auto"
    return vert ? "vertical" : "horizontal"
  else
    return self.axis
  endif

endfunction

function gpt#widget#SetAxis(axis) dict
  let self.axis = a:axis
endfunction

function gpt#widget#GetSize() dict
  return self.size
endfunction

function gpt#widget#SetSize(size) dict
  let self.size = a:size
endfunction

function gpt#widget#GetLines(start, end) abort dict
  return getbufline(self.bufnr, a:start, a:end)
endfunction

function gpt#widget#SetLines(pos, lines) abort dict
  call setbufvar(self.bufnr, "&modifiable", v:true)
  call setbufline(self.bufnr, a:pos, a:lines)
  call setbufvar(self.bufnr, "&modifiable", v:false)
endfunction

function gpt#widget#GetAutoFocus(enable) dict
  return self.autofocus
endfunction

function gpt#widget#SetAutoFocus(enable) dict
  let self.autofocus = a:enable
endfunction

function gpt#widget#BufAppendLine(line) abort dict
  call setbufvar(self.bufnr, "&modifiable", v:true)
  call appendbufline(self.bufnr, '$', [a:line])
  call setbufvar(self.bufnr, "&modifiable", v:false)
endfunction

function gpt#widget#BufAppendLines(lines) abort dict
  for line in a:lines
    call self.BufAppendLine(line)
  endfor
endfunction

function gpt#widget#BufAppendString(text) abort dict
  let l:text = split(a:text, '\n', 1)
  call self.BufAppendLines(l:text)
endfunction

function gpt#widget#LineAppendString(pos, string) abort dict
  call self.SetLine(a:pos, self.GetLine(a:pos) .. a:string)
endfunction

function gpt#widget#DeleteLines(start, end) dict
  call self.SetVar("&modifiable", v:true)
  call deletebufline(self.bufnr, 1, '$')
  call self.SetVar("&modifiable", v:false)
endfunction


" vim: ft=vim sw=2 foldmethod=marker foldlevel=0
