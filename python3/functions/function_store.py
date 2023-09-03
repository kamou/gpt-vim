import inspect
import json
import traceback


class GptException(Exception):
    def __init__(self, message):
        self.message = message
        super().__init__(self.message)


class FunctionStore:
    def __init__(self):
        self.funcs = dict()

    def add_function(self, function, schema):
        for k in ("name", "description", "parameters"):
            if (k not in schema):
                raise GptException(f"function schema should contain a {k} field")

        name = schema["name"]
        params = schema["parameters"]

        for k in ("type", "properties"):
            if (k not in params):
                raise GptException(f"function schema parameters should contain a {k} filed")

        sig = inspect.signature(function)
        parameters = set(list(sig.parameters)[1:])
        properties = set(params["properties"])

        if parameters != properties:
            message = f"Invalid schema detected, the provided schema does not match {name} signature:\n"
            message += f"expected {name}({', '.join(parameters)})"
            message += f"got {name}({', '.join(properties)})"
            raise GptException(message)

        schema["function"] = function
        self.funcs[name] = schema

    def call(self, x,  name, params):
        params = json.loads(params)
        if name not in self.funcs:
            for k, v  in self.funcs.items():
                if "alias" in v and name == v["alias"]:
                    name = k
                    break
        return self.funcs[name]["function"](x, **params)

    def schemas(self):
        return [{key: value for key, value in schema.items() if key != "function"} for schema in self.funcs.values()]

    def check_args(self, name, args):
        orig_name = name
        if name not in self.funcs:
            for k, v  in self.funcs.items():
                if "alias" in v and name == v["alias"]:
                    name = k
                    break

        try:
            args = json.loads(args)
        except Exception as e:
            message = f"Invalid function call detected, the provided parameters are not valid json\n"
            message += f"the `{orig_name}` function expects the following parameters:\n"
            expected_args = set(list(inspect.signature(self.funcs[name]["function"]).parameters)[1:])
            message += "\n".join(expected_args)
            message += "\n\n"
            raise GptException(message)

        if name not in self.funcs:
            message = f"Invalid function name detected ({name}), the provided function name does not match any registered function:\n"
            message += "\n".join(self.funcs.keys())
            raise GptException(message)


        expected_args = set(list(inspect.signature(self.funcs[name]["function"]).parameters)[1:])
        args = set(args)
        if args != expected_args:
            message = f"Invalid function signagure detected, the provided parameters list does not match {name} signature:\n"
            message += f"expected {name}({', '.join(expected_args)})"
            message += f"got {name}({', '.join(args)})"
            raise GptException(message)

    def set_alias(self, function, alias):
        self.funcs[function]["alias"] = alias


