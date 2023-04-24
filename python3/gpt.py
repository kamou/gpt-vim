import os
import vim
import openai
import tiktoken
import sqlite3
import gptdb
import shutil
openai.api_key = vim.eval("g:gpt_api_key")

GPT_TASKS = dict()

# TODO: clean this wild mess
# - a class for the DB
# - a class for TaskManager
# - an interface for vim
# - split in multiple modules




class Assistant(object):
    def __init__(self, context = None, model ="gpt-3.5-turbo"):
        self.history = list()
        self.full_history = list()
        self.model = model
        self.context = context
        self.response = None

    def remaining_tokens(self, max_tokens):
        enc = tiktoken.encoding_for_model("gpt-3.5-turbo")
        messages = self.history
        tokens = 0

        if self.context:
            messages = [{"role": "system", "content": self.context }] + messages

        for msg in messages:
            tokens += len(enc.encode(msg["content"])) + 4
            if msg["role"] == "assistant":
                tokens += 2
            elif msg["role"] == "system":
                tokens += 3
        tokens += 5
        return (max_tokens - tokens)


    def send(self, n=1, max_tokens=4096, stream=False, temperature=0.7, **kwargs):
        if kwargs:
            self.history.append(kwargs)
            self.full_history.append(kwargs)

        while ((remaining_tokens := self.remaining_tokens(int(max_tokens))) < 1000):
            del self.history[0]

        messages = self.history
        if self.context:
            messages = [{"role": "system", "content": self.context }] + messages

        a = [ "False", "True"]
        if stream in a:
            stream = bool(a.index(stream))

        self.response = openai.ChatCompletion.create(
            model=self.model,
            messages=messages,
            n=n,
            stream=stream,
            temperature=float(temperature),
            max_tokens=int((remaining_tokens)/n) - 1
        )
        return self.response

    def user_say(self, message: str, **kwargs):
        return self.send(role = "user", content=message, **kwargs)

    def system_say(self, message: str, **kwargs):
        self.history.append({"role": "system", "content": message})

    def assistant_say(self, message: str):
        return self.send(role = "assistant", content=message)

    # mainly used to store Assistant answers
    def update(self, message: dict):
        self.history.append(message)
        self.full_history.append(message)

    def reset(self):
        self.history = []

    def get_next_chunk(self):
        return next(self.response)


def GptUpdate():
    message = vim.eval("a:message")
    task = GPT_TASKS[vim.eval("self.name")]
    task.update(message)
    open("history.json", "w").write(str(task.history))

def GptReplay():
    task = GPT_TASKS[vim.eval("self.name")]
    task.send()

def GptCreateTask():
    name = vim.eval("self.name")
    GPT_TASKS[vim.eval("self.name")] = Assistant(context=vim.eval("self.context"))

def GptUserSay():
    name = vim.eval("self.name")
    task = GPT_TASKS[vim.eval("self.name")]

    config = vim.eval("self.config")
    for key in config:
        config[key] = vim.eval(f"self.config.{key}")
    config = config if config else {}
    ret = task.user_say(vim.eval("a:message"), **config)
    stream = vim.eval("self.config['stream']")
    if (not stream) or stream == 'False':
        return ret
    else:
        return None

def GptSystemSay():
    name = vim.eval("self.name")
    task = GPT_TASKS[vim.eval("self.name")]

    config = vim.eval("self.config")
    config = config if config else {}

    ret = task.system_say(vim.eval("a:message"), **config)
    if (not vim.eval("self.config['stream']")):
        return ret
    else:
        return None

def GptReset():
    task = GPT_TASKS[vim.eval("self.name")]
    task.reset()

def GptGetNextChunk():
    task = GPT_TASKS[vim.eval("self.name")]
    return task.get_next_chunk()["choices"][0]

def GptSetMessages():
    messages = vim.eval("a:messages")
    task = GPT_TASKS[vim.eval("self.name")]
    task.history = messages
    task.full_history = messages

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
            messages = [ { "role": message[2], "content": message[3] } for message in conv["messages"] ]
            newdb.save(summary, messages)
        shutil.move(path + ".new", path)
        del newdb

def get_version_number(path):
    database_name = os.path.join(path,'history.db')
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
