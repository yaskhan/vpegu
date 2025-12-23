// parser.v - Packrat PEG parser with memoization
//
// Implements the core Packrat parsing algorithm with memoization.
// Parses PEG grammar text into an AST using the grammar and actions modules.
//
// Author: VPEGU Team
// 
module parser

import grammar
import actions
import lexer

// Memoization key: (rule_name, position)
type MemoKey = string

// ParserState represents the state of parsing at a given position
pub struct ParserState {
pub:
    success bool
    pos     int
    result  grammar.Expression
}

// Parser implements Packrat parsing with memoization
pub struct Parser {
mut:
    input   string
    tokens  []lexer.Token
    pos     int
    peg     actions.Peg
    memo    map[MemoKey]ParserState
}

// new_parser creates a new parser instance
pub fn new_parser() Parser {
    return Parser{
        input: ""
        tokens: []
        pos: 0
        peg: actions.new_peg()
        memo: {}
    }
}

// parse parses a PEG grammar string into a Tree
pub fn (mut p Parser) parse(input string) !grammar.Tree {
    p.input = input
    p.pos = 0
    p.peg.reset()
    p.memo.clear()
    
    // Tokenize input
    mut lexer1 := lexer.new_lexer(input)
    p.tokens = lexer1.tokenize_all()
    
    // Parse grammar
    p.parse_grammar()!
    
    return p.peg.get_tree()
}

// parse_grammar parses the complete grammar
fn (mut p Parser) parse_grammar() ! {
    for p.pos < p.tokens.len {
        token := p.tokens[p.pos]
        
        match token.type {
            .comment {
                p.peg.add_comment(token.value)
                p.pos++
            }
            .package {
                p.parse_package()!
            }
            .import_kw {
                p.parse_import()!
            }
            .type_kw {
                p.parse_type()!
            }
            .identifier {
                p.parse_rule()!
            }
            .newline, .space {
                p.pos++
            }
            .eof {
                break
            }
            else {
                // Skip unexpected tokens
                p.pos++
            }
        }
    }
}

// parse_package parses: package <name>
fn (mut p Parser) parse_package() ! {
    p.pos++ // skip 'package'
    
    if p.pos >= p.tokens.len || p.tokens[p.pos].type != .identifier {
        return error("Expected identifier after 'package'")
    }
    
    name := p.tokens[p.pos].value
    p.peg.add_package(name)
    p.pos++
}

// parse_import parses: import "path"
fn (mut p Parser) parse_import() ! {
    p.pos++ // skip 'import'
    
    // Skip whitespace/newlines
    for p.pos < p.tokens.len && (p.tokens[p.pos].type == .newline || p.tokens[p.pos].type == .space) {
        p.pos++
    }
    
    if p.pos >= p.tokens.len {
        return error("Expected import path")
    }
    
    token := p.tokens[p.pos]
    if token.type == .literal_double || token.type == .literal_single {
        p.peg.add_import(token.value)
        p.pos++
    } else {
        return error("Expected string literal after 'import'")
    }
}

// parse_type parses: type <name> Peg
fn (mut p Parser) parse_type() ! {
    p.pos++ // skip 'type'
    
    if p.pos >= p.tokens.len || p.tokens[p.pos].type != .identifier {
        return error("Expected identifier after 'type'")
    }
    
    name := p.tokens[p.pos].value
    p.pos++
    
    if p.pos >= p.tokens.len || p.tokens[p.pos].type != .peg_kw {
        return error("Expected 'Peg' after type name")
    }
    
    p.peg.add_peg(name)
    p.pos++
}

// parse_rule parses: <name> <- <expression>
fn (mut p Parser) parse_rule() ! {
    name := p.tokens[p.pos].value
    p.pos++
    
    if p.pos >= p.tokens.len || p.tokens[p.pos].type != .arrow {
        return error("Expected '<-' after rule name")
    }
    
    p.pos++ // skip arrow
    
    // Parse expression
    expr := p.parse_expression()!
    
    p.peg.add_rule(name, expr)
}

// parse_expression parses an expression (handles alternates)
fn (mut p Parser) parse_expression() !grammar.Expression {
    mut items := []grammar.Expression{}
    
    // Parse first sequence
    seq := p.parse_sequence()!
    items << seq
    
    // Check for alternates
    for p.pos < p.tokens.len && p.tokens[p.pos].type == .slash {
        p.pos++ // skip /
        next_seq := p.parse_sequence()!
        items << next_seq
    }
    
    if items.len == 1 {
        return items[0]
    }
    return p.peg.add_alternate(items)
}

// parse_sequence parses a sequence of primaries
fn (mut p Parser) parse_sequence() !grammar.Expression {
    mut items := []grammar.Expression{}
    
    for p.pos < p.tokens.len {
        token := p.tokens[p.pos]
        
        // Stop at tokens that end a sequence
        match token.type {
            .slash, .newline, .eof, .rbrace, .rangle { break }
            else {}
        }
        
        primary := p.parse_primary()!
        items << primary
    }
    
    if items.len == 0 {
        return error("Expected expression")
    }
    if items.len == 1 {
        return items[0]
    }
    return p.peg.add_sequence(items)
}

// parse_primary parses a primary expression (atoms, prefixes, suffixes)
fn (mut p Parser) parse_primary() !grammar.Expression {
    if p.pos >= p.tokens.len {
        return error("Unexpected end of input")
    }
    
    token := p.tokens[p.pos]
    
    // Handle prefixes
    match token.type {
        .ampersand {
            p.pos++
            expr := p.parse_primary()!
            return p.peg.add_peek_for(expr)
        }
        .exclamation {
            p.pos++
            expr := p.parse_primary()!
            return p.peg.add_peek_not(expr)
        }
        else {}
    }
    
    // Handle atoms
    mut atom := p.parse_atom()!
    
    // Handle suffixes
    for p.pos < p.tokens.len {
        suffix_token := p.tokens[p.pos]
        
        match suffix_token.type {
            .question {
                atom = p.peg.add_query(atom)
                p.pos++
            }
            .star {
                atom = p.peg.add_star(atom)
                p.pos++
            }
            .plus {
                atom = p.peg.add_plus(atom)
                p.pos++
            }
            else {
                break
            }
        }
    }
    
    return atom
}

// parse_atom parses an atomic expression
fn (mut p Parser) parse_atom() !grammar.Expression {
    if p.pos >= p.tokens.len {
        return error("Expected atom")
    }
    
    token := p.tokens[p.pos]
    
    match token.type {
        .identifier {
            p.pos++
            return p.peg.add_name(token.value)
        }
        .literal_single, .literal_double {
            p.pos++
            return p.peg.add_literal(token.value)
        }
        .character_class {
            p.pos++
            return p.peg.add_character_class(token.value)
        }
        .dot {
            p.pos++
            return p.peg.add_dot()
        }
        .lbrace {
            p.pos++
            // The value contains the action body
            expr := p.peg.add_action(token.value)
            // Skip closing brace if present
            if p.pos < p.tokens.len && p.tokens[p.pos].type == .rbrace {
                p.pos++
            }
            return expr
        }
        .langle {
            p.pos++
            // Parse push expression
            expr := p.parse_expression()!
            // Skip closing angle
            if p.pos < p.tokens.len && p.tokens[p.pos].type == .rangle {
                p.pos++
            }
            return p.peg.add_push(expr)
        }
        .lparen {
            p.pos++
            expr := p.parse_expression()!
            if p.pos >= p.tokens.len || p.tokens[p.pos].type != .rparen {
                return error("Expected ')'")
            }
            p.pos++
            return expr
        }
        else {
            return error("Unexpected token: ${token.type}")
        }
    }
}

// parse_with_memo parses a rule with memoization (Packrat)
fn (mut p Parser) parse_with_memo(rule_name string, start_pos int) !(bool, int, grammar.Expression) {
    key := "${rule_name}:${start_pos}"
    
    // Check memoization cache
    if key in p.memo {
        state := p.memo[key]
        if state.success {
            return true, state.pos, state.result
        } else {
            return false, state.pos, grammar.Expression{}
        }
    }
    
    // Save current state
    old_pos := p.pos
    p.pos = start_pos
    
    // Parse the rule
    mut success := false
    mut new_pos := start_pos
    mut result := grammar.Expression{}
    
    match rule_name {
        "Expression" {
            result = p.parse_expression()!
            success = true
            new_pos = p.pos
        }
        "Sequence" {
            result = p.parse_sequence()!
            success = true
            new_pos = p.pos
        }
        "Primary" {
            result = p.parse_primary()!
            success = true
            new_pos = p.pos
        }
        "Atom" {
            result = p.parse_atom()!
            success = true
            new_pos = p.pos
        }
        else {
            // Unknown rule - restore and fail
            p.pos = old_pos
            return false, start_pos, grammar.Expression{}
        }
    }
    
    // Store in memoization cache
    p.memo[key] = ParserState{
        success: success
        pos: new_pos
        result: result
    }
    
    if success {
        return true, new_pos, result
    } else {
        return false, start_pos, grammar.Expression{}
    }
}

// current_token returns the current token
fn (p &Parser) current_token() lexer.Token {
    if p.pos >= p.tokens.len {
        return lexer.Token{type: .eof, value: "", line: 0, column: 0}
    }
    return p.tokens[p.pos]
}

// skip_whitespace skips whitespace tokens
fn (mut p Parser) skip_whitespace() {
    for p.pos < p.tokens.len {
        token := p.tokens[p.pos]
        if token.type == .space || token.type == .newline {
            p.pos++
        } else {
            break
        }
    }
}