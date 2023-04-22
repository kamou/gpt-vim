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
  let g:__GPTVIMWidgets__[a:name] = w
  call extend({"gpt": ["GPT Chat", ""]}, get(g:, 'airline_filetype_overrides', {}), 'force')

  if exists('*airline#add_statusline_func')
    function GptAirlineHook(...)
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

  return w

endfunction


function gpt#widget#construct(w)
  let self = a:w
  " autofocus by default
  let self.autofocus = v:true

  function self.configure_axis(axis, ...)
    " -1 means half
    let self["size"] = get(a:, 1, -1)
    let self["axis"] = a:axis
    return self
  endfunction

  function self.get_axis()

    let vert = winwidth(0) > winheight(0) * 2

    if self.axis == "auto"
      return vert ? "vertical" : "horizontal"
    else
      return self.axis
    endif

  endfunction

  function self.resize()
    if self.get_axis() != "auto"
      execute self.get_axis() .. ' resize ' .. self.size
    endif
  endfunction

  function self.set_autofocus(enable)
    let self.autofocus = a:enable
  endfunction

  function self.show()
    let tabpage_buffers = tabpagebuflist()

    if index(tabpage_buffers, self.bufnr) == -1
      execute self.get_axis() .. " split " ..  bufname(self.bufnr)
      call self.resize()
    endif

    if self.autofocus
      let winid = bufwinid(self.bufnr)
      call win_gotoid(winid)
    endif
  endfunction

  function self.imap()
  endfunction

  function self.nmap()
  endfunction

  function self.vmap()
  endfunction

  function self.unmap()
  endfunction

  return self
endfunction

" vim: ft=vim sw=2 foldmethod=marker foldlevel=0
