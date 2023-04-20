if !has('python3')
    echomsg ':python3 is not available, gpt will not be loaded.'
    finish
endif

call mkdir(g:gpt#plugin_dir, 'p')

python3 import gpt
