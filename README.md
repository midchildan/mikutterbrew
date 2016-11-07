# mikutterbrew

Script to update the mikutter formula for Homebrew.

## Features

- Checks if the local installation of mikutter is up to date
- Generates a new formula if outdated

## Requirements

- macOS (Tested on Sierra)
- ruby
- rubygems

## Installation

run `git clone https://github.com/midchildan/mikutterbrew.git`

## Usage

### `mikutterbrew init`

Download dependencies needed to run mikutterbrew.

### `mikutterbrew [formula_path]`

Check for updates, and generate a new formula if outdated. If formula path isn't given, mikutterbrew will use `$(brew --repo homebrew/gui)/mikutter.rb` .

## License

mikutterbrew is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
