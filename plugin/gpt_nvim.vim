if !has('python3')
    echomsg ':python3 is not available, gpt-nvim will not be loaded.'
    finish
endif

lua require "func_span"

python3 import gpt_nvim.gpt
python3 GptAssist = gpt_nvim.gpt.GptAssist

command! GptAssist python3 GptAssist()
