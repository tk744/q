# Overview
`q` is an LLM-powered copilot for the command line, designed to keep programers in the terminal and reduce time spent looking things up. It can generate shell commands, write Python scripts, construct regex patterns, and more, all from the comfort of your command line.

# Installation

Requires Python 3.8+ and the following dependencies:

```
pip install colorama openai pyperclip termcolor
```

Download the script to a directory in your path (e.g. `~/.local/bin/`) and make it executable:

```
wget -qO ~/.local/bin/q https://raw.githubusercontent.com/tk744/q/refs/heads/master/q && chmod +x ~/.local/bin/q
```

The first time `q` is prompted, you will be asked for an OpenAI API key which you can create [here](https://platform.openai.com/api-keys).

# Usage

The basic syntax is `q [command] TEXT [options]`. `q` accepts at most one command and any number of options. Any arguments between the command and options is treated as the input text.

`q` stores the output to the clipboard so you can paste it wherever you need it. This only works on non-headless environments (no VMs and Docker containers), check [here](https://pyperclip.readthedocs.io/en/latest/index.html#not-implemented-error) if it doesn't work.

For a full list of commands and options, run `q -h`.

## Commands

Each command runs a tailored LLM prompt using the OpenAI API and returns the response.

### Generate Code

Use the `-c` or `--code` command to generate code snippets:

```
$ q -c copy user input to clipboard
import pyperclip

user_input = input("Enter text to copy to clipboard: ")
pyperclip.copy(user_input)
```

By default this generates Python code, but you can specify a different programming language in the prompt itself:

```
$ q -c copy user input to clipboard in rust
use std::io::{self, Write};
use clipboard::{ClipboardContext, ClipboardProvider};

fn main() {
    let mut input = String::new();
    print!("Enter text to copy to clipboard: ");
    io::stdout().flush().unwrap();
    io::stdin().read_line(&mut input).unwrap();

    let mut ctx: ClipboardContext = ClipboardProvider::new().unwrap();
    ctx.set_contents(input.trim().to_string()).unwrap();
}
```

You can redirect the output to a file and run it instantly:

```
$ q -c fib function w main function > fib.py && python3 fib.py
Enter a number: 10
Fibonacci number at position 10 is 55
```

### Generate Shell Commands

Use the `-s` or `--shell` command to generate shell commands:

```
$ q -s add README.md to prev commit and push changes
git add README.md && git commit --amend --no-edit && git push --force
```

By default this generates Bash commands for a Linux system, but you can specify a different shell or OS in the prompt itself:

```
$ q -s auto hide the dock on macos
defaults write com.apple.dock autohide -bool true; killall Dock
```

You can pipe the output to the shell interpreter to run it instantly:

```
$ q -s count line numbers in fib.py | bash
12 fib.py
```

### Generate Regex Patterns

Use the `-x` or `--regex` command to generate regex patterns:

```
$ q -x html tags
<[^>]+>
```

### Rephrase Text

Use the `-r` or `--rephrase` command to rephrase text for enhanced fluency:

```
$ q -r watchin haters wonder why gambino got the game locked
Watching critics wonder why Gambino dominates the game.
```

### General Prompting

Use the `-p` or `--prompt` command to prompt a regular language model about anything:

```
$ q -p give me a punchline without the setup
"…and that's why you never trust a penguin with your ice cream!"
```

## Multi-Turn Commands

Use `q` without specifying a command to build on previous responses and run contextualized multi-turn commands:

```
$ q -r did they went away of town
Did they leave town?
$ q now like a sarcastic pirate
Arr, did they set sail and abandon this here town?
```

This enables many useful follow-up interactions, like interactively refining generated code:

```
$ q -s get cuda version
nvcc --version
$ nvcc --version
bash: nvcc: command not found
$ q command not found
cat /usr/local/cuda/version.txt
$ cat /usr/local/cuda/version.txt
cat: /usr/local/cuda/version.txt: No such file or directory
$ q file not found
nvidia-smi | grep "CUDA Version"
$ nvidia-smi | grep "CUDA Version"
| NVIDIA-SMI 560.35.02    Driver Version: 560.94    CUDA Version: 12.6 |
```

Asking questions about generated code:

```
$ q -c function to merge two dictionaries x and y
def merge_dictionaries(x, y):
    return {**x, **y}
$ q what is the time complexity
The time complexity of merging two dictionaries using `{**x, **y}` is O(n + m), where n is the number of elements in dictionary `x` and m is the number of elements in dictionary `y`.
```

## Options

Options are boolean flags that modify the behavior of `q`:

- Use the `-o` or `--overwrite` option to overwrite the previous command.
- Use the `-l` or `--longer` option to increase the max token length of responses (*note: this may increase the cost of API calls*).
- Use the `-n` or `--no-clip` option to disable storing responses to the clipboard.
- Use the `-v` or `--verbose` option to print the model parameters and message history.

You can combine multiple options using their abbreviated forms following a single hyphen:

```
$ q -p knock knock
Who's there?
$ q apple
Apple who?
$ q orange -vo

MODEL PARAMETERS:
model: gpt-4o
max_tokens: 256
temperature: 0.25
frequency_penalty: 0
presence_penalty: 0
top_p: 1

MESSAGES:
System: You are a helpful and knowledgeable AI assistant.
User: knock knock
Assistant: Who's there?
User: orange
Assistant: Orange who?
```

# Adding Custom Commands

`q` was designed to be easily extensible. To add a custom command in the script, simply add a new dictionary entry to the `COMMANDS` list with the following keys:
- `flags` *(required)*: a list of flags to invoke the command.
- `description` *(required)*: a brief description of the command.
- `messages` *(required)*: the instructions sent to the LLM, using `{text}` as a placeholder for the input text.
- `model_args` *(optional)*: override default model arguments set in `DEFAULT_MODEL_ARGS`.

Refer to the existing commands in the script for examples. And use `q` to help!
