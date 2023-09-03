import os
import vim
import openai
import tiktoken
import sqlite3
import gptdb
import shutil
import sys
import json

openai.api_key = vim.eval("g:gpt_api_key")

GPT_TASKS = dict()

# TODO: clean this wild mess
# - a class for the DB
# - a class for TaskManager
# - an interface for vim
# - split in multiple modules




class Assistant(object):
    MAX_TOKENS = {
        "gpt-3.5-turbo-16k": 1024*16,
        "gpt-4": 1024*8,
    }
    def __init__(self, context=None, model="gpt-3.5-turbo-16k"):
        self.history = list()
        self.full_history = list()
        self.model = model
        self.context = context
        self.response = None

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
        kwargs["max_tokens"] = int(remaining_tokens/n)

        messages = self.history
        if self.context:
            messages = [
                {"role": "system", "content": self.context}
            ] + messages

        self.response = openai.ChatCompletion.create(
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

        try: return next(self.response)
        except StopIteration as e: return None

# seems like vim.eva() is not recursively evaluating dictionaries.
# let's fix that here
def get_config(config):
    return json.loads(vim.eval(f"json_encode({config})"))


def GptUpdate():
    message = vim.eval("a:message")
    task = GPT_TASKS[vim.eval("self.name")]
    task.update(message)

def GptReplay():
    name = vim.eval("self.name")
    config = get_config("self.config")
    task = GPT_TASKS[name]
    task.send(**config)


def GptCreateTask():
    name = vim.eval("self.name")
    model = vim.eval("self.model")
    memory = int(vim.eval("self.memory"))

    GPT_TASKS[name] = Assistant(model=model, context=vim.eval("self.context"), memory=memory)


def GptUserSay():
    name = vim.eval("self.name")
    task = GPT_TASKS[name]

    config = get_config("self.config")
    try:
        ret = task.user_say(vim.eval("a:message"), **config)
    except openai.OpenAIError as e:
        return {"error": e.user_message}

    return {} if config.get("stream", False) else ret

def GptSystemSay():
    name = vim.eval("self.name")
    task = GPT_TASKS[name]

    config = get_config("self.config")
    ret = task.system_say(vim.eval("a:message"), **config)

    return None if config.get("stream", False) else ret

def GptReset():
    task = GPT_TASKS[vim.eval("self.name")]
    task.reset()


def GptGetNextChunk():
    task = GPT_TASKS[vim.eval("self.name")]
    chunk = task.get_next_chunk()
    if chunk and len(chunk.get("choices", [])):
        return chunk["choices"][0]
    return None


def GptSetMessages():
    messages = vim.eval("a:messages")
    task = GPT_TASKS[vim.eval("self.name")]
    task.history = messages[:]
    task.full_history = messages[:]


def GptGetMessages():
    task = GPT_TASKS[vim.eval("self.name")]
    return task.full_history


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


def check_and_update_db(path):
    db = gptdb.GPTDataBase(path)
    if os.path.isfile(path) and db.get_version() == 1:
        newdb = gptdb.GPTDataBase(path + ".new")
        print("Updating conversation database to v2")
        conversations = db.extract_v1()
        del db
        os.remove(path)
        for conv in conversations:
            summary = conv["summary"]
            messages = [{
                    "role": message[2],
                    "content": message[3]
                } for message in conv["messages"]
            ]
            newdb.save(summary, messages)
        shutil.move(path + ".new", path)
        del newdb


def get_version_number(path):
    database_name = os.path.join(path, 'history.db')
    conn = sqlite3.connect(database_name)
    cursor = conn.cursor()
    try:
        cursor.execute('SELECT version FROM version')
    except sqlite3.OperationalError:
        return 1

    version_number = cursor.fetchone()
    conn.close()

    return version_number


def GptDBSave():
    path = vim.eval("self.path")
    summary = vim.eval("a:summary")
    messages = vim.eval("a:messages")

    db = gptdb.GPTDataBase(path)
    db.save(summary, messages)


def GptDBUpdate():
    path = vim.eval("self.path")
    summary = vim.eval("a:summary")
    messages = vim.eval("a:messages")

    db = gptdb.GPTDataBase(path)
    db.update(summary, messages)


def GptDBDelete():
    path = vim.eval("self.path")
    summary = vim.eval("a:summary")

    db = gptdb.GPTDataBase(path)
    db.delete(summary)


def GptDBGet():
    path = vim.eval("self.path")
    summary = vim.eval("a:summary")

    db = gptdb.GPTDataBase(path)
    return db.get(summary)


def GptDBList():
    path = vim.eval("self.path")

    db = gptdb.GPTDataBase(path)
    return db.list()


def GptDBGetVers():
    path = vim.eval("self.path")

    db = gptdb.GPTDataBase(path)
    return db.get_version()


def GptDBSetVers():
    path = vim.eval("self.path")
    version = vim.eval("a:version")

    db = gptdb.GPTDataBase(path)
    return db.set_version(version)
