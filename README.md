# Overview
`q` is an LLM-powered copilot for the command line, designed to keep programers in the terminal and reduce time spent looking things up. It can generate shell commands, write Python scripts, construct regex patterns, and more, all from the comfort of your command line.

# Installation

- Install Python 3 and the following dependencies:

    ```
    pip install openai pyperclip termcolor
    ```

- Download the script to a directory in your path (e.g. `~/.local/bin/`) and make it executable:

    ```
    wget -qO ~/.local/bin/q https://raw.githubusercontent.com/tk744/q/refs/heads/master/q && chmod +x ~/.local/bin/q
    ```

- The first time `q` is run, you will be prompted for an OpenAI API key which you can create [here](https://platform.openai.com/api-keys).

# Usage

- Below is the basic syntax for using `q`. For a full list of commands and options, run `q -h`.

    ```
    q [command] TEXT [options]
    ```

- `q` stores the output to the clipboard so you can paste it wherever you need it. This only works on non-headless environments (no VMs and Docker containers), check [here](https://pyperclip.readthedocs.io/en/latest/index.html#not-implemented-error) if it doesn't.

## Commands

- Generate code using the `-c` or `--code` command (assumes Python unless specified):

    ```
    $ q -c copy user input to clipboard
    import pyperclip

    user_input = input("Enter text to copy to clipboard: ")
    pyperclip.copy(user_input)
    ```

- Generate shell commands using the `-s` or `--shell` command (assumes Linux Bash unless specified):

    ```
    $ q -s add run.py to prev commit
    git add run.py && git commit --amend --no-edit
    ```

- Generate regex patterns using the `-x` or `--regex` command:

    ```
    $ q -x extract domain name from url
    `(?:(?:https?://)?(?:www\.)?([^/]+))`
    ```

- Rephrase text for improved fluency using the `-r` or `--rephrase` command:

    ```
    $ q -r watchin haters wonder why gambino got the game locked
    Watching critics wonder why Gambino dominates the game.
    ```

- Prompt a regular language model using the `-p` or `--prompt` command:

    ```
    $ q -p give me a punchline without the setup
    "…and that's why you never trust a penguin with your ice cream!"
    ```

## Follow-up Commands

`q` allows you to build on previous responses by prompting it without an explicit command. This enables many useful follow-up interactions.

- Interactive debugging:

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

- Asking for explanations:

    ```
    $ q -c function to merge two dictionaries x and y
    def merge_dictionaries(x, y):
        return {**x, **y}
    $ q what does '**' do
    In Python, the `**` operator is used to unpack dictionaries. When used in the context of merging dictionaries, `**` allows you to unpack the key-value pairs of a dictionary into another dictionary. This ...
    ```

## Options

Options are boolean flags that modify the behavior of `q`. They can be combined using their abbreviated forms following a single hyphen. (e.g. `-vo`).

- Overwrite the previous follow-up command using the `-o` or `--overwrite` option.

- Increase the max token length of responses using the `-l` or `--longer` option. *Note: this may increase the cost of API calls.*

- Disable storing responses to the clipboard using the `-n` or `--no-clip` option.

- Print the model parameters and message history using the `-v` or `--verbose` option.


# Adding Custom Commands

`q` was designed to be easily extensible. To add a custom command, simply add a new entry to the `COMMANDS` list in the script. Each entry is a dictionary with the following keys:
- `flags` *(required)*: a list of flags to invoke the command.
- `description` *(required)*: a brief description of the command.
- `messages` *(required)*: the instructions sent to the LLM, using `{text}` as a placeholder for the input text.
- `model_args` *(optional)*: override default model arguments set in `DEFAULT_MODEL_ARGS`.

Refer to the existing commands in the script for examples.