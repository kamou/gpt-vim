import vim
import openai
import json
import tiktoken
from contextlib import contextmanager
openai.api_key = vim.eval("g:gpt_api_key")

class Response(object):
    def __init__(self, resp):
        self.resp = resp

class Session(object):
    def __init__(self, memory: int = 1, context: str | None = None, model: str ="gpt-3.5-turbo"):
        self.memory = memory
        self.history = list()
        self.model = model
        self.context = context

    def remaining_tokens(self, max_tokens):
        enc = tiktoken.encoding_for_model("gpt-3.5-turbo")
        messages = self.history[-self.memory:]
        tokens = 0

        if self.context:
            messages = [{"role": "system", "content": self.context }] + messages

        for msg in messages:
            tokens += len(enc.encode(msg["content"])) + 4
            if msg["role"] == "assistant":
                tokens += 2
        tokens += 5
        return (max_tokens - tokens)


    def send(self, n=1, max_tokens=4096, stream=False, **kwargs):

        if kwargs:
            self.history.append(kwargs)

        while ((remaining_tokens := self.remaining_tokens(max_tokens)) < 1000):
            del self.history[0]

        messages = self.history[-self.memory:]
        if self.context:
            messages = [{"role": "system", "content": self.context }] + messages

        return openai.ChatCompletion.create(
            model=self.model,
            messages=messages,
            n=n,
            stream=stream,
            temperature=0.7,
            max_tokens=int((remaining_tokens)/n)
        )


    def update(self, message):
        self.history.append(message)

class AssistantManager(object):
    def __init__(self):
        self.assistants = dict()

    def create_session(self, id: str, **kwargs):
        if id not in self.assistants:
            self.assistants[id] = Session(**kwargs)
        return self.assistants[id]

class Assistant(object):
    def __init__(self, session=None, **kwargs):
        self.session = session if session else Session(**kwargs)

    def send(self, **kwargs):
        return self.session.send(**kwargs)

    def user_say(self, message: str, **kwargs):
        return self.send(role = "user", content=message, **kwargs)

    def assistant_say(self, message: str):
        return self.send(role = "assistant", content=message)

    # mainly used to store Assistant answers
    def update(self, message: dict):
        self.session.update(message)

AM = AssistantManager()


def GptCreateSession():
    session = vim.eval("l:session")
    context = vim.eval("l:context")
    AM.create_session(session, memory=0, context=context)
    return Assistant(AM.assistants[session])

def create_options():
    options = [
        "temperature [ 1.0 ]",
        "p_penalty   [ 0.0 ]",
        "f_penalty   [ 0.0 ]",
        "stream      [ OFF ]",
    ]
    num_options = len(options) + 1
    vim.command(f"new | resize {num_options}")
    buf = vim.api.get_current_buf()
    buf.options["buftype"] = "nofile"
    buf.options["filetype"] = "gpt"
    buf.options["syntax"] = "markdown"
    vim.api.buf_set_lines(buf, 0, 0, True,  options)

def OpenOptions():
    create_options()

def SaveConversation(session):
    with open(f'{session}_conv.json', 'w') as f:
        json.dump(AM.assistants[session].history, f)


assistant = None
