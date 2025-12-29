# VPEGU

VPEGU is a Packrat PEG parser generator for the V programming language.

## Features

- Full PEG support (sequences, choices, repetitions, predicates)
- Packrat parsing with memoization for O(n) time complexity
- Generator that produces standalone V code for your parser
- Support for semantic actions

## Installation

```bash
git clone https://github.com/vpegu/vpegu
cd vpegu
v .
```

## Usage

### Define your grammar

Create a `.peg` file, for example `arithmetic.peg`:

```peg
Expression <- Term (('+' / '-') Term)*
Term <- Factor (('*' / '/') Factor)*
Factor <- Number / '(' Expression ')'
Number <- [0-9]+
```

### Generate a parser

```bash
vpegu arithmetic.peg --output parser.v
```

### Use the generated parser

```v
import os

fn main() {
    input := "1+2*3"
    mut p := PackratParser{input: input}
    result := p.parse()
    if result.success {
        println("Parsed successfully!")
    } else {
        println("Parse failed")
    }
}
```

## License

MIT
