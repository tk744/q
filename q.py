#!/usr/bin/env python3

import argparse
import json
import os
import pyperclip

from abc import ABC, abstractmethod
from openai import OpenAI
from termcolor import colored


class SingleMetavarHelpFormatter(argparse.HelpFormatter):
    """Custom HelpFormatter to display `--cmd TEXT` instead of `--cmd TEXT [TEXT ...]`."""
    def _format_args(cls, action, default_metavar):
        if action.nargs == "+":
            return action.metavar  # Show only 'TEXT' instead of 'TEXT [TEXT ...]'
        return super()._format_args(action, default_metavar)

class LLM(ABC):
    """
    Abstract base class for a language model. Subclasses must implement the `model` and `messages` methods, and may override the `model_args` method.
    """

    messages_file = 'messages.json'

    default_model_args = {
        'temperature': 0.0,
        'max_tokens': 256,
        'frequency_penalty': 0,
        'presence_penalty': 0,
        'top_p': 1,
        'stop': None
    }

    @classmethod
    def prompt(cls, text: str, verbose=False) -> str:
        model_args = {**cls.default_model_args, **cls.model_args()}
        messages = cls.messages(text)

        # send messages to the LLM
        response = cls.client().chat.completions.create(
            model=cls.model(),
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
        if verbose:
            for message in messages:
                print(colored(f'{message["role"].capitalize()}:', 'red'), message['content'], end='\n\n')
        else:
            print(response)

        # copy response to clipboard
        pyperclip.copy(response)

        return response
    
    @classmethod
    def client(cls, openai_key_file='openai.key') -> OpenAI:
        try:
            with open(openai_key_file) as f:
                os.environ['OPENAI_API_KEY'] = f.read()
                return OpenAI()
        except FileNotFoundError:
            print(colored(f'Error: OpenAI API key file not found. Please create a file named {openai_key_file} in the current directory and paste your API key there.', 'red'))
            exit(1)

    @classmethod
    def save_messages(cls, messages: list):
        with open(cls.messages_file, 'w') as f:
            json.dump(messages, f, indent=4)

    @classmethod
    def load_messages(cls) -> list:
        with open(cls.messages_file) as f:
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

class RecallLLM(LLM):
    """
    A stateful language model that can respond to prompts about previous messages.
    """
    
    
    @classmethod
    def model(cls) -> str:
        return 'gpt-4o'

    @classmethod
    def messages(cls, text) -> list:
        return cls.load_messages() + [
            {
                'role': 'user',
                'content': text
            }
        ]

class ChatLLM(LLM):
    """
    A conversational language model that can respond to anything.
    """
    
    @classmethod
    def model(cls) -> str:
        return 'gpt-4o'

    @classmethod
    def messages(cls, text) -> list:
        return [
            { 
                'role': 'system', 
                'content': 'You are ChatGPT, a friendly AI assistant.'
            },
            {
                'role': 'user',
                'content': text
            }
        ]

class RewriteLLM(LLM):
    """
    A language model that rewrites text for clarity, accuracy, and readability.
    """

    @classmethod
    def model(cls) -> str:
        return 'gpt-4o'

    @classmethod
    def messages(cls, text) -> list:
        return [
            { 
                'role': 'system', 
                'content': 'You are a skilled writing assistant specializing in improving the clarity, conciseness, and correctness of written text. Your goal is to rephrase input text while preserving its original meaning, improving word choice, grammar, and flow. Ensure that the output is professional, precise, and natural-sounding. Do not add or remove significant information unless necessary for clarity.'
            },
            {
                'role': 'user',
                'content': f'Improve the following text for clarity, accuracy, and readability while keeping the original meaning.\n{text}'
            }
        ]

class BashLLM(LLM):
    """
    A language model that generates Bash commands from natural language descriptions.
    """

    @classmethod
    def model(cls) -> str:
        return 'gpt-4o-mini'

    @classmethod
    def messages(cls, text) -> list:
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
        return 'gpt-4o'
    
    @classmethod
    def model_args(cls) -> dict:
        return {
            'max_tokens': 1024
        }

    @classmethod
    def messages(cls, text) -> list:
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
        return 'gpt-4o-mini'

    @classmethod
    def messages(cls, text) -> list:
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

if __name__ == '__main__':
    parser = argparse.ArgumentParser(
        description='q is an LLM-powered command-line copilot that generates code and text used most by programmers.', 
        formatter_class=SingleMetavarHelpFormatter # custom formatter
    )

    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument('-c', '--chat', metavar='TEXT', nargs='+', type=str, help='prompt the LLM about anything')
    group.add_argument('-r', '--rewrite', metavar='TEXT', nargs='+', type=str, help='rewrite text for improved phrasing')
    group.add_argument('-b', '--bash', metavar='TEXT', nargs='+', type=str, help='generate a Bash command from a description')
    group.add_argument('-p', '--python', metavar='TEXT', nargs='+', type=str, help='generate a Python script from a description')
    group.add_argument('-x', '--regex', metavar='TEXT', nargs='+', type=str, help='generate a Python regex pattern from a description')
    group.add_argument('text', metavar='TEXT', nargs='*', type=str, help='chat about the previous response')
    
    parser.add_argument('-v', '--verbose', action='store_true', help='print the LLM messages and response')

    # TODO:
    # group.add_argument('-e', '--explain', metavar='TEXT', nargs='+', type=str, help='Explain a concept or code snippet')

    args = parser.parse_args()

    if args.chat:
        ChatLLM.prompt(' '.join(args.chat), args.verbose)
    elif args.rewrite:
        RewriteLLM.prompt(' '.join(args.rewrite), args.verbose)
    elif args.bash:
        BashLLM.prompt(' '.join(args.bash), args.verbose)
    elif args.python:
        PythonLLM.prompt(' '.join(args.python), args.verbose)
    elif args.regex:
        RegexLLM.prompt(' '.join(args.regex), args.verbose)
    elif args.text:
        RecallLLM.prompt(' '.join(args.text), args.verbose)
    else:
        parser.print_help()