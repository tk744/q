#!/usr/bin/env python3

# standard library imports
import getpass
import json
import os
import sys

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

def _save_messages(messages: list[dict]):
    with open(PREV_MESSAGES, 'w') as f:
        json.dump(messages, f, indent=4)

def _load_messages() -> list[dict]:
    try:
        with open(PREV_MESSAGES) as f:
            return json.load(f)
    except FileNotFoundError:
        return []
    
def _save_model_args(model_args: dict):
    with open(PREV_MODEL, 'w') as f:
        json.dump(model_args, f, indent=4)

def _load_model_args() -> dict:
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
LONG_MAX_TOKENS = 512 # max tokens for long responses

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
        'flags': ['-b', '--bash'],
        'description': 'generate a Bash command from a description',
        'messages': [
            { 
                'role': 'system', 
                'content': 'You are a command-line assistant. Given a natural language task description, respond with a single shell command that accomplishes the task. Respond with only the command, without explanations, additional text, or formatting. Assume a Bash environment. Avoid commands that could delete, overwrite, or modify important files or system settings (e.g., rm -rf, dd, mkfs, chmod -R, chown, kill -9).'
            },
            {
                'role': 'user',
                'content': 'Generate a single Bash command to accomplish the following task: {text}. Respond with only the command, without explanation or additional text.'
            }
        ]
    },
    {
        'flags': ['-p', '--python'],
        'description': 'generate a Python script from a description',
        'model_args': {
            'model': FULL_LLM,
            'max_tokens': 256
        },
        'messages': [
            { 
                'role': 'system', 
                'content': 'You are a Python coding assistant. Given a natural language description, generate Python code that accomplishes the requested task. Ensure the code is correct, efficient, and follows best practices. Respond only with the code, without explanations, additional text, or formatting. If multiple implementations are possible, choose the most idiomatic and concise approach.'
            },
            {
                'role': 'user',
                'content': 'Write a Python script to accomplish the following task: {text}. Respond only with the code, without explanation or additional text.'
            }
        ]
    },
    {
        'flags': ['-x', '--regex'],
        'description': 'generate a Python regex pattern from a description',
        'messages': [
            { 
                'role': 'system', 
                'content': 'You are a Python regular expression generator. Given a natural language description of the desired text pattern, respond with only a valid Python regex pattern. Do not include explanations, code examples, or additional text -- only the raw regex string. Ensure correctness and efficiency.'
            },
            {
                'role': 'user',
                'content': 'Generate a Python regular expression that matches {text}. Respond with only the regex pattern, without explanation or additional text.'
            }
        ]
    },
    {
        'flags': ['-r', '--rephrase'],
        'description': 'rephrase text for improved fluency',
        'model_args' : {
            'model': FULL_LLM,
            'max_tokens': 256
        },
        'messages': [
            { 
                'role': 'system', 
                'content': 'You are an advanced language model specialized in rephrasing text for clarity, fluency, and conciseness. Your goal is to improve readability and coherence while preserving the original meaning. Ensure the output is grammatically correct, natural, and precise. Eliminate redundancy by removing unnecessary words and simplifying overly complex structures without losing essential details. Maintain technical accuracy for specialized content and adapt the phrasing to suit the audience if specified. Avoid altering factual content, tone, or intent unless explicitly requested.',
            },
            {
                'role': 'user',
                'content': 'Rephrase the following text to improve clarity, fluency, and conciseness: {text}'
            }
        ]
    },
    {
        'flags': ['-w', '--workplace'],
        'description': 'write a professional workplace message',
        'model_args': {
            'model': FULL_LLM
        },
        'messages': [
            { 
                'role': 'system', 
                'content': 'You are an assistant that writes workplace chat messages in a professional tone for communication with managers and coworkers. Your goal is to transform input messages into clear, workplace-appropriate language without altering intent, adding personal judgments, or providing unsolicited advice. Maintain a neutral or positive tone as appropriate. Do not use formal or flowery language, and avoid greetings and unnecessary pleasantries unless requested.'
            },
            {
                'role': 'user',
                'content': 'Write a clear and professional chat message for the following task: {text}'
            }
        ]
    },
    {
        'flags': ['-c', '--chat'],
        'description': 'chat with a full language model',
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
        'description': 'overwrite the previous follow-up command',
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
        except (FileNotFoundError, openai.AuthenticationError, openai.APIConnectionError):
            print(colored(f'Error: OpenAI API key not found. Please paste your API key: ', 'red'), end='', flush=True)
            with open(OPENAI_KEY_FILE, 'w') as f:
                f.write(getpass.getpass(prompt=''))

def prompt_model(model: str, model_args: dict, messages: list[dict]) -> str:
    return get_client().chat.completions.create(
        messages=messages,
        **model_args
    ).choices[0].message.content

def run_command(cmd: dict, text: str, **opt_args):
    # load model and messages from command
    model_args = {**DEFAULT_MODEL_ARGS, **cmd.get('model_args', {})}
    messages = json.loads(json.dumps(cmd.get('messages', [])).replace('{text}', text))

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

def main(args):
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
        default_cmds = [cmd for cmd in COMMANDS if not cmd['flags']]
        if len(default_cmds) == 0:
            print(colored(f'Error: No default command found.', 'red'))
            exit(1)
        elif len(default_cmds) > 1:
            print(colored(f'Error: More than one default command found. If a custom command was added, it is missing a flag.', 'red'))
            exit(1)
        else:
            cmd = default_cmds[0]
            run_command(cmd, ' '.join(args[1:]), **opt_args)
            exit(0)

if __name__ == '__main__':
    main(sys.argv)
