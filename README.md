# vim-gpt

This plugin brings chat gpt to Vim and NVim
The purpose of this pugin is to assist you for your various development tasks.

![Demo time !](./uml2rust.gif)

## Current Features

 - Chat with GPT (currently gpt3.5-turbo) in a separate buffer. The output is in markdown.
 - GPT can recall previous messages from the current session.
 - Selected text/code is appended to the prompt.
 - GPT is aware of the language of your current buffer.
 - Multiple sessions.

## Requirements

 - an openai [api key](https://platform.openai.com/account/api-keys) (add `g:gpt_api_key` to your config)
 - openai and tiktoken python package
 ```sh
 pip install openai
 pip install tiktoken
 ```

## Installation
```vim
Plug 'kamou/gpt-vim'
```

## Available commands
```
:call gpt#assist([sessionname])             # Launch the prompt
:'<,'>call gpt#visual_assist([sessionname]) # Launch the prompt and append the current selection
```


## Sample keymapping configuration
```
map <silent> <leader><space> :<C-U>call gpt#assist()<cr>
xnoremap <silent> <leader><space> :'<,'>call gpt#visual_assist()<cr>
vnoremap <silent> <leader><space> :'<,'>call gpt#visual_assist()<cr>
```

## GPT buffer keys
  - `r` reset current session memory, GPT will forget everything, the buffer will be cleared
  - `q` close gpt buffer. Memory is kept untouched, gpt will recall previous (most recent) messages.
  - `s` save the current session history in \<sessiontname\>_conv.json
