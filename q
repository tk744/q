#!/usr/bin/env python3

# standard library imports
import base64
import getpass
import json
import os
import re
import string
import sys
from typing import Any, Dict, List, Tuple

# third-party imports
import openai
import pyperclip
from colorama import just_fix_windows_console
from termcolor import colored, cprint

# versioning
VERSION = 'v1.2.0'

# command parameters
DEFAULT_CODE = 'Python'      # default language for code generation
DEFAULT_SHELL = 'Linux Bash' # default system for shell command generation

# model variants
MINI_LLM = 'gpt-4.1-mini'    # cheap and fast
FULL_LLM = 'gpt-4.1'         # expensive and more powerful

# model token limits
TOKEN_LIMIT = 512            # default token limit
LONG_TOKEN_LIMIT = 2048      # token limit for long response generation

# model parameters
DEFAULT_MODEL_ARGS = {
    'model': MINI_LLM,
    'max_output_tokens': TOKEN_LIMIT,
    'temperature': 0.0
}

# program resources
RESOURCE_PATH = os.path.join(os.path.expanduser('~'), '.q', 'resources.json')
os.makedirs(os.path.dirname(RESOURCE_PATH), exist_ok=True)

def _load_resource(name: str, default: Any) -> Any:
    try:
        with open(RESOURCE_PATH) as f:
            return json.load(f)[name]
    except:
        return default
    
def _save_resource(name: str, value: Any):
    try:
        with open(RESOURCE_PATH) as f:
            resources = json.load(f)
    except:
        resources = {}
    resources[name] = value
    with open(RESOURCE_PATH, 'w') as f:
        json.dump(resources, f, indent=4)

COMMANDS = [
    {
        'flags': [],
        'description': 'follow-up on the previous response',
        'clip_output': _load_resource('clip_output', False),
        'model_args': _load_resource('model_args', {}),
        'messages': _load_resource('messages', []) + [
            {
                'role': 'user',
                'content': '{text}'
            }
        ]
    },
    {
        'flags': ['-p', '--prompt'],
        'description': 'prompt a regular language model',
        'model_args': {
            'model': FULL_LLM,
            'temperature': 0.25,
        },
        'messages': [
            { 
                'role': 'developer', 
                'content': 'You are a helpful and knowledgeable AI assistant.'
            },
            {
                'role': 'user',
                'content': '{text}'
            }
        ]
    },
    {
        'flags': ['-c', '--code'],
        'description': f'generate a code snippet (default {DEFAULT_CODE})',
        'clip_output': True,
        'model_args': {
            'model': FULL_LLM,
        },
        'messages': [
            { 
                'role': 'developer', 
                'content': f'You are a coding assistant. Given a natural language description, generate a code snippet that accomplishes the requested task. The code should be correct, efficient, concise, and idiomatic. Respond with only the code snippet, without explanations, additional text, or formatting. Assume the programming language is {DEFAULT_CODE} unless otherwise specified.'
            },
            {
                'role': 'user',
                'content': 'Generate a code snippet to accomplish the following task: {text}. Respond only with the code, without explanation or additional text.'
            }
        ]
    },
    {
        'flags': ['-s', '--shell'],
        'description': f'generate a shell command (default {DEFAULT_SHELL})',
        'clip_output': True,
        'messages': [
            { 
                'role': 'developer', 
                'content': f'You are a command-line assistant. Given a natural language task description, generate the simplest single shell command that accomplishes the task. Favor minimal, commonly available commands with no extra formatting or piping. Avoid commands that could delete, overwrite, or modify important files or system settings (e.g., rm -rf, dd, mkfs, chmod -R, chown, kill -9). Respond with only the command, without explanations, additional text, or formatting. Assume a {DEFAULT_SHELL} shell unless otherwise specified.'
            },
            {
                'role': 'user',
                'content': 'Generate a single shell command to accomplish the following task: {text}. Respond with only the command, without explanation or additional text.'
            }
        ]
    },
    {
        'flags': ['-x', '--regex'],
        'description': 'generate a regex pattern',
        'clip_output': True,
        'messages': [
            { 
                'role': 'developer', 
                'content': 'You are a regular expression generator. Given a natural language description of the desired text pattern, generate a regex pattern to match it. The regex should be correct, efficient, and concise. Respond with only the raw regex string, without explanations, additional text, or formatting.'
            },
            {
                'role': 'user',
                'content': 'Generate a regex to match the following: {text}. Respond with only the regex pattern, without explanation or additional text.'
            }
        ]
    },
    {
        'flags': ['-i', '--image'],
        'description': 'generate an image (very expensive)',
        'model_args': {
            'model': MINI_LLM,
            'tools': [{
                'type': 'image_generation',
                'size': '1024x1024',
                'quality': 'auto' # low, medium, high
            }],
        },
        'messages': [
            {
                'role': 'user',
                'content': 'Generate an image of the following: {text}.'
            }
        ]
    },
    {
        'flags': ['-w', '--web'],
        'description': 'search the internet (more expensive)',
        'model_args' : {
            'model': MINI_LLM,
            'tools': [{
                'type': 'web_search_preview',
                'search_context_size': 'low'
            }],
        },
        'messages': [
            { 
                'role': 'developer', 
                'content': 'You fetch real-time data from the internet. Always respond with only the data requested. Do not provide additional information in the form of context, background, or links. The response should be less than a single sentence.'
            },
            {
                'role': 'user',
                'content': 'Fetch the following information: {text}.'
            }
        ]
    },
    {
        'flags': ['-r', '--rephrase'],
        'description': 'rephrase text for enhanced fluency',
        'model_args' : {
            'model': FULL_LLM,
        },
        'messages': [
            { 
                'role': 'developer', 
                'content': 'You are writing assistant. Given a text passage, rephrase it to enhance clarity, fluency, and conciseness. Ensure the output is gramatically correct, coherent, and precise. Remove redundant phrases without losing essential details. Do not modify the factual content, level of detail, or tone unless requested.',
            },
            {
                'role': 'user',
                'content': 'Rephrase the following text: {text}'
            }
        ]
    }
]

OPTIONS = [
    {
        'name': 'overwrite',
        'flags': ['-o', '--overwrite'],
        'description': 'overwrite the previous command',
    },
    {
        'name': 'longer',
        'flags': ['-l', '--longer'],
        'description': 'enable longer responses',
    },
    {
        'name': 'no-clip',
        'flags': ['-n', '--no-clip'],
        'description': 'do not copy the output to the clipboard',
    },
    { 
        'name': 'verbose',
        'flags': ['-v', '--verbose'],
        'description': 'print the model parameters and message history',
    },
]
    
def get_client() -> openai.OpenAI:
    api_key =_load_resource('openai_key', None)
    
    if api_key is None:
        cprint(f'Error: OpenAI API key not found. Please paste your API key: ', 'red', end='', flush=True)
        api_key = getpass.getpass(prompt='')
        _save_resource('openai_key', api_key)

    while True:
        try:
            client = openai.OpenAI(api_key=api_key)
            client.models.list() # test the API key
            return client
        
        except openai.APIError:
            cprint(f'Error: OpenAI API key not valid. Please paste your API key: ', 'red', end='', flush=True)
            api_key = getpass.getpass(prompt='')
            _save_resource('openai_key', api_key)

def prompt_model(model_args: Dict, messages: List[Dict]) -> Tuple[str, str]:
    response = get_client().responses.create(
        input=messages,
        **model_args
    )

    # extract text response
    text_response = response.output_text

    # remove markdown formatting from code responses
    text_response = re.sub(r'^\s*```(?:\w*\n)?(.*?)```(?:\s*)$', r'\1', text_response, flags=re.DOTALL)

    # shorten links from web search responses
    text_response = re.sub(r'\[([^\]]+)\]\([^)]+\)', r'\1', text_response).strip()

    # extract image response
    image_response = None
    for output in response.output:
        if output.type == 'image_generation_call':
            image_response = output
            break

    return text_response, image_response

def run_command(cmd: Dict, text: str, **opt_args):
    # load model and messages from command
    model_args = {**DEFAULT_MODEL_ARGS, **cmd.get('model_args', {})}
    messages = [ { role : content.replace('{text}', text) for role, content in msg.items() } for msg in cmd.get('messages', []) ]

    # save model args for follow-up commands
    _save_resource('model_args', model_args)
    # save command args for follow-up commands
    _save_resource('clip_output', cmd.get('clip_output', False))

    # overwrite previous follow-up command
    if opt_args.get('overwrite', False):
        # remove messages from second-to-last user message to last user message
        user_msg_indices = [i for i, msg in enumerate(messages) if msg.get('role') == 'user']
        if len(user_msg_indices) > 1:
            messages = messages[:user_msg_indices[-2]] + messages[user_msg_indices[-1]:]
        else:
            cprint(f'Error: No previous command to overwrite.', 'red')
            sys.exit(1)

    # set max tokens for long responses
    if opt_args.get('longer', False):
        model_args['max_output_tokens'] = LONG_TOKEN_LIMIT

    # prompt the model
    text_response, image_response = prompt_model(model_args, messages)

    # save messages for follow-up commands
    if image_response:
        messages.append({'type': 'image_generation_call', 'id': image_response.id})
    else:
        messages.append({'role': 'assistant', 'content': text_response})
    _save_resource('messages', messages)

    # print output
    if opt_args.get('verbose', False):
        # model parameters
        cprint('MODEL PARAMETERS:', 'red')
        for arg in model_args:
            print(colored(f'{arg}:', 'green'), model_args[arg])
        # message history
        cprint('\n'+'MESSAGES:', 'red')
        for message in messages:
            if message.get('role'):
                print(colored(f'{message["role"].capitalize()}:', 'green'), message['content'])
            elif message.get('type'):
                print(colored(f'{message["type"]}:', 'green'), message['id'])
    elif not image_response:
        print(text_response)

    # copy text response to clipboard
    if not image_response and not opt_args.get('no-clip', False) and cmd.get('clip_output', False):
        try:
            pyperclip.copy(text_response)
            cprint(f'Output copied to clipboard.', 'yellow')
        except pyperclip.PyperclipException:
            pass # ignore clipboard errors

    # save image to file
    if image_response:
        image_file = 'q_' + ''.join(c for c in text if c not in string.punctuation).replace(' ', '_') + '.png'
        with open(image_file, 'wb') as f:
            f.write(base64.b64decode(image_response.result))
        cprint(f'Image saved to {image_file}.', 'yellow')
        
def validate_commands():
    # check if there is a default command
    if len([cmd for cmd in COMMANDS if not cmd['flags']]) == 0:
        cprint(f'Error: No default command found.', 'red')
        sys.exit(1)

    # check if there is more than one default command
    if len([cmd for cmd in COMMANDS if not cmd['flags']]) > 1:
        cprint(f'Error: More than one default command found. If a custom command was added, it is missing a flag.', 'red')
        sys.exit(1)

    # check if there are duplicate commands
    cmd_flags = [flag for cmd in COMMANDS for flag in cmd['flags']]
    dup_flags = set(flag for flag in cmd_flags if cmd_flags.count(flag) > 1)
    if dup_flags:
        cprint(f'Error: Duplicate commands found: {", ".join(dup_flags)}.', 'red')
        sys.exit(1)

def main(args):
    # fix ANSI escape codes on Windows
    just_fix_windows_console()

    # validate custom commands
    validate_commands()

    # help text
    tab_spaces, flag_len = 4, max(len(', '.join(cmd['flags'])) for cmd in COMMANDS + OPTIONS) + 2
    help_text = f'q {VERSION} - an LLM-powered programming copilot from the comfort of your command line.'
    help_text += '\n\nUsage: ' + colored(f'{os.path.basename(args[0])} [command] TEXT [options]', 'green')
    help_text += '\n\nCommands (one required):\n'
    help_text += '\n'.join([' '*tab_spaces + colored(f'{", ".join(cmd["flags"]) if cmd["flags"] else "TEXT":<{flag_len}}', 'green') + f'{cmd["description"]}' for cmd in COMMANDS])
    help_text += '\n\nOptions:\n'
    help_text += '\n'.join([' '*tab_spaces + colored(f'{", ".join(opt["flags"]):<{flag_len}}', 'green') + f'{opt["description"]}' for opt in OPTIONS])

    # print help text if no arguments or -h/--help flag is provided
    if len(args) == 1 or args[1] in ['-h', '--help']:
        print(help_text)
        sys.exit(0)

    # check if there is more than one command
    cmd_flags = [flag for cmd in COMMANDS for flag in cmd['flags']]
    if len([arg for arg in args[1:] if arg in cmd_flags]) > 1:
        cprint(f'Error: Only one command may be provided.', 'red')
        sys.exit(1)

    # check if there is a command that is not the first argument
    if len([arg for arg in args[1:] if arg in cmd_flags]) == 1 and args[1] not in cmd_flags:
        cprint(f'Error: Command must be the first argument.', 'red')
        sys.exit(1)

    # check if the first argument is an invalid command
    if args[1].startswith('-') and args[1] not in cmd_flags:
        cprint(f'Error: Invalid command "{args[1]}".', 'red')
        sys.exit(1)

    # check if there is no text provided for a command
    if args[1] in cmd_flags and len(args) < 3:
        cprint(f'Error: No text provided.', 'red')
        sys.exit(1)

    # extract options and remove them from the text
    opt_args = {opt['name']: False for opt in OPTIONS}
    opt_flags = [flag for opt in OPTIONS for flag in opt['flags']]
    while args[-1].startswith('-') and args[-1] != '-':
        # individual flags (e.g. -v -n)
        if args[-1] in opt_flags:
            flag = args.pop()
            for opt in OPTIONS:
                if flag in opt['flags']:
                    opt_args[opt['name']] = True
        # combined flags (e.g. -vn)
        else:
            flags = args.pop()[1:]
            for flag in flags:
                for opt in OPTIONS:
                    if f'-{flag}' in opt['flags']:
                        opt_args[opt['name']] = True
                        break
                else:
                    cprint(f'Error: Invalid option "-{flags}".', 'red')
                    sys.exit(1)

    # run command
    for cmd in COMMANDS:
        if args[1] in cmd['flags']:
            run_command(cmd, ' '.join(args[2:]), **opt_args)
            sys.exit(0)
    # run default command
    else:
        # already validated there is exactly one default command
        cmd = [cmd for cmd in COMMANDS if not cmd['flags']][0]
        run_command(cmd, ' '.join(args[1:]), **opt_args)

if __name__ == '__main__':
    main(sys.argv)
