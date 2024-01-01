import traceback
import vim
import os
import tempfile
import sys
from io import StringIO


def evaluate_code(x, code, description):
    # code = code or kwargs.get("default", '')
    # Redirect stdout to a StringIO object
    stdout = sys.stdout
    # sys.stdout = StringIO()

    # Redirect stderr to a StringIO object
    stderr = sys.stderr
    sys.stderr = StringIO()

    # Create a temporary file for the code
    with tempfile.NamedTemporaryFile(delete=False, suffix=".lua") as temp_code:
        # Write the lua code to the file
        temp_code.write(code.encode())


    # Create another temporary file to write the output
    # Redirect the output of the lua code execution to the file
    temp = tempfile.NamedTemporaryFile(dir='/tmp', delete=True)
    temp_filename = temp.name
    temp.close()
    vim.command(f":redir > {temp_filename}")

    exception_info = None
    try:
        vim.command(f":luafile {temp_code.name}")
    except Exception as e:
        exception_info = str(traceback.format_exc())
    finally:
        _type = "E" if exception_info else "I"
        x["generated"].append((temp_code.name, description, _type))
        items = list()
        for (file, desc, _type) in x["generated"]:
            desc = desc.replace("'", r"\'")
            items.append(f"{{'filename': '{file}', 'text': '{desc}', 'type': '{_type}'}}")
        items = ",".join(items)

    vim.command(f"call setqflist([{items}], 'r')")

    vim.command(f":redir END")

    # Open the output file and read its content
    with open(temp_filename, 'r') as file:
        output = file.read()
        error = sys.stderr.read()

    os.remove(temp_filename)

    # Restore stdout and stderr
    sys.stdout = stdout
    sys.stderr = stderr

    result = f"lua_evaluate_code: Executing Lua Code:\n"
    result += "```lua\n"
    result += code
    result += "\n'''\n"
    if exception_info:
        result += "\n\nlua_evaluate_code: An exception occured during the execution of the code:"
        result += exception_info
    else:
        result += f"\n\nlua_evaluate_code: Execution Finished:\n\n"
    result += f"-----------------\n\n"
    result += "Execution Result:\n"
    result += f"-----------------\n\n"
    result += f"STDOUT:\n{output}\n\n"
    result += f"STDERR:\n{error}\n\n"


    return result


evaluate_code_schema = {
    "name": "lua_evaluate_code",
    "description": "evaluate the provided lua code",
    "parameters": {
        "type": "object",
        "properties": {
            "code": {
                "type": "string",
                "description": "Lua code to evaluate inside neovim"
            },
            "description": {
                "type": "string",
                "description": "Short description of the code to execute"
            }
        },
        "required": ["code", "description"]
    }
}

def register(store):
    store.add_function(evaluate_code, evaluate_code_schema)
