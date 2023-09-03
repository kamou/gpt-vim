import requests
from bs4 import BeautifulSoup
import wikipedia


def download_file(_, url, dest):
    print(f"Downloading file {url} to {dest}")
    response = requests.get(url)
    if response.status_code == 200:
        with open(dest, "bw") as f:
            f.write(response.content)
        return "Successfully to downloaded file to " + dest
    else:
        return f"Failed to download file from {url} with status code {response.status_code}"


download_file_schema = {
    "name": "download_file",
    "description": "Download and read unicode/ascii text file from provided url",
    "parameters": {
        "type": "object",
        "properties": {
            "url": {
                "type": "string",
                "description": "url of the file to download",
            },
            "dest": {
                "type": "string",
                "description": "destination path to save the file to",
            }
        },
        "required": ["url", "dest"]
    }
}


def open_url(_, url):
    print(f"Reading {url}")
    try:
        response = requests.get(url, headers={'User-agent': 'smart-bot 1.0'}, timeout=1)
    except Exception as e:
        return "Failed to read" + url + " with error: " + str(e)

    soup = BeautifulSoup(response.content, 'html.parser')
    paragraphs = soup.find_all(['href', 'p', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6'])
    paragraph_texts = ["> " + p.get_text() for p in paragraphs]
    return "\n".join(paragraph_texts) + "\n\n"


open_url_schema = {
    "name": "web_open_url",
    "description": "open provide url and read its content",
    "parameters": {
        "type": "object",
        "properties": {
            "url": {
                "type": "string",
                "description": "url to read"
            }
        },
        "required": ["url"]
    }
}


def get_wikipedia_summary(_, subject):
    print(f"Searching Wikipedia for {subject}")
    try:
        result = wikipedia.summary(subject)
        return f"Summary for {subject}\n\n" + result + "\n\n"
    except wikipedia.exceptions.DisambiguationError as e:
        options = e.options[:5]  # Get the first 5 suggestions
        return f"Multiple options found, please specify: {options}"
    except Exception as e:
        return f"An error occurred: {str(e)}"


get_wikipedia_summary_schema = {
    "name": "web_get_wikipedia_summary",
    "description": "get a summary of a wikipedia page",
    "parameters": {
        "type": "object",
        "properties": {
            "subject": {
                "type": "string",
                "description": "subject of the wikipedia page"
            }
        },
        "required": ["subject"]
    }
}


def register(store):
    store.add_function(get_wikipedia_summary, get_wikipedia_summary_schema)
    store.add_function(open_url, open_url_schema)
    store.add_function(download_file, download_file_schema)
