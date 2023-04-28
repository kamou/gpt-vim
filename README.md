# vim-gpt

This plugin brings chat gpt to Vim and NVim
The purpose of this pugin is to assist you for your various development tasks.

![Demo time !](./uml2rust.gif)

## Current Features

 - Chat with GPT (currently gpt3.5-turbo) in a separate buffer. The output is in markdown.
 - GPT can recall previous messages from the current session.
 - Selected text/code is appended to the prompt.
 - GPT is aware of the language of your current buffer.
 - Multiple sessions. You can save a session and continue the conversation later if needed.

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
:call gpt#Assist(0)<cr>      # Launch the prompt
:'<,'>call gpt#Assist(1)<cr> # Launch the prompt and append the current selection
:call gpt#List()<cr>         # List saved conversations
```

## Default keymapping configuration
```
nmap <silent> gpa <Plug>(gpt-vim-assist)
xmap <silent> gpa <Plug>(gpt-vim-assist-vis)
vmap <silent> gpa <Plug>(gpt-vim-assist-vis)
nmap <silent> gpl <Plug>(gpt-vim-conversations)
```
You may update it in you .vimrc file.

## GPT buffer keys
  - `r` reset current session memory, GPT will forget everything, the buffer will be cleared.
  - `q` close gpt buffer. Memory is kept untouched, gpt will recall previous (most recent) messages.
  - `s` save the current session history.
  - `L` list previously saved sessions (press enter to load selected session).
  - `c` Cancel the current stream. (The answer will be lost, and not saved in the database)
  - `B` Enter Block Mode.

## Block Mode
  - `j` Cycle down to next fenced code block.
  - `k` Cycle up to next fenced code block.
  - `y` Copy current block and leave Block Mode.

## Session list keys
  - `q` close the list
  - `d` delete the session under the cursor
  - `<cr>` select the session under the cursor
  - `s`: Open the conversation under the cursor in a horizontal split.
  - `v`: Open the conversation under the cursor in a vertical split.
