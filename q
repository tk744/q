#!/usr/bin/env python3

# standard library imports
import getpass
import json
import os
import sys
from typing import List, Dict

# third-party imports
import openai
import pyperclip
from openai import OpenAI
from termcolor import colored

# resource paths
RESOURCE_DIR = os.path.expanduser('~/.q')
OPENAI_KEY_FILE = os.path.join(RESOURCE_DIR, 'openai.key')  # api key
PREV_MESSAGES = os.path.join(RESOURCE_DIR, 'messages.json') # previous messages
PREV_MODEL = os.path.join(RESOURCE_DIR, 'model_args.json')  # previous model parameters
os.makedirs(RESOURCE_DIR, exist_ok=True)

def _save_messages(messages: List[Dict]):
    with open(PREV_MESSAGES, 'w') as f:
        json.dump(messages, f, indent=4)

def _load_messages() -> List[Dict]:
    try:
        with open(PREV_MESSAGES) as f:
            return json.load(f)
    except FileNotFoundError:
        return []
    
def _save_model_args(model_args: Dict):
    with open(PREV_MODEL, 'w') as f:
        json.dump(model_args, f, indent=4)

def _load_model_args() -> Dict:
    try:
        with open(PREV_MODEL) as f:
            return json.load(f)
    except FileNotFoundError:
        return {}

# model variants
MINI_LLM = 'gpt-4o-mini' # faster and cheaper
FULL_LLM = 'gpt-4o'      # more powerful and expensive

# default model parameters
DEFAULT_MODEL_ARGS = {
    'model': MINI_LLM,
    'max_tokens': 128,
    'temperature': 0.0,
    'frequency_penalty': 0,
    'presence_penalty': 0,
    'top_p': 1,
    'stop': None
}

# option parameters
LONG_MAX_TOKENS = 1024 # max tokens for long responses

COMMANDS = [
    {
        'flags': [],
        'description': 'follow-up on the previous response',
        'model_args': _load_model_args(),
        'messages': _load_messages() + [
            {
                'role': 'user',
                'content': '{text}'
            }
        ]
    },
    {
        'flags': ['-c', '--code'],
        'description': 'generate a code snippet (default Python unless specified)',
        'model_args': {
            'model': FULL_LLM,
            'max_tokens': 256
        },
        'messages': [
            { 
                'role': 'system', 
                'content': 'You are a coding assistant. Given a natural language description, generate a code snippet that accomplishes the requested task. The code should be correct, efficient, concise, and idiomatic. Respond with only the code snippet, without explanations, additional text, or formatting. Assume the programming language is Python unless otherwise specified.'
            },
            {
                'role': 'user',
                'content': 'Generate a code snippet to accomplish the following task: {text}. Respond only with the code, without explanation or additional text.'
            }
        ]
    },
    {
        'flags': ['-s', '--shell'],
        'description': 'generate a shell command (default Linux Bash unless specified)',
        'messages': [
            { 
                'role': 'system', 
                'content': 'You are a command-line assistant. Given a natural language task description, generate a single shell command that accomplishes the task. Avoid commands that could delete, overwrite, or modify important files or system settings (e.g., rm -rf, dd, mkfs, chmod -R, chown, kill -9). Respond with only the command, without explanations, additional text, or formatting. Assume a Linux Bash shell unless otherwise specified.'
            },
            {
                'role': 'user',
                'content': 'Generate a single shell command to accomplish the following task: {text}. Respond with only the command, without explanation or additional text.'
            }
        ]
    },
    {
        'flags': ['-x', '--regex'],
        'description': 'generate a regex pattern (default Python re unless specified)',
        'messages': [
            { 
                'role': 'system', 
                'content': 'You are a regular expression generator. Given a natural language description of the desired text pattern, generate a regex pattern to match it. The regex should be correct, efficient, and concise. Respond with only the raw regex string, without explanations, additional text, or formatting. Use the Python re module syntax unless otherwise specified.'
            },
            {
                'role': 'user',
                'content': 'Generate a regex to match the following: {text}. Respond with only the regex pattern, without explanation or additional text.'
            }
        ]
    },
    {
        'flags': ['-r', '--rephrase'],
        'description': 'rephrase text for enhanced fluency',
        'model_args' : {
            'model': FULL_LLM,
            'max_tokens': 256
        },
        'messages': [
            { 
                'role': 'system', 
                'content': 'You are writing assistant. Given a text passage, rephrase it to enhance clarity, fluency, and conciseness. Ensure the output is gramatically correct, coherent, and precise. Remove redundant phrases without losing essential details. Do not modify the factual content, level of detail, or tone unless requested.',
            },
            {
                'role': 'user',
                'content': 'Rephrase the following text: {text}'
            }
        ]
    },
    {
        'flags': ['-p', '--prompt'],
        'description': 'prompt a regular language model',
        'model_args': {
            'model': FULL_LLM,
            'max_tokens': 256,
            'temperature': 0.25,
        },
        'messages': [
            { 
                'role': 'system', 
                'content': 'You are a helpful and knowledgeable AI assistant.'
            },
            {
                'role': 'user',
                'content': '{text}'
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
        'description': 'enable longer responses (note: may increase cost)',
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
    
def get_client() -> OpenAI:
    while True:
        try:
            with open(OPENAI_KEY_FILE) as f:
                client = OpenAI(api_key=f.read())
                client.models.list() # test the API key
                return client
        except FileNotFoundError:
            print(colored(f'Error: OpenAI API key not found. Please paste your API key: ', 'red'), end='', flush=True)
            with open(OPENAI_KEY_FILE, 'w') as f:
                f.write(getpass.getpass(prompt=''))
        except (openai.AuthenticationError, openai.APIConnectionError):
            print(colored(f'Error: OpenAI API key not valid. Please paste your API key: ', 'red'), end='', flush=True)
            with open(OPENAI_KEY_FILE, 'w') as f:
                f.write(getpass.getpass(prompt=''))

def prompt_model(model: str, model_args: Dict, messages: List[Dict]) -> str:
    return get_client().chat.completions.create(
        messages=messages,
        **model_args
    ).choices[0].message.content

def run_command(cmd: Dict, text: str, **opt_args):
    # load model and messages from command
    model_args = {**DEFAULT_MODEL_ARGS, **cmd.get('model_args', {})}
    messages = [ { role : content.replace('{text}', text) for role, content in msg.items() } for msg in cmd.get('messages', []) ]

    # save model args for follow-up commands
    _save_model_args(model_args)

    # overwrite previous follow-up command
    if opt_args.get('overwrite', False):
        # remove messages from second-to-last user message to last user message
        user_msg_indices = [i for i, msg in enumerate(messages) if msg['role'] == 'user']
        if len(user_msg_indices) > 1:
            messages = messages[:user_msg_indices[-2]] + messages[user_msg_indices[-1]:]
        else:
            print(colored(f'Error: No previous command to overwrite.', 'red'))
            exit(1)

    # set max tokens for long responses
    if opt_args.get('longer', False):
        model_args['max_tokens'] = LONG_MAX_TOKENS

    # prompt the model
    response = prompt_model(model_args['model'], model_args, messages)

    # remove markdown formatting from code responses
    if response.startswith('```'):
        response = response[response.find('\n')+1:]
    if response.endswith('```'):
        response = response[:response.rfind('\n')]

    # save messages for follow-up commands
    messages.append({'role': 'assistant', 'content': response})
    _save_messages(messages)

    # print output
    if opt_args.get('verbose', False):
        print(colored('MODEL PARAMETERS:', 'red'))
        for arg in model_args:
            print(colored(f'{arg}:', 'green'), model_args[arg])
        print('\n'+colored('MESSAGES:', 'red'))
        for message in messages:
            print(colored(f'{message["role"].capitalize()}:', 'green'), message['content'])
    else:
        print(response)

    # copy response to clipboard
    if not opt_args.get('no-clip', False):
        try:
            pyperclip.copy(response)
        except pyperclip.PyperclipException:
            pass # ignore clipboard errors
        
def validate_commands():
    # check if there is a default command
    if len([cmd for cmd in COMMANDS if not cmd['flags']]) == 0:
        print(colored(f'Error: No default command found.', 'red'))
        exit(1)

    # check if there is more than one default command
    if len([cmd for cmd in COMMANDS if not cmd['flags']]) > 1:
        print(colored(f'Error: More than one default command found. If a custom command was added, it is missing a flag.', 'red'))
        exit(1)

    # check if there are duplicate commands
    cmd_flags = [flag for cmd in COMMANDS for flag in cmd['flags']]
    dup_flags = set(flag for flag in cmd_flags if cmd_flags.count(flag) > 1)
    if dup_flags:
        print(colored(f'Error: Duplicate commands found: {", ".join(dup_flags)}.', 'red'))
        exit(1)

def main(args):
    # validate custom commands
    validate_commands()

    # help text
    tab_spaces, flag_len = 4, max(len(', '.join(cmd['flags'])) for cmd in COMMANDS + OPTIONS) + 2
    help_text = 'q is an LLM-powered programming copilot from the comfort of your command line.'
    help_text += '\n\nUsage: ' + colored(f'{os.path.basename(args[0])} [command] TEXT [options]', 'green')
    help_text += '\n\nCommands (one required):\n'
    help_text += '\n'.join([' '*tab_spaces + colored(f'{", ".join(cmd["flags"]) if cmd["flags"] else "TEXT":<{flag_len}}', 'green') + f'{cmd["description"]}' for cmd in COMMANDS])
    help_text += '\n\nOptions:\n'
    help_text += '\n'.join([' '*tab_spaces + colored(f'{", ".join(opt["flags"]):<{flag_len}}', 'green') + f'{opt["description"]}' for opt in OPTIONS])

    # print help text if no arguments or -h/--help flag is provided
    if len(args) == 1 or args[1] in ['-h', '--help']:
        print(help_text)
        exit(0)

    # check if there is more than one command
    cmd_flags = [flag for cmd in COMMANDS for flag in cmd['flags']]
    if len([arg for arg in args[1:] if arg in cmd_flags]) > 1:
        print(colored(f'Error: Only one command may be provided.', 'red'))
        exit(1)

    # check if there is a command that is not the first argument
    if len([arg for arg in args[1:] if arg in cmd_flags]) == 1 and args[1] not in cmd_flags:
        print(colored(f'Error: Command must be the first argument.', 'red'))
        exit(1)

    # check if the first argument is an invalid command
    if args[1].startswith('-') and args[1] not in cmd_flags:
        print(colored(f'Error: Invalid command "{args[1]}".', 'red'))
        exit(1)

    # check if there is no text provided for a command
    if args[1] in cmd_flags and len(args) < 3:
        print(colored(f'Error: No text provided.', 'red'))
        exit(1)

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
                    print(colored(f'Error: Invalid option "-{flags}".', 'red'))
                    exit(1)

    # run command
    for cmd in COMMANDS:
        if args[1] in cmd['flags']:
            run_command(cmd, ' '.join(args[2:]), **opt_args)
            exit(0)
    # run default command
    else:
        # already validated there is exactly one default command
        cmd = [cmd for cmd in COMMANDS if not cmd['flags']][0]
        run_command(cmd, ' '.join(args[1:]), **opt_args)

if __name__ == '__main__':
    main(sys.argv)
