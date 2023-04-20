
import vim
import openai
openai.api_key = vim.g.gpt_api_key

def get_function_span():
    try:
      return vim.call("GetFunctionSpan")
    except:
      return None

def extractcode(span):
    start_row = span["start"][0]
    start_col = span["start"][1]
    end_row = span["end"][0]
    end_col = span["end"][1]

    return vim.current.buffer[start_row-1:end_row+1]

def _GptAssist():
    openai.api_key = vim.g.gpt_api_key
    func_code = extractcode(get_function_span())
    if not func_code:
      return ""
    response = openai.ChatCompletion.create(model="gpt-3.5-turbo",
        messages=[
            {
                'role': 'system',
                'content' : """
                You are a code assistant.
                Your role is to complete and/or modify provided functions.
                The user will provie you a function, with comments requesting for changes.
                All requests are preceded with "ASSISTANT:"
                You only answer with the new code.
                """
            },
            {
                'role': 'user',
                'content' : str(func_code),
            },
            {
                 'role': 'assistant',
                 'content' : "// First, let's think step by step."
            },
        ]
    )
    return (response["choices"][0]["message"]["content"].split("\n"))

def _GptImprove():
    func_code = extractcode(get_function_span())
    if not func_code:
      return ""
    response = openai.ChatCompletion.create(model="gpt-3.5-turbo",
        messages=[
            {
                'role': 'system',
                'content' : """
                You are a code improvement tool.
                The user will provie you a function, and you will improve it for size, readability, safety, and if applicable for performance, try to make use of standard apis when possible.
                You only answer with improved code, no extra explanations, no text, no backticks or any formatting tags around the code, just the code.
                """
            },
            {
                'role': 'user',
                'content' : str(func_code),
            },
            {
                 'role': 'assistant',
                 'content' : "// First, let's think step by step."
            },
        ]
    )
      # messages=[
      #     {
      #         'role': 'system',
      #         'content' : """
      #         You are a code improvement tool.
      #         The user will provie you with a function, and you will improve it for size, readability, safety, and if applicable for performance, try to make use of standard apis when possible.
      #         First, describe what the code does.
      #         Then, provide the different steps of improvement.
      #         Only provide compilable answers, all reasoning and explanations should be commented out. Never provide non code text outside of comments.
      #         Always provide the improved version of the code after the code explanation and improvement reasoning.
      #         """
      #     },
      #     {
      #         'role': 'user',
      #         'content' : str(func_code)
      #     },
      #     {
      #         'role': 'assistant',
      #         'content' : "// First, let's think step by step."
      #     }
      # ]


    return (response["choices"][0]["message"]["content"].split("\n"))

def GptAssist():
    lang = vim.api.buf_get_option(vim.api.get_current_buf().number, 'filetype')
    text = _GptAssist()
    if not text:
      return ""

    ui = vim.api.list_uis()[0]
    maxw = ui['width'] / 2

    height = len(text)
    width = 0
    for line in text:
      if len(line) > width:
        width = len(line)



    gpt_buf = vim.api.create_buf(False, True)
    gpt_buf.options["filetype"] = lang
    # vim.api.buf_set_text(gpt_buf, current_row, start_col, current_row, end_col, [line])
    vim.api.buf_set_text(gpt_buf, 0, 0, 0, 0, text)


    if width > ui['width'] / 2:
      width = ui['width'] / 2

    if height > ui['height'] / 2:
      height = ui['height'] / 2

    opts = {
      'relative': 'editor',
      'width': int(width),
      'height': int(height),
      'col': (ui['width']/2) - (width/2),
      'row': (ui['height']/2) - (height/2),
      'anchor': 'NW',
      'style': 'minimal',
      # 'wrap': True,
    }
    vim.api.open_win(gpt_buf.number, 1, opts)
def GptImprove():
    lang = vim.api.buf_get_option(vim.api.get_current_buf().number, 'filetype')
    text = _GptImprove()

    ui = vim.api.list_uis()[0]
    maxw = ui['width'] / 2

    height = len(text)
    width = 0
    for line in text:
      if len(line) > width:
        width = len(line)



    gpt_buf = vim.api.create_buf(False, True)
    gpt_buf.options["filetype"] = lang
    # vim.api.buf_set_text(gpt_buf, current_row, start_col, current_row, end_col, [line])
    vim.api.buf_set_text(gpt_buf, 0, 0, 0, 0, text)


    if width > ui['width'] / 2:
      width = ui['width'] / 2

    if height > ui['height'] / 2:
      height = ui['height'] / 2

    opts = {
      'relative': 'editor',
      'width': int(width),
      'height': int(height),
      'col': (ui['width']/2) - (width/2),
      'row': (ui['height']/2) - (height/2),
      'anchor': 'NW',
      'style': 'minimal',
      # 'wrap': True,
    }
    vim.api.open_win(gpt_buf.number, 1, opts)

def GptImproveInline(text):
  pass


def GptExplain():
    func_code = extractcode(get_function_span())
    if not func_code:
      return ""
    ui = vim.api.list_uis()[0]
    maxw = ui['width'] / 2
    response = openai.ChatCompletion.create(model="gpt-3.5-turbo",
        messages=[
            {
                'role': 'system',
                'content' : """
                You are a code analysis tool and never leave that role.
                All your answers should always be formatted in Markdown.
                The user will provide you a function, and you will help them understand what the function does.
                Extract relevant snippets of code to explain them in detail.
                Also provide ideas on how to improve the function (or the extracted snippets) for readability, for safety, and if applicable for performance.
                Provide the improved function with comments hightlighting the updates""",
            },
            {
                'role': 'user',
                'content' : str(func_code)
            }
        ]
    )


    retval = (response["choices"][0]["message"]["content"].split("\n"))

    height = len(retval)
    width = 0
    for line in retval:
      if len(line) > width:
        width = len(line)



    gpt_buf = vim.api.create_buf(False, True)
    gpt_buf.options["filetype"] = "cpp"
    # vim.api.buf_set_text(gpt_buf, current_row, start_col, current_row, end_col, [line])
    vim.api.buf_set_text(gpt_buf, 0, 0, 0, 0, retval)


    if width > ui['width'] / 2:
      width = ui['width'] / 2

    if height > ui['height'] / 2:
      height = ui['height'] / 2

    opts = {
      'relative': 'editor',
      'width': int(width),
      'height': int(height),
      'col': (ui['width']/2) - (width/2),
      'row': (ui['height']/2) - (height/2),
      'anchor': 'NW',
      'style': 'minimal',
      # 'wrap': True,
    }
    vim.api.open_win(gpt_buf.number, 1, opts)

# vim.api.create_user_command("GptAssist", ":py3 GptAssist()", {})
# vim.api.create_user_command("GptImprove", ":py3 GptImprove()", {})
# vim.api.create_user_command("GptExplain", ":py3 GptExplain()", {})
