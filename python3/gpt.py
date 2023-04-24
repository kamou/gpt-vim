import os
import vim
import openai
import tiktoken
import sqlite3
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
    global assistant
    message = vim.eval("a:message")
    task = GPT_TASKS[vim.eval("self.name")]
    task.update(message)
    open("history.json", "w").write(str(task.history))

def GptReplay():
    global assistant
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
    if (not vim.eval("self.config['stream']")):
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

def get_summary_list(path):
    database_name = os.path.join(path,'history.db')
    table_name = 'conversations'
    connection = sqlite3.connect(database_name)
    connection.execute("PRAGMA foreign_keys = 1")

    cursor = connection.cursor()

    # Check if the conversations table exists
    cursor.execute(f"SELECT name FROM sqlite_master WHERE type='table' AND name='{table_name}';")
    result = cursor.fetchone()
    if result is None:
        return []

    select_query = f"SELECT summary FROM {table_name};"
    cursor.execute(select_query)
    results = cursor.fetchall()

    # Extract the summary values from the results
    summaries = [result[0] for result in results]

    connection.close()
    summaries = [ f" [{i + 1}] {summary}" for i, summary in enumerate(summaries) ]
    summaries.reverse()
    return summaries

def set_conversation(path, summary):
    global assistant
    conv = get_conversation(path, summary)
    conv = [ { "role": msg["role"], "content": msg["content"] } for msg in conv ]
    GPT_TASKS["Chat"].full_history = conv

def gen_summary():
    assist = Assistant(context="in no more than five words, provide a meaningful description of the topic for the following conversation.")

    messages = [ f"{message['role']}:\n\n {message['content']}\n\n" for message in GPT_TASKS["Chat"].full_history if message["role"] != "system"] 

    messages = "==========".join(messages)
    response = assist.user_say(messages + "\n\ndescribe the main topic of this conversation in 5 words")
    return response["choices"][0]["message"]["content"]


def get_conversation(path, summary):
    # Define the database name and table names
    database_name = os.path.join(path, 'history.db')
    messages_table_name = 'messages'

    # Connect to the database and execute the query
    connection = sqlite3.connect(database_name)
    connection.execute("PRAGMA foreign_keys = 1")

    cursor = connection.cursor()
    select_query = f"SELECT id, role, content FROM {messages_table_name} WHERE conversation_summary = ?;"
    cursor.execute(select_query, (summary,))
    results = cursor.fetchall()

    # Create a list of messages from the results
    messages = [{'id': result[0], 'role': result[1], 'content': result[2]} for result in results]

    # Close the database connection
    connection.close()

    return messages

def replace_conversation(summary, path):
    # Define the database name and table names
    database_name = os.path.join(path,'history.db')
    messages_table_name = 'messages'

    # Define the schema for the tables
    schema = '''
    CREATE TABLE IF NOT EXISTS conversations (
        summary TEXT PRIMARY KEY
    );

    CREATE TABLE IF NOT EXISTS messages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        conversation_summary TEXT,
        role TEXT,
        content TEXT,
        FOREIGN KEY (conversation_summary) REFERENCES conversations(summary) ON DELETE CASCADE
    );

    CREATE TABLE IF NOT EXISTS version (
        version INTEGER PRIMARY KEY NOT NULL DEFAULT 2
    );
    '''
    message = GPT_TASKS["Chat"].full_history

    # Connect to the database and create the tables
    connection = sqlite3.connect(database_name)
    connection.execute("PRAGMA foreign_keys = 1")

    cursor = connection.cursor()
    cursor.executescript(schema)
    connection.commit()

    # Remove all messages for the conversation
    cursor.execute(f"DELETE FROM {messages_table_name} WHERE conversation_summary=?", (summary,))
    connection.commit()

    # Insert the new messages
    messages = GPT_TASKS["Chat"].full_history
    for message in messages:
        role = message['role']
        content = message['content']
        insert_query = f"INSERT INTO {messages_table_name} (conversation_summary, role, content) VALUES (?, ?, ?);"
        cursor.execute(insert_query, (summary, role, content))
        connection.commit()

    # Close the database connection
    connection.close()

def delete_conversation(path, summary):
    # Define the database name and table names
    database_name = os.path.join(path,'history.db')
    table_name = 'conversations'
    messages_table_name = 'messages'

    # Connect to the database and delete the conversation and its messages
    connection = sqlite3.connect(database_name)
    connection.execute("PRAGMA foreign_keys = 1")

    cursor = connection.cursor()
    cursor.execute(f"DELETE FROM {table_name} WHERE summary=?", (summary,))
    connection.commit()
    cursor.execute(f"DELETE FROM {messages_table_name} WHERE conversation_summary=?", (summary,))
    connection.commit()

    # Close the database connection
    connection.close()


def save_conversation(path, summary=None, messages=None):
    database_name = os.path.join(path,'history.db')
    # Define the database name and table names
    table_name = 'conversations'
    messages_table_name = 'messages'

    # Define the schema for the tables
    schema = '''
    CREATE TABLE IF NOT EXISTS conversations (
        summary TEXT PRIMARY KEY
    );

    CREATE TABLE IF NOT EXISTS messages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        conversation_summary TEXT,
        role TEXT,
        content TEXT,
        FOREIGN KEY (conversation_summary) REFERENCES conversations(summary) ON DELETE CASCADE
    );

    CREATE TABLE IF NOT EXISTS version (
        version INTEGER PRIMARY KEY NOT NULL DEFAULT 2
    );

    '''
    if not summary:
        summary = gen_summary().strip()

    if not messages:
        messages = GPT_TASKS["Chat"].full_history

    # Connect to the database and create the tables
    connection = sqlite3.connect(database_name)
    connection.execute("PRAGMA foreign_keys = 1")

    cursor = connection.cursor()
    cursor.executescript(schema)
    connection.commit()

    insert_query = f"INSERT OR IGNORE INTO {table_name} (summary) VALUES (?);"
    cursor.execute(insert_query, (summary,))
    connection.commit()
    for message in messages:
        role = message['role']
        content = message['content']
        insert_query = f"INSERT INTO {messages_table_name} (conversation_summary, role, content) VALUES (?, ?, ?);"
        cursor.execute(insert_query, (summary, role, content))
        connection.commit()

    replace_query = f"INSERT OR REPLACE INTO version (version) VALUES (?);"
    cursor.execute(replace_query, (2,))
    connection.close()


def check_and_update_db(path):
    database_name = os.path.join(path,'history.db')
    if os.path.isfile(database_name) and get_version_number(path) == 1:
        print("Updating conversation database to v2")
        conversations = extract_conversations_v1(path)
        os.remove(database_name)
        for conv in conversations:
            summary = conv["summary"]
            messages = [ { "role": message[2], "content": message[3] } for message in conv["messages"] ]
            save_conversation(path, summary, messages)
        set_version_number(path, 2)

def get_version_number(path):
    database_name = os.path.join(path,'history.db')
    conn = sqlite3.connect(database_name)
    cursor = conn.cursor()
    try:
        cursor.execute('SELECT version FROM version')
    except sqlite3.OperationalError as e:
        return 1

    version_number = cursor.fetchone()[0]
    conn.close()

    return version_number

def set_version_number(path, version_number):
    database_name = os.path.join(path, 'history.db')
    conn = sqlite3.connect(database_name)
    cursor = conn.cursor()
    replace_query = f"INSERT OR REPLACE INTO version (version) VALUES (?);"
    cursor.execute(replace_query, (version_number,))
    conn.commit()
    conn.close()

def extract_conversations_v1(path):
    database_name = os.path.join(path,'history.db')
    # Define the database name and table names
    table_name = 'conversations'
    messages_table_name = 'messages'

    # Connect to the database and retrieve the conversations
    connection = sqlite3.connect(database_name)
    cursor = connection.cursor()
    cursor.execute(f"SELECT * FROM {table_name}")
    conversations = cursor.fetchall()

    # Create a dictionary to hold the conversations and their messages
    conversations_dict = list()
    for conversation in conversations:
        conversation_id = conversation[0]
        summary = conversation[1]
        cursor.execute(f"SELECT * FROM {messages_table_name} WHERE my_table_id=?", (conversation_id,))
        messages = cursor.fetchall()
        conversations_dict.append({'summary': summary, 'messages': messages})

    connection.close()
    return conversations_dict


