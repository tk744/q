#!/usr/bin/env python3

# standard library imports
import getpass
import json
import os
import sys
from abc import ABC, abstractmethod

# third-party imports
import openai
import pyperclip
from openai import OpenAI
from termcolor import colored

# default resource paths
RESOURCE_DIR = os.path.expanduser('~/.q')
OPENAI_KEY_FILE = os.path.join(RESOURCE_DIR, 'openai.key')
MESSAGES_FILE = os.path.join(RESOURCE_DIR, 'messages.json')

# model variants
MINI_LLM = 'gpt-4o-mini' # faster and cheaper
FULL_LLM = 'gpt-4o'      # more powerful and expensive

class LLM(ABC):
    """
    Abstract base class for a language model. Subclasses must implement the `model` and `messages` methods, and may override the `model_args` method.
    """

    default_model_args = {
        'max_tokens': 128,
        'temperature': 0.0,
        'frequency_penalty': 0,
        'presence_penalty': 0,
        'top_p': 1,
        'stop': None
    }

    long_max_tokens = 1024

    @classmethod
    def prompt(cls, text: str, **option_args) -> str:
        # load model and messagees from subclass
        model = cls.model()
        model_args = {**cls.default_model_args, **cls.model_args()}
        messages = cls.messages(text)

        # set max tokens for long responses
        if option_args.get('long', False):
            model_args['max_tokens'] = cls.long_max_tokens

        # send messages to the LLM
        response = cls.client().chat.completions.create(
            model=model,
            messages=messages,
            **model_args
        ).choices[0].message.content

        # remove markdown formatting from code responses
        if response.startswith('```'):
            response = response[response.find('\n')+1:]
        if response.endswith('```'):
            response = response[:response.rfind('\n')]

        # save messages to file for future reference
        messages.append({'role': 'assistant', 'content': response})
        cls.save_messages(messages)

        # print messages and response depending on verbosity
        if option_args.get('verbose', False):
            for message in messages:
                print(colored(f'{message["role"].capitalize()}:', 'red'), message['content'], end='\n\n')
        else:
            print(response)

        # copy response to clipboard
        if not option_args.get('no-clip', False):
            pyperclip.copy(response)

        return 0
    
    @classmethod
    def client(cls) -> OpenAI:
        while True:
            try:
                with open(OPENAI_KEY_FILE) as f:
                    client = OpenAI(api_key=f.read())
                    client.models.list() # test the API key
                    return client
            except (FileNotFoundError, openai.AuthenticationError, openai.APIConnectionError):
                print(colored(f'Error: OpenAI API key not found. Please paste your API key:', 'red'), end='', flush=True)
                os.makedirs(RESOURCE_DIR, exist_ok=True)
                with open(OPENAI_KEY_FILE, 'w') as f:
                    f.write(getpass.getpass(prompt=''))

    @classmethod
    def save_messages(cls, messages: list):
        with open(MESSAGES_FILE, 'w') as f:
            json.dump(messages, f, indent=4)

    @classmethod
    def load_messages(cls) -> list:
        with open(MESSAGES_FILE) as f:
            return json.load(f)

    @classmethod
    @abstractmethod
    def model(cls) -> str:
        pass

    @classmethod
    def model_args(cls) -> dict:
        return {}

    @classmethod
    @abstractmethod
    def messages(cls, text=None) -> list:
        pass

class FollowupLLM(LLM):
    """
    A stateful language model that can respond to prompts about previous messages.
    """

    @classmethod
    def model(cls) -> str:
        return FULL_LLM
    
    @classmethod
    def model_args(cls) -> dict:
        return {
            'max_tokens': 256,
        }

    @classmethod
    def messages(cls, text: str) -> list:
        return cls.load_messages() + [
            {
                'role': 'user',
                'content': text
            }
        ]

class BashLLM(LLM):
    """
    A language model that generates Bash commands from natural language descriptions.
    """

    @classmethod
    def model(cls) -> str:
        return MINI_LLM

    @classmethod
    def messages(cls, text: str) -> list:
        return [
            { 
                'role': 'system', 
                'content': 'You are a command-line assistant. Given a natural language task description, respond with a single shell command that accomplishes the task. Respond with only the command, without explanations, additional text, or formatting. Assume a Bash environment. Avoid commands that could delete, overwrite, or modify important files or system settings (e.g., rm -rf, dd, mkfs, chmod -R, chown, kill -9).'
            },
            {
                'role': 'user',
                'content': f'Generate a single Bash command to accomplish the following task: {text}. Respond with only the command, without explanation or additional text.'
            }
        ]
    
class PythonLLM(LLM):
    """
    A language model that generates Python code from natural language descriptions.
    """

    @classmethod
    def model(cls) -> str:
        return FULL_LLM
    
    @classmethod
    def model_args(cls) -> dict:
        return {
            'max_tokens': 512
        }

    @classmethod
    def messages(cls, text: str) -> list:
        return [
            { 
                'role': 'system', 
                'content': 'You are a Python coding assistant. Given a natural language description, generate Python code that accomplishes the requested task. Ensure the code is correct, efficient, and follows best practices. Respond only with the code, without explanations, additional text, or formatting. If multiple implementations are possible, choose the most idiomatic and concise approach.'
            },
            {
                'role': 'user',
                'content': f'Write a Python script to accomplish the following task: {text}. Respond only with the code, without explanation or additional text.'
            }
        ]
    
class RegexLLM(LLM):
    """
    A language model that generates Python regex patterns from natural language descriptions.
    """

    @classmethod
    def model(cls) -> str:
        return MINI_LLM

    @classmethod
    def messages(cls, text: str) -> list:
        return [
            { 
                'role': 'system', 
                'content': 'You are a Python regular expression generator. Given a natural language description of the desired text pattern, respond with only a valid Python regex pattern. Do not include explanations, code examples, or additional text -- only the raw regex string. Ensure correctness and efficiency.'
            },
            {
                'role': 'user',
                'content': f'Generate a Python regular expression that matches {text}. Respond with only the regex pattern, without explanation or additional text.'
            }
        ]

class RephraseLLM(LLM):
    """
    A language model that rephrases text for clarity and fluency.
    """

    @classmethod
    def model(cls) -> str:
        return FULL_LLM
    
    @classmethod
    def model_args(cls) -> dict:
        return {
            'max_tokens': 256,
            'temperature': 0.3
        }

    @classmethod
    def messages(cls, text: str) -> list:
        return [
            { 
                'role': 'system', 
                'content': 'You are an advanced language model specialized in rephrasing text for clarity, fluency, and conciseness. Your goal is to improve readability and coherence while preserving the original meaning. Ensure the output is grammatically correct, natural, and precise. Eliminate redundancy by removing unnecessary words and simplifying overly complex structures without losing essential details. Maintain technical accuracy for specialized content and adapt the phrasing to suit the audience if specified. Avoid altering factual content, tone, or intent unless explicitly requested.',
            },
            {
                'role': 'user',
                'content': f'Rephrase the following text to improve clarity, fluency, and conciseness: {text}'
            }
        ]

class WorkplaceLLM(LLM):
    """
    A language model that generates messages for workplace communication.
    """

    @classmethod
    def model(cls) -> str:
        return FULL_LLM

    @classmethod
    def messages(cls, text: str) -> list:
        return [
            { 
                'role': 'system', 
                'content': 'You are an assistant that writes workplace chat messages in a professional tone for communication with managers and coworkers. Your goal is to transform input messages into clear, workplace-appropriate language without altering intent, adding personal judgments, or providing unsolicited advice. Maintain a neutral or positive tone as appropriate. Do not use formal or flowery language, and avoid greetings and unnecessary pleasantries unless requested.'
            },
            {
                'role': 'user',
                'content': f'Write a clear and professional chat message for the following task: {text}'
            }
        ]
    
class ChatLLM(LLM):
    """
    A conversational language model that can respond to anything.
    """

    @classmethod
    def model(cls) -> str:
        return FULL_LLM

    @classmethod
    def model_args(cls) -> dict:
        return {
            'max_tokens': 256,
            'temperature': 0.3,
        }

    @classmethod
    def messages(cls, text: str) -> list:
        return [
            { 
                'role': 'system', 
                'content': 'You are a helpful and knowledgeable AI assistant.'
            },
            {
                'role': 'user',
                'content': text
            }
        ]

def main(args):
    commands = [
        {
            'llm': FollowupLLM,
            'flags': [], # default LLM
            'description': 'chat about the previous response',
        },
        {
            'llm': BashLLM,
            'flags': ['-b', '--bash'],
            'description': 'generate a Bash command from a description',
        },
        {
            'llm': PythonLLM,
            'flags': ['-p', '--python'],
            'description': 'generate a Python script from a description',
        },
        {
            'llm': RegexLLM,
            'flags': ['-x', '--regex'],
            'description': 'generate a Python regex pattern from a description',
        },
        {
            'llm': RephraseLLM,
            'flags': ['-r', '--rephrase'],
            'description': 'rephrase text for improved fluency',
        },
        {
            'llm': WorkplaceLLM,
            'flags': ['-w', '--workplace'],
            'description': 'write a professional workplace message',
        },
        {
            'llm': ChatLLM,
            'flags': ['-c', '--chat'],
            'description': 'prompt a regular language model',
        },
    ]

    options = [
        {
            'name': 'long',
            'flags': ['-l', '--long'],
            'description': 'enable longer responses (note: more expensive)',
        },
        # {
        #     'name': 'reasoning',
        #     'flags': ['-o', '--reasoning'],
        #     'description': 'use a reasoning model (note: this is very expensive)',
        # },
        {
            'name': 'no-clip',
            'flags': ['-n', '--no-clip'],
            'description': 'do not copy the output to the clipboard',
        },
        { 
            'name': 'verbose',
            'flags': ['-v', '--verbose'],
            'description': 'print the message and response history',
        },
    ]

    # help text
    tab_spaces, flag_len = 4, max(len(', '.join(cmd['flags'])) for cmd in commands + options) + 3
    help_text = 'q is an LLM-powered programming copilot from the comfort of your command line.'
    help_text += '\n\nUsage: ' + colored(f'{os.path.basename(args[0])} [command] TEXT [options]', 'green')
    help_text += '\n\nCommands (one required):\n'
    help_text += '\n'.join([' '*tab_spaces + colored(f'{", ".join(cmd["flags"]) if cmd["flags"] else "TEXT":<{flag_len}}', 'green') + f'{cmd["description"]}' for cmd in commands])
    help_text += '\n\nOptions:\n'
    help_text += '\n'.join([' '*tab_spaces + colored(f'{", ".join(opt["flags"]):<{flag_len}}', 'green') + f'{opt["description"]}' for opt in options])

    # print help text if no arguments or -h/--help flag is provided
    if len(args) == 1 or args[1] in ['-h', '--help']:
        print(help_text)
        exit(0)

    # check if there is more than one command
    cmd_flags = [flag for cmd in commands for flag in cmd['flags']]
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

    # get options after text and remove them from args
    option_args = {opt['name']: False for opt in options}
    opt_flags = [flag for opt in options for flag in opt['flags']]
    while args[-1].startswith('-') and args[-1] != '-':
        # individual flags (e.g. -v -n)
        if args[-1] in opt_flags:
            flag = args.pop()
            for opt in options:
                if flag in opt['flags']:
                    option_args[opt['name']] = True
        # combined flags (e.g. -vn)
        else:
            flags = args.pop()[1:]
            for flag in flags:
                for opt in options:
                    if f'-{flag}' in opt['flags']:
                        option_args[opt['name']] = True
                        break
                else:
                    print(colored(f'Error: Invalid option "-{flags}".', 'red'))
                    exit(1)

    # if the first argument is not a command, use the default LLM
    if args[1] not in cmd_flags:
        default_llms = [cmd['llm'] for cmd in commands if not cmd['flags']]
        assert len(default_llms) == 1, 'Programming error: There is more than one default LLM.'
        default_llms[0].prompt(' '.join(args[1:]), **option_args)
        exit(0)

    # if the first argument is a command, use the corresponding LLM
    for cmd in commands:
        if args[1] in cmd['flags']:
            cmd['llm'].prompt(' '.join(args[2:]), **option_args)
            exit(0)

    # unknown error
    print(colored(f'Error: An unknown error occurred.', 'red'))
    exit(1)

if __name__ == '__main__':
    main(sys.argv)