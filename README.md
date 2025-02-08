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

- Omit a command to chat about the previous response. This enables may useful follow-up interactions.
- `q` stores each output to the clipboard, so you can paste it wherever you need it.

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
    $ ./q -r The project was delayed due to unexpected issues we hadnt anticipated.
    The project was delayed due to unforeseen issues.
    ```

- Write a professional workplace message using the `-w` or `--workplace` command:

    ```
    $ q -w tell my manager he sucks at his job
    I have some concerns about certain aspects of our workflow and would appreciate discussing ways we can improve our processes. Could we schedule a time to talk about this?
    ```

- Prompt a regular language model using the `-c` or `--chat` command:

    ```
    $ q -c give me a punchline without the setup
    "That's why you never trust a ladder—it’s always up to something!"
    ```

## Follow-up Interactions

- Fix errors and add context:

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