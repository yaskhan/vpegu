// lexer.v - Tokenizer for PEG grammar files
//
// Provides lexical analysis for PEG grammar syntax.
// Converts raw text input into tokens that can be parsed.
//
// Author: VPEGU Team
// 
module lexer

// TokenType represents the different types of tokens
pub enum TokenType {
    identifier
    literal_single    // '...'
    literal_double    // "..."
    arrow            // <- or ←
    slash            // /
    ampersand        // &
    exclamation      // !
    question         // ?
    star             // *
    plus             // +
    dot              // .
    lparen           // (
    rparen           // )
    lbracket         // [
    rbracket         // ]
    llbracket        // [[
    rrbracket        // ]]
    lbrace           // {
    rbrace           // }
    langle           // <
    rangle           // >
    backslash        // \
    character_class  // [a-z] or [[a-z\.]]
    package          // package keyword
    import_kw        // import keyword
    type_kw          // type keyword
    peg_kw           // Peg keyword
    comment          // # comment
    space            // whitespace
    newline          // \n
    eof              // end of file
    unknown          // unknown token
}

// Token represents a single lexical token
pub struct Token {
pub:
    type TokenType
    value string
    line int
    column int
}

// Lexer performs lexical analysis on PEG grammar input
pub struct Lexer {
	mut:
    input string
    pos   int
    line  int
    col   int
}

// new_lexer creates a new lexer instance
pub fn new_lexer(input string) Lexer {
    return Lexer{
        input: input
        pos: 0
        line: 1
        col: 1
    }
}

// peek returns the character at current position without advancing
pub fn (l &Lexer) peek() string {
    if l.pos >= l.input.len {
        return ''
    }
    return l.input[l.pos].str()
}

// peek_n returns the character n positions ahead
pub fn (l &Lexer) peek_n(n int) string {
    pos := l.pos + n
    if pos >= l.input.len {
        return ''
    }
    return l.input[pos].str()
}

// advance moves the position forward by one character
pub fn (mut l Lexer) advance() {
    if l.pos >= l.input.len {
        return
    }
    
    if l.input[l.pos] == `\n` {
        l.line++
        l.col = 1
    } else {
        l.col++
    }
    l.pos++
}

// skip_whitespace skips whitespace characters
pub fn (mut l Lexer) skip_whitespace() {
    for l.pos < l.input.len {
        c := l.input[l.pos]
        if c == ` ` || c == `\t` || c == `\r` {
            l.advance()
        } else {
            break
        }
    }
}

// skip_comment skips a comment line
pub fn (mut l Lexer) skip_comment() {
    for l.pos < l.input.len && l.input[l.pos] != `\n` {
        l.advance()
    }
}

// scan_identifier scans an identifier (rule name or keyword)
pub fn (mut l Lexer) scan_identifier() string {
    start := l.pos
    for l.pos < l.input.len {
        c := l.input[l.pos]
        if (c >= `a` && c <= `z`) || (c >= `A` && c <= `Z`) || c == `_` || (c >= `0` && c <= `9`) {
            l.advance()
        } else {
            break
        }
    }
    return l.input[start..l.pos]
}

// scan_literal scans a string literal (single or double quoted)
pub fn (mut l Lexer) scan_literal(quote u8) string {
    l.advance() // skip opening quote
    mut result := ""
    
    for l.pos < l.input.len {
        c := l.input[l.pos]
        
        // Check for escape sequence first
        if c == `\\` {
            l.advance() // skip backslash
            if l.pos < l.input.len {
                escape_char := l.input[l.pos]
                l.advance()
                match escape_char {
                    `n` { result += "\n" }
                    `r` { result += "\r" }
                    `t` { result += "\t" }
                    `v` { result += "\v" }
                    `f` { result += "\f" }
                    `b` { result += "\b" }
                    `a` { result += "\a" }
                    `e` { result += "\x1b" }
                    `\\` { result += "\\" }
                    `\'` { result += "'" }
                    `\"` { result += "\"" }
                    else { result += [escape_char].bytestr() }
                }
            }
            continue
        }
        
        // Check for closing quote
        if c == quote {
            l.advance() // skip closing quote
            return result
        }
        
        // Regular character
        result += [c].bytestr()
        l.advance()
    }
    
    // Unclosed literal
    return result
}

// scan_character_class scans a character class
pub fn (mut l Lexer) scan_character_class() string {
    l.advance() // skip [
    
    // Check for double bracket [[
    mut is_double := false
    if l.peek() == "[" {
        is_double = true
        l.advance() // skip second [
    }
    
    start := l.pos
    mut depth := 1
    
    for l.pos < l.input.len && depth > 0 {
        c := l.input[l.pos]
        if c == `[` {
            depth++
            l.advance()
        } else if c == `]` {
            depth--
            l.advance()
            if depth == 0 {
                if is_double {
                    // Skip the closing ]] for double brackets
                    if l.pos < l.input.len && l.input[l.pos] == `]` {
                        l.advance()
                        // Return content between [[ and ]]
                        return l.input[start..l.pos - 2]
                    }
                }
                // For single brackets, return content between [ and ]
                return l.input[start..l.pos - 1]
            }
        } else {
            l.advance()
        }
    }
    
    return l.input[start..l.pos]
}

// scan_action scans an action block { ... }
pub fn (mut l Lexer) scan_action() string {
    l.advance() // skip {
    start := l.pos
    mut depth := 1
    
    for l.pos < l.input.len && depth > 0 {
        c := l.input[l.pos]
        if c == `{` {
            depth++
            l.advance()
        } else if c == `}` {
            depth--
            l.advance()
            if depth == 0 {
                return l.input[start..l.pos - 1]
            }
        } else {
            l.advance()
        }
    }
    
    return l.input[start..l.pos]
}

// scan_push scans a push expression < ... >
pub fn (mut l Lexer) scan_push() string {
    l.advance() // skip <
    start := l.pos
    mut depth := 1
    
    for l.pos < l.input.len && depth > 0 {
        c := l.input[l.pos]
        if c == `<` {
            depth++
            l.advance()
        } else if c == `>` {
            depth--
            l.advance()
            if depth == 0 {
                return l.input[start..l.pos - 1]
            }
        } else {
            l.advance()
        }
    }
    
    return l.input[start..l.pos]
}

// scan_escape scans an escape sequence
pub fn (mut l Lexer) scan_escape() string {
    l.advance() // skip \
    if l.pos >= l.input.len {
        return ""
    }
    
    c := l.input[l.pos]
    l.advance()
    
    match c {
        `n` { return "\n" }
        `r` { return "\r" }
        `t` { return "\t" }
        `v` { return "\v" }
        `f` { return "\f" }
        `b` { return "\b" }
        `a` { return "\a" }
        `e` { return "\x1b" }
        `\\` { return "\\" }
        `\'` { return "'" }
        `\"` { return "\"" }
        `[` { return "[" }
        `]` { return "]" }
        `-` { return "-" }
        `x` {
            // Hex escape \xHH
            if l.pos + 2 < l.input.len {
                hex := l.input[l.pos..l.pos+2]
                l.pos += 2
                // Convert hex to char (simplified)
                return hex
            }
            return ""
        }
        else {
            // Octal escape \ooo (1-3 digits)
            if c >= `0` && c <= `7` {
                mut octal := c.str()
                // Read up to 2 more digits
                for i := 0; i < 2 && l.pos < l.input.len; i++ {
                    if l.input[l.pos] >= `0` && l.input[l.pos] <= `7` {
                        octal += l.input[l.pos].str()
                        l.advance()
                    } else {
                        break
                    }
                }
                return octal
            }
            return c.str()
        }
    }
}

// next_token returns the next token from the input
pub fn (mut l Lexer) next_token() Token {
    l.skip_whitespace()
    
    if l.pos >= l.input.len {
        return Token{type: .eof, value: "", line: l.line, column: l.col}
    }
    
    start_line := l.line
    start_col := l.col
    c := l.input[l.pos]
    
    // Comments
    if c == `#` {
        l.skip_comment()
        return Token{type: .comment, value: "", line: start_line, column: start_col}
    }
    
    // Newline
    if c == `\n` {
        l.advance()
        return Token{type: .newline, value: "\n", line: start_line, column: start_col}
    }
    
    // Literals
    if c == `'` {
        value := l.scan_literal(`'`)
        return Token{type: .literal_single, value: value, line: start_line, column: start_col}
    }
    if c == `"` {
        value := l.scan_literal(`"`)
        return Token{type: .literal_double, value: value, line: start_line, column: start_col}
    }
    
    // Character class
    if c == `[` {
        value := l.scan_character_class()
        return Token{type: .character_class, value: value, line: start_line, column: start_col}
    }
    
    // Action block
    if c == `{` {
        value := l.scan_action()
        return Token{type: .lbrace, value: value, line: start_line, column: start_col}
    }
    
    // Arrow (must be checked before push expression)
    if c == `<` && l.pos + 1 < l.input.len && l.input[l.pos + 1] == `-` {
        l.advance()
        l.advance()
        return Token{type: .arrow, value: "<-", line: start_line, column: start_col}
    }
    
    // Push expression
    if c == `<` {
        // Check if it's the start of a push
        if l.pos + 1 < l.input.len && l.input[l.pos + 1] != `<` { // Not a comment
            l.advance()
            return Token{type: .langle, value: "<", line: start_line, column: start_col}
        }
    }
    
    // Single character tokens
    match c {
        `/` { l.advance(); return Token{type: .slash, value: "/", line: start_line, column: start_col} }
        `&` { l.advance(); return Token{type: .ampersand, value: "&", line: start_line, column: start_col} }
        `!` { l.advance(); return Token{type: .exclamation, value: "!", line: start_line, column: start_col} }
        `?` { l.advance(); return Token{type: .question, value: "?", line: start_line, column: start_col} }
        `*` { l.advance(); return Token{type: .star, value: "*", line: start_line, column: start_col} }
        `+` { l.advance(); return Token{type: .plus, value: "+", line: start_line, column: start_col} }
        `.` { l.advance(); return Token{type: .dot, value: ".", line: start_line, column: start_col} }
        `(` { l.advance(); return Token{type: .lparen, value: "(", line: start_line, column: start_col} }
        `)` { l.advance(); return Token{type: .rparen, value: ")", line: start_line, column: start_col} }
        `>` { l.advance(); return Token{type: .rangle, value: ">", line: start_line, column: start_col} }
        `\\` {
            value := l.scan_escape()
            return Token{type: .literal_single, value: value, line: start_line, column: start_col}
        }
        else {}
    }
    
    // Identifier or keyword
    if (c >= `a` && c <= `z`) || (c >= `A` && c <= `Z`) || c == `_` {
        value := l.scan_identifier()
        
        // Check for keywords
        match value {
            "package" { return Token{type: .package, value: value, line: start_line, column: start_col} }
            "import" { return Token{type: .import_kw, value: value, line: start_line, column: start_col} }
            "type" { return Token{type: .type_kw, value: value, line: start_line, column: start_col} }
            "Peg" { return Token{type: .peg_kw, value: value, line: start_line, column: start_col} }
            else { return Token{type: .identifier, value: value, line: start_line, column: start_col} }
        }
    }
    
    // Unknown token
    l.advance()
    return Token{type: .unknown, value: c.str(), line: start_line, column: start_col}
}

// tokenize_all returns all tokens from the input
pub fn (mut l Lexer) tokenize_all() []Token {
    mut tokens := []Token{}
    for {
        token := l.next_token()
        tokens << token
        if token.type == .eof {
            break
        }
    }
    return tokens
}