import traceback
import os
import vim
import openai
from openai import RateLimitError
import tiktoken
import sqlite3
import gptdb
import shutil
import json
from functions.function_store import GptException
from assistant import Assistant

GPT_TASKS = dict()

# TODO: clean this wild mess
# - a class for the DB
# - a class for TaskManager
# - an interface for vim
# - split in multiple modules



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
    apikey = vim.eval("g:gpt_api_key")

    GPT_TASKS[name] = Assistant(apikey, model=model, context=vim.eval("self.context"), memory=memory)


def GptUserSay():
    name = vim.eval("self.name")
    task = GPT_TASKS[name]

    config = get_config("self.config")
    try:
        ret = task.user_say(vim.eval("a:message"), **config)
    except RateLimitError as e:
        print(str(e))
        return {"rate": True}
    except openai.OpenAIError as e:
        return {"error": e.user_message}

    return {} if config.get("stream", False) else ret


def GptBuildFunctionCall():
    name = vim.eval("self.name")
    task = GPT_TASKS[name]

    function_call = vim.eval("a:func")
    if "name" in function_call:
        task.set_current_function_name(function_call["name"])
    else:
        task.update_current_function_args(function_call["arguments"])


privdata = { "generated": list() }


def GptDoCall():
    global privdata
    name = vim.eval("self.name")
    task = GPT_TASKS[name]
    config = get_config("self.config")

    function_call = task.get_current_function()
    name = function_call["name"]
    arguments = function_call["arguments"]
    try:
        try:
            task.fs.check_args(name, arguments)
            data = task.fs.call(privdata, name, function_call["arguments"])
        except GptException as e:
            task.function_say(str(e), name, **config)
            return {"data": ""}
        except Exception:
            print(traceback.format_exc())
            return {"error": str(traceback.format_exc())}


        enc = tiktoken.encoding_for_model(task.model)
        size = len(enc.encode(data))
        if size > task.MAX_TOKENS[task.model] / 2:
            task.function_say("Error: result too big", name, **config)
            return {"data": ""}

        task.function_say(data, name, **config)
        return {"result": data}

    except RateLimitError:
        return {"rate": True}


def GptSystemSay():
    name = vim.eval("self.name")
    task = GPT_TASKS[name]

    config = get_config("self.config")
    ret = task.system_say(vim.eval("a:message"), **config)

    return None if config.get("stream", False) else ret


def GptFunctionSay():
    name = vim.eval("self.name")
    task = GPT_TASKS[name]

    config = get_config("self.config")
    func_name = vim.eval("a:func_name")
    message = vim.eval("a:message")
    ret = task.function_say(message, func_name, **config)

    return None if config.get("stream", False) else ret


def GptReset():
    task = GPT_TASKS[vim.eval("self.name")]
    task.reset()


def GptGetNextChunk():
    task = GPT_TASKS[vim.eval("self.name")]
    chunk = task.get_next_chunk()
    if chunk and len(chunk.choices):
        return chunk.choices[0].model_dump(exclude_unset=True)
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
