# Pearl VS Code Extension

We recommend using the pearl-vscode extension for verification support.

## Installation

The Pearl VS Code Extension extension will soon be available on the VS Code marketplace. Simply search for `bbentzen.pearl-vscode` on the VS Code Extensions view and click on the Install buttom. Alternativelly, you can install the extension manually from source. To do this, assuming you have already cloned the pearl repository, you can run:

```
$ cd vscode
$ npm install
$ npm run compile
```

Now you can copy the folder to `~/.vscode/extensions`.

## Usage

You need a pearl executable. Open any `.prl` file on VS Code. Once you see any highlighted code you can compile the file simply by saving it with `Ctrl+S`.

If you see a message "Pearl binary cannot be located", this is most likely because you need to tell VS Code the exact path to your executable to compile the file. You need to open the Settings editor via File > Preferences > Settings menu or using the `Ctrl+,` shortcut, then and go to Extensions > Pearl Configuration. Under Pearl: Executable Path you should provide the full path of the executable on your computer. For example:

`/home/myusername/pearl/_build/default/bin/main.exe`

### Features

The Pearl VS Code Extension extension supports syntax highlighting, snippet completion, bracket matching, bracket autoclosing, bracket autosurrounding, comment toggling (`Ctrl` + `/`), Go to Definition, and various LaTeX-style abbreviations for Greek letters, letter and numerical super and subscripts, mathematical and logical operators.

## AI Use Disclosure

Parts of this VS Code extension were vibe coded for the sake of convenience. 