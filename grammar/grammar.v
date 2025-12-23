// grammar.v - Data structures for PEG grammar AST
//
// Defines the core data structures for representing PEG grammars:
// - Tree: Root of the AST containing package, imports, and rules
// - Rule: Individual grammar rule
// - Expression: Expression nodes with various kinds
// - ExprKind: Enumeration of expression types
//
// Author: VPEGU Team
// 
module grammar

// Tree represents the abstract syntax tree of a PEG grammar
pub struct Tree {
pub mut:
    package_name string
    imports      []string
    peg_name     string
    rules        []Rule
    comments     []string
    spaces       []string
}

// Rule represents a single grammar rule
pub struct Rule {
pub:
    name string
    expr Expression
}

// Expression represents a node in the expression tree
pub struct Expression {
pub:
    kind   ExprKind
    items  []Expression
    value  string // for literals, names, actions, character classes
}

// ExprKind enumerates all possible expression types
pub enum ExprKind {
    sequence      // e1 e2 e3
    alternate     // e1 / e2 / e3
    peek_for      // &e
    peek_not      // !e
    query         // e?
    star          // e*
    plus          // e+
    name          // rule_name
    literal       // "..." or '...'
    character_class // [a-z] or [[a-z\.]]
    dot           // .
    action        // { ... }
    push          // <...>
}

// String representation for debugging and JSON serialization
pub fn (ek ExprKind) str() string {
    return match ek {
        .sequence { "sequence" }
        .alternate { "alternate" }
        .peek_for { "peek_for" }
        .peek_not { "peek_not" }
        .query { "query" }
        .star { "star" }
        .plus { "plus" }
        .name { "name" }
        .literal { "literal" }
        .character_class { "character_class" }
        .dot { "dot" }
        .action { "action" }
        .push { "push" }
    }
}

// Helper function to create a simple expression
pub fn create_expr(kind ExprKind, value string) Expression {
    return Expression{
        kind: kind
        items: []
        value: value
    }
}

// Helper function to create a composite expression
pub fn create_composite_expr(kind ExprKind, items []Expression) Expression {
    return Expression{
        kind: kind
        items: items
        value: ""
    }
}

// Helper function to create a rule
pub fn create_rule(name string, expr Expression) Rule {
    return Rule{
        name: name
        expr: expr
    }
}

// Helper function to create a tree
pub fn create_tree() Tree {
    return Tree{
        package_name: ""
        imports: []
        peg_name: ""
        rules: []
        comments: []
        spaces: []
    }
}