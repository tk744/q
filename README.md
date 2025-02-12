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

- `q` stores the output to the clipboard so you can paste it wherever you need it. This only works on non-headless environments (no VMs and Docker containers). Check [here](https://pyperclip.readthedocs.io/en/latest/index.html#not-implemented-error) if it doesn't.

## Commands

- Generate Bash commands using the `-b` or `--bash` command:

    ```
    $ q -b add the file run.py to the previous commit
    git add run.py && git commit --amend --no-edit
    ```

- Generate Python code using the `-p` or `--python` command:

    <!-- ```
    $ q -p fib function as a lambda
    fib = lambda n, a=0, b=1: a if n == 0 else fib(n-1, b, a+b)
    ``` -->

    ```
    $ q -p take user input and copy to clipboard
    import pyperclip

    def main():
        user_input = input("Enter text to copy to clipboard: ")
        pyperclip.copy(user_input)
        print("Text copied to clipboard.")

    if __name__ == "__main__":
        main()
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

<!-- - Write a professional workplace message using the `-w` or `--workplace` command:

    ```
    $ q -w tell my manager he sucks at his job
    I have some concerns about certain aspects of our workflow and would appreciate discussing ways we can improve our processes. Could we schedule a time to talk about this?
    ``` -->

- Prompt a regular language model using the `-c` or `--chat` command:

    ```
    $ q -c give me a punchline without the setup
    "…and that's why you never trust a penguin with your ice cream!"
    ```

## Follow-up Interactions

Omitting a command enables chatting about the previous response, which allows for many useful follow-up interactions.

- Iterative refinement:

    ```
    $ q -b get cuda version
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

- Ask for explanations:

    ```
    $ ./q -p function to merge two dictionaries x and y
    def merge_dictionaries(x, y):
        return {**x, **y}
    $ ./q what does '**' do
    In Python, the `**` operator is used to unpack dictionaries. When used in the context of merging dictionaries, `**` allows you to unpack the key-value pairs of a dictionary into another dictionary. This ...
    ```

## Options

Options are boolean flags that modify the behavior of `q`. Combine options using their abbreviated form after a single hyphen. (e.g. `-nv`).

- Increase the max token length of responses using the `-l` or `--longer` option.

- Disable storing responses to the clipboard using the `-n` or `--no-clipboard` option.

- Print the message and response history using the `-v` or `--verbose` option.

# Adding Custom Commands

`q` was designed to be easily extensible. To add a custom command, simply add a new entry to the `COMMANDS` list in the script. Each entry is a dictionary with the following keys:
- `flags` *(required)*: A list of flags to invoke the command.
- `description` *(required)*: A brief description of the command.
- `messages` *(required)*: The prompts sent to the LLM, using `{text}` as a placeholder for the input text.
- `model` *(optional)*: Override the default model set in `DEFAULT_MODEL`.
- `model_args` *(optional)*: Override the default model arguments set in `DEFAULT_LLM_ARGS`.

Refer to the existing commands in the script for examples.