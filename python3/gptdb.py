import os
import sqlite3
class GPTDataBase(object):
    CURRENT_VERSION = 2
    SCHEMA = '''
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
    def __init__(self, path):
        self.path = path
        if not os.path.isfile(path):
            # create the database
            # Connect to the database and create the tables
            connection = sqlite3.connect(path)

            cursor = connection.cursor()
            cursor.executescript(GPTDataBase.SCHEMA)
            replace_query = f"INSERT OR REPLACE INTO version (version) VALUES (?);"
            cursor.execute(replace_query, (GPTDataBase.CURRENT_VERSION,))
            connection.commit()
            connection.close()

        self.connection = sqlite3.connect(path)
        self.cursor = self.connection.cursor()

    def list(self):
        # Check if the conversations table exists
        self.cursor.execute(f"SELECT name FROM sqlite_master WHERE type='table' AND name='conversations';")
        result = self.cursor.fetchone()
        if result is None:
            return []

        select_query = f"SELECT summary FROM conversations;"
        self.cursor.execute(select_query)
        results = self.cursor.fetchall()

        # Extract the summary values from the results
        summaries = [result[0] for result in results]

        summaries = [ f" [{i + 1}] {summary}" for i, summary in enumerate(summaries) ]
        summaries.reverse()
        return summaries

    def save(self, summary, messages):
        insert_query = f"INSERT OR IGNORE INTO conversations (summary) VALUES (?);"
        self.cursor.execute(insert_query, (summary,))
        self.connection.commit()
        for message in messages:
            role = message['role']
            content = message['content']
            insert_query = f"INSERT INTO messages (conversation_summary, role, content) VALUES (?, ?, ?);"
            self.cursor.execute(insert_query, (summary, role, content))
            self.connection.commit()

    def get(self, summary):
        select_query = f"SELECT id, role, content FROM messages WHERE conversation_summary = ?;"
        self.cursor.execute(select_query, (summary,))
        results = self.cursor.fetchall()

        # Create a list of messages from the results
        messages = [{'role': result[1], 'content': result[2]} for result in results]

        return messages

    def delete(self, summary):
        self.cursor.execute(f"DELETE FROM conversations WHERE summary=?", (summary,))
        self.connection.commit()
        self.cursor.execute(f"DELETE FROM messages WHERE conversation_summary=?", (summary,))
        self.connection.commit()

    def get_version(self):
        try:
            self.cursor.execute('SELECT version FROM version')
        except sqlite3.OperationalError:
            return 1

        version_number = self.cursor.fetchone()

        return version_number

    def set_version(self, version_number):
        replace_query = f"INSERT OR REPLACE INTO version (version) VALUES (?);"
        self.cursor.execute(replace_query, (version_number,))
        self.connection.commit()

    def update(self, summary, messages):
        self.delete(summary)
        self.save(summary, messages)

    def extract_v1(self):
        table_name = 'conversations'
        messages_table_name = 'messages'

        # Connect to the database and retrieve the conversations
        self.cursor.execute(f"SELECT * FROM {table_name}")
        conversations = self.cursor.fetchall()

        # Create a dictionary to hold the conversations and their messages
        conversations_dict = list()
        for conversation in conversations:
            conversation_id = conversation[0]
            summary = conversation[1]
            self.cursor.execute(f"SELECT * FROM {messages_table_name} WHERE my_table_id=?", (conversation_id,))
            messages = self.cursor.fetchall()
            conversations_dict.append({'summary': summary, 'messages': messages})

        return conversations_dict


    def __del__(self):
        self.connection.commit()
        self.connection.close()
