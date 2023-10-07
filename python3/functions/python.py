import vim
import sys
import io
import traceback
import pydoc
import tempfile


class Environment:
    _instance = None

    def __new__(cls):
        if not cls._instance:
            cls._instance = super(Environment, cls).__new__(cls)
        return cls._instance

    def __init__(self):
        self.stdout = sys.stdout
        self.stderr = sys.stderr
        self.stdout_buffer = io.StringIO()
        self.stderr_buffer = io.StringIO()
        self.namespace = {}

    def execute(self, code, description):
        print(f"exexuting code: {description}")
        # Redirect the standard output and standard error to buffers
        sys.stdout = self.stdout_buffer
        sys.stderr = self.stderr_buffer

        with tempfile.NamedTemporaryFile(delete=True, suffix=".py") as temp_code:
            # Write the lua code to the file
            temp_code.write(code.encode())

        exception_info = None
        try:
            # Execute the code with the stored namespace
            exec(code, self.namespace)
        except Exception:
            # Capture the exception information
            exception_info = str(traceback.format_exc())

        # Restore the standard output and standard error
        sys.stdout = self.stdout
        sys.stderr = self.stderr

        # Get the captured output
        output = self.stdout_buffer.getvalue()
        error = self.stderr_buffer.getvalue()

        # Clear the output buffers
        self.stdout_buffer.truncate(0)
        self.stdout_buffer.seek(0)
        self.stderr_buffer.truncate(0)
        self.stderr_buffer.seek(0)

        # Return the captured output, error, exception information, and namespace
        return output, error, exception_info


env = Environment()


execute_code_schema = {
    "name": "python_execute_code",
    "description": "execute Python code snippet within the Environment, the code keyword is mandatory",
    "parameters": {
        "type": "object",
        "properties": {
            "code": {
                "type": "string",
                "description": "Python code to execute"
            },
            "description": {
                "type": "string",
                "description": "Short description of the code to execute"
            }
        },
        "required": ["code", "description"]
    }
}


def execute_code(x, code, description):

    try:
        output, error, exception_info = env.execute(code, description)
        _type = 'I'
    except Exception as e:
        _type = 'E'
        raise e
    finally:

        result = "python_execute_code: Executing Python Code:\n"
        result += "```python\n"
        result += code
        result += "\n```\n"
        if exception_info:
            result += "\n\npython_execute_code: An exception occured during the execution of the code:"
            result += exception_info
        else:
            result += "\n\npython_execute_code: Execution Finished:\n\n"
        result += "\n\n-----------------\n\n"
        result += "Execution Result:\n"
        result += "-----------------\n\n"
        result += f"STDOUT:\n{output}\n\n"
        result += f"STDERR:\n{error}\n\n"
        if not exception_info:
            result += "Execution succesfully finished with no exception"

        with tempfile.NamedTemporaryFile(delete=False, suffix=".py") as temp_code:
            temp_code.write(code.encode() + b"\n")
            for line in result.split("\n"):
                temp_code.write(f"# {line}\n".encode())

            x["generated"].append((temp_code.name, description, _type))
            items = list()
            for (file, desc, _type) in x["generated"]:
                desc = desc.replace("'", r"\'")
                items.append(f"{{'filename': '{file}', 'text': '{desc}', 'type': '{_type}'}}")
            items = ",".join(items)
            vim.command(f"call setqflist([{items}], 'r')")

    return result


pydoc_help_schema = {
    "name": "python_pydoc_help",
    "description": "Print the help page for a given Python module, function, class, or method.",
    "parameters": {
        "type": "object",
        "properties": {
            "name": {
                "type": "string",
                "description": "The name of the Python module, function, class, or method to print the help page for."
            }
        },
        "required": ["code"]
    }
}

# hack gpt-3.5 failing to use a dict with a single "code" key
def pydoc_help(x, name):
    try:
        return str(pydoc.render_doc(name, renderer=pydoc.plaintext))
    except Exception:
        # Capture the exception information
        return str(traceback.format_exc())


def register(store):
    store.add_function(execute_code, execute_code_schema)
    # weird, to execute python code, gpt will almost always use the`python`
    # function  even if it is not described in any schema... overfitting ?
    store.set_alias("python_execute_code", "python")
    store.add_function(pydoc_help, pydoc_help_schema)
