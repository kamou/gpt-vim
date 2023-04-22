let g:__GPTVIMWidgets__ = {}

function gpt#widget#get(name)abort
  if g:__GPTVIMWidgets__->has_key(a:name)
    return g:__GPTVIMWidgets__[a:name]
  endif

  return v:null
endfunction

function gpt#widget#GenericWidget(name, ...) abort
  let w = {}

  let bnr = bufnr("GPT " .. a:name)
  if (bnr >= 0)
    throw "A Buffer named GPT " .. a:name .. " already exists"
  endif

  let bnr = bufadd("GPT " .. a:name)

  " default overridable config.
  " default non overridable config should land in ftplugin
  call setbufvar(bnr, "&number", v:false)
  call setbufvar(bnr, "&modifiable", v:false)
  call setbufvar(bnr, "&relativenumber", v:false)
  call setbufvar(bnr, "&buftype", "nofile")
  call setbufvar(bnr, "__GPT__", v:true)

  " TODO add function to set opts and vars
  " override
  if has_key(w, "bufopts")
      for [k, v] in items(w["bufopts"])
        call setbufvar(bnr,  key, value)
      endfor
  endif

  if has_key(w, "vars")
      for [k, v] in items(w["vars"])
        call setbufvar(bnr, key, value)
      endfor
  endif

  call bufload(bnr)
  let w["bufnr"] = bnr

  let w = gpt#widget#construct(w)

  if exists('*airline#add_statusline_func') && !len(g:__GPTVIMWidgets__)
    function! GptAirlineHook(...)
      " TODO: add configuration information ?
      if &filetype =~ '^gpt'
        let w:airline_section_a = '%f'
        let w:airline_section_b = ''
        let w:airline_section_c = ''
        " let g:airline_variable_referenced_in_statusline = 'foo'
      endif
    endfunction

    call airline#add_statusline_func('GptAirlineHook')
  endif

  let g:__GPTVIMWidgets__[a:name] = w

  return w

endfunction


function gpt#widget#construct(widget) abort
  let widget = a:widget
  " autofocus by default
  let widget["autofocus"] = v:true

  function widget.configure_axis(axis, ...)
    " -1 means half
    let self["size"] = get(a:, 1, -1)
    let self["axis"] = a:axis
    return self
  endfunction

  function widget.get_axis()

    let vert = winwidth(0) > winheight(0) * 2

    if self.axis == "auto"
      return vert ? "vertical" : "horizontal"
    else
      return self.axis
    endif

  endfunction

  function widget.resize()
    if self.get_axis() != "auto"
      execute self.get_axis() .. ' resize ' .. self.size
    endif
  endfunction

  function widget.set_autofocus(enable)
    let self.autofocus = a:enable
  endfunction

  function widget.show()
    let cur_bnr = bufnr("%")
    let tabpage_buffers = tabpagebuflist()

    if index(tabpage_buffers, self.bufnr) == -1
      execute self.get_axis() .. " split " ..  bufname(self.bufnr)
      call self.resize()
    endif

    if !self.autofocus
      let winid = bufwinid(cur_bnr)
      call win_gotoid(winid)
    endif
  endfunction

  function widget.buf_append_line(line) abort
    call setbufvar(self.bufnr, "&modifiable", v:true)
    call appendbufline(self.bufnr, '$', [a:line])
    call setbufvar(self.bufnr, "&modifiable", v:false)
  endfunction

  function widget.buf_append_lines(lines) abort
    for line in a:lines
      call self.buf_append_line(line)
    endfor
  endfunction

  function widget.buf_append_text(text) abort
    let l:text = split(a:text, '\n', 1)
    call self.buf_append_lines(l:text)
  endfunction

  function widget.get_line(pos) abort
    return getbufline(self.bufnr, a:pos)[0]
  endfunction

  function widget.get_lines(start, end) abort
    return getbufline(self.bufnr, a:start, a:end)
  endfunction

  function widget.set_line(pos, line) abort
    call setbufvar(self.bufnr, "&modifiable", v:true)
    call setbufline(self.bufnr, a:pos, [ a:line ])
    " call setbufline(Wchat.bufnr, '$', getbufline(Wchat.bufnr, '$')[0] . l:content[0])
    call setbufvar(self.bufnr, "&modifiable", v:false)
  endfunction

  function widget.set_lines(pos, lines) abort
    call setbufvar(self.bufnr, "&modifiable", v:true)
    call setbufline(self.bufnr, a:pos, a:lines)
    " call setbufline(Wchat.bufnr, '$', getbufline(Wchat.bufnr, '$')[0] . l:content[0])
    call setbufvar(self.bufnr, "&modifiable", v:false)
  endfunction

  function widget.line_append_string(pos, line) abort
    call self.set_line(a:pos, self.get_line(a:pos) .. a:line)
  endfunction

  function widget.hide() abort
    execute "hide " ..  "\"" .. bufname(self.bufnr) .. "\""
  endfunction

  function widget.getpos(mark)
    " save current buffer
    let cur_bnr = gpt#utils#switchwin(self.bufnr)

    let pos = getpos(a:mark) " set mark '.' to end of buffer

    " go back to original buffer
    let cur_bnr = gpt#utils#switchwin(cur_bnr)

    return pos
  endfunction

  function widget.setvar(name, value)
    call setbufvar(self.bufnr, a:name, a:value)
  endfunction

  function widget.getvar(name)
    return getbufvar(self.bufnr, a:name)
  endfunction

  return widget
endfunction

" vim: ft=vim sw=2 foldmethod=marker foldlevel=0
