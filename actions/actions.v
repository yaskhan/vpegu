// actions.v - PEG grammar builder with semantic actions
//
// Implements the Peg struct with methods to build up the grammar tree
// from parsed tokens. Each add_* method corresponds to a semantic action
// that mutates the internal tree structure.
//
// Author: VPEGU Team
//
module actions

import grammar

// ActionValue represents a value returned by a semantic action
pub enum ActionValueKind {
	void_kind
	string_kind
	array_kind
	int_kind
}

pub struct ActionValue {
pub:
	kind    ActionValueKind
	str_val string
	int_val int
	arr_val []ActionValue
}

pub fn (av ActionValue) str() string {
	match av.kind {
		.void_kind { return 'void' }
		.string_kind { return av.str_val }
		.int_kind { return av.int_val.str() }
		.array_kind { return '[' + av.arr_val.map(it.str()).join(', ') + ']' }
	}
}

pub fn (av ActionValue) type_of() ActionValueKind {
	return av.kind
}

pub fn new_void_value() ActionValue {
	return ActionValue{
		kind: .void_kind
	}
}

pub fn new_string_value(val string) ActionValue {
	return ActionValue{
		kind:    .string_kind
		str_val: val
	}
}

pub fn new_int_value(val int) ActionValue {
	return ActionValue{
		kind:    .int_kind
		int_val: val
	}
}

pub fn new_array_value(val []ActionValue) ActionValue {
	return ActionValue{
		kind:    .array_kind
		arr_val: val
	}
}

// ActionContext provides context for semantic actions
pub struct ActionContext {
mut:
	values map[string]ActionValue
}

pub fn new_action_context() ActionContext {
	return ActionContext{
		values: {}
	}
}

pub fn (mut c ActionContext) set_value(name string, val ActionValue) {
	c.values[name] = val
}

pub fn (c ActionContext) get_value(name string) ActionValue {
	return c.values[name] or { new_void_value() }
}

// ActionExecutor executes semantic actions
pub struct ActionExecutor {}

pub fn new_action_executor() ActionExecutor {
	return ActionExecutor{}
}

pub fn (ae ActionExecutor) execute(code string, context ActionContext) !ActionValue {
	// Simple implementation: just return the result from context
	// In a real implementation, this would evaluate the V code
	return context.get_value('result')
}

// Peg represents the PEG grammar builder
pub struct Peg {
pub mut:
	tree grammar.Tree
}

// new_peg creates a new Peg instance
pub fn new_peg() Peg {
	return Peg{
		tree: grammar.create_tree()
	}
}

// add_package sets the package name
pub fn (mut p Peg) add_package(name string) {
	p.tree.package_name = name
}

// add_import adds an import path
pub fn (mut p Peg) add_import(path string) {
	p.tree.imports << path
}

// add_peg sets the peg type name
pub fn (mut p Peg) add_peg(name string) {
	p.tree.peg_name = name
}

// add_rule adds a new rule to the tree
// This should be called after building the expression
pub fn (mut p Peg) add_rule(name string, expr grammar.Expression) {
	rule := grammar.create_rule(name, expr)
	p.tree.rules << rule
}

// add_expression creates a new expression node
pub fn (mut p Peg) add_expression() grammar.Expression {
	return grammar.create_expr(.sequence, '')
}

// add_alternate creates an alternate expression
pub fn (mut p Peg) add_alternate(items []grammar.Expression) grammar.Expression {
	return grammar.create_composite_expr(.alternate, items)
}

// add_sequence creates a sequence expression
pub fn (mut p Peg) add_sequence(items []grammar.Expression) grammar.Expression {
	return grammar.create_composite_expr(.sequence, items)
}

// add_peek_for creates a peek-for expression (&e)
pub fn (mut p Peg) add_peek_for(expr grammar.Expression) grammar.Expression {
	return grammar.create_composite_expr(.peek_for, [expr])
}

// add_peek_not creates a peek-not expression (!e)
pub fn (mut p Peg) add_peek_not(expr grammar.Expression) grammar.Expression {
	return grammar.create_composite_expr(.peek_not, [expr])
}

// add_query creates a query expression (e?)
pub fn (mut p Peg) add_query(expr grammar.Expression) grammar.Expression {
	return grammar.create_composite_expr(.query, [expr])
}

// add_star creates a star expression (e*)
pub fn (mut p Peg) add_star(expr grammar.Expression) grammar.Expression {
	return grammar.create_composite_expr(.star, [expr])
}

// add_plus creates a plus expression (e+)
pub fn (mut p Peg) add_plus(expr grammar.Expression) grammar.Expression {
	return grammar.create_composite_expr(.plus, [expr])
}

// add_name creates a name expression (rule reference)
pub fn (mut p Peg) add_name(name string) grammar.Expression {
	return grammar.create_expr(.name, name)
}

// add_literal creates a literal expression
pub fn (mut p Peg) add_literal(value string) grammar.Expression {
	return grammar.create_expr(.literal, value)
}

// add_character_class creates a character class expression
pub fn (mut p Peg) add_character_class(pattern string) grammar.Expression {
	return grammar.create_expr(.character_class, pattern)
}

// add_dot creates a dot expression (.)
pub fn (mut p Peg) add_dot() grammar.Expression {
	return grammar.create_expr(.dot, '')
}

// add_action creates an action expression
pub fn (mut p Peg) add_action(body string) grammar.Expression {
	return grammar.create_expr(.action, body)
}

// add_push creates a push expression (<...>)
pub fn (mut p Peg) add_push(expr grammar.Expression) grammar.Expression {
	return grammar.create_composite_expr(.push, [expr])
}

// add_comment adds a comment to the tree
pub fn (mut p Peg) add_comment(text string) {
	p.tree.comments << text
}

// add_space adds a space to the tree
pub fn (mut p Peg) add_space(text string) {
	p.tree.spaces << text
}

// add_character adds a character (helper for parsing)
pub fn (mut p Peg) add_character(c string) {
	// This is a helper method that might be used during parsing
	// Implementation depends on specific needs
}

// get_tree returns the current tree
pub fn (mut p Peg) get_tree() grammar.Tree {
	return p.tree
}

// reset clears the tree
pub fn (mut p Peg) reset() {
	p.tree = grammar.create_tree()
}
