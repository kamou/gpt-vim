import json
import openai
import functions.python as python
import functions.search as search
import functions.web as web
import functions.lua as lua
from functions.function_store import FunctionStore
import tiktoken


class Assistant(object):
    MAX_TOKENS = {
        "gpt-3.5-turbo-16k": 1024*16,
        "gpt-4": 1024*8,
    }

    def __init__(self, context=None, model="gpt-3.5-turbo-16k", memory=0):
        self.history = list()
        self.full_history = list()
        self.model = model
        self.context = context
        self.response = None
        self.memory = memory
        self.func = dict()

        self.fs = FunctionStore()

        lua.register(self.fs)
        python.register(self.fs)
        web.register(self.fs)
        search.register(self.fs)

    def set_current_function_name(self, name):
        self.func["name"] = name
        self.func["arguments"] = ""

    def update_current_function_args(self, args):
        self.func["arguments"] += args

    def get_current_function(self):
        return self.func

    def remaining_tokens(self, max_tokens):
        enc = tiktoken.encoding_for_model(self.model)
        messages = self.history
        tokens = 0

        if self.context:
            messages = [{"role": "system", "content": self.context}] + messages

        for msg in messages:
            tokens += len(enc.encode(msg["content"])) + 4
            if msg["role"] == "assistant":
                tokens += 2
            elif msg["role"] == "system":
                tokens += 3
            elif msg["role"] == "function":
                tokens += 3
        tokens += 5
        return (max_tokens - tokens)

    def send(self, message={}, n=1, **kwargs):
        if message:
            self.history.append(message)
            self.full_history.append(message)

        self.history = self.history[-self.memory:]

        max_tokens = kwargs.get("max_tokens", self.MAX_TOKENS.get(self.model, 4096))

        while (self.remaining_tokens(int(max_tokens)) < 1000):
            del self.history[0]

        remaining_tokens = self.remaining_tokens(int(max_tokens))

        functions = self.fs.schemas()
        enc = tiktoken.encoding_for_model(self.model)
        func_ctx = sum([
                len(enc.encode(json.dumps(function)))
                for function in functions
        ])

        remaining_tokens -= func_ctx

        kwargs["max_tokens"] = int(remaining_tokens/n)

        messages = self.history
        if self.context:
            messages = [
                {"role": "system", "content": self.context}
            ] + messages

        print("caling openai.ChatCompletion.create")
        self.response = openai.ChatCompletion.create(
            functions=self.fs.schemas(),
            messages=messages,
            model=self.model,
            **kwargs
        )
        return self.response

    def user_say(self, message: str, **kwargs):
        return self.send({
                "role": "user",
                "content": message
            }, **kwargs)

    def system_say(self, message: str, **kwargs):
        self.history.append({
                "role": "system",
                "content": message
            }, **kwargs)

    def function_say(self, message: str, name: str, **kwargs):
        return self.send({
                "role": "function",
                "name": name,
                "content": message
            }, **kwargs
        )

    def assistant_say(self, message: str):
        return self.send(role="assistant", content=message)

    # mainly used to store Assistant answers
    def update(self, message: dict):
        self.history.append(message)
        self.full_history.append(message)

    def reset(self):
        self.history = []
        self.full_history = []

    def get_next_chunk(self):
        if not self.response:
            return None

        try:
            return next(self.response)
        except StopIteration:
            return None
