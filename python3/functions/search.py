import googlesearch
from duckduckgo_search import DDGS


# hack gpt-3.5 failing to use a dict with a single "code" key
def google(x, query):
    print(f"searching google for {query}.")
    try:
        results = googlesearch.search(query, lang="en", advanced=True)
    except Exception:
        return "Failed getting google results, maybe try duckduckgo ?"
    return "".join(["\n".join([f"{i}. [{result.title}]:({result.url})\n{result.description}\n\n"]) for i, result in enumerate(results)])


google_schema = {
    "name": "search_google",
    "description": "search Google",
    "parameters": {
        "type": "object",
        "properties": {
            "query": {
                "type": "string",
                "description": "query to search"
            }
        },
        "required": ["query"]
    }
}


def duckduckgo(x, query):
    print(f"searching DuckDuckgo for {query}.")
    with DDGS() as ddgs:
        results = list(ddgs.text(query, safesearch='off', timelimit='y'))[:10]
        ret =  "".join(["\n".join([f"{i}. [{result['title']}]:({result['href']})\n{result['body']}\n\n"]) for i, result in enumerate(results)])
        return ret


duckduckgo_schema = {
    "name": "search_duckduckgo",
    "description": "search DuckDuckGo",
    "parameters": {
        "type": "object",
        "properties": {
            "query": {
                "type": "string",
                "description": "query to search"
            }
        },
        "required": ["query"]
    }
}


def register(store):
    store.add_function(google, google_schema)
    store.add_function(duckduckgo, duckduckgo_schema)
