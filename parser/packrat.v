module parser

import lexer
import actions
import grammar

// PackratMemoizationCache stores memoized parse results for Packrat parsing
pub struct PackratMemoizationCache {
mut:
	// Key: rule_name + position, Value: ParseResult
	cache map[string]ParseResult
}

// PackratParser generates and executes Packrat parsers with memoization
pub struct PackratParser {
pub mut:
	grammar    grammar.Tree
	lexer      lexer.Lexer
	memo_cache PackratMemoizationCache
	actions    actions.ActionExecutor
}

// ParseResult represents the result of a parsing operation
pub struct ParseResult {
pub:
	success      bool
	value        actions.ActionValue
	end_position int
}

// new_packrat_parser creates a new Packrat parser from a grammar
pub fn new_packrat_parser(g grammar.Tree) &PackratParser {
	return &PackratParser{
		grammar:    g
		lexer:      lexer.new_lexer('')
		memo_cache: PackratMemoizationCache{}
		actions:    actions.new_action_executor()
	}
}

// parse parses input using the Packrat algorithm
pub fn (mut p PackratParser) parse(input string) !actions.ActionValue {
	p.lexer = lexer.new_lexer(input)
	p.memo_cache.cache.clear()

	// Find the start rule
	if p.grammar.rules.len == 0 {
		return error('No rules found in grammar')
	}
	start_rule := p.grammar.rules[0]

	result := p.parse_rule(start_rule.name, 0)

	if !result.success {
		return error('Parse failed at position ${result.end_position}')
	}

	return result.value
}

// parse_rule implements the core Packrat parsing with memoization
fn (mut p PackratParser) parse_rule(rule_name string, position int) ParseResult {
	// Create cache key
	cache_key := '${rule_name}_${position}'

	// Check memoization cache
	if cache_key in p.memo_cache.cache {
		return p.memo_cache.cache[cache_key]
	}

	// Find the rule
	mut found_rule := grammar.Rule{}
	mut found := false
	for rule in p.grammar.rules {
		if rule.name == rule_name {
			found_rule = rule
			found = true
			break
		}
	}
	if !found {
		return ParseResult{false, actions.ActionValue{}, position}
	}

	// Parse the rule's expression
	result := p.parse_expression(found_rule.expr, position)

	// Memoize the result
	p.memo_cache.cache[cache_key] = result

	return result
}

// parse_expression parses an expression starting at position
fn (mut p PackratParser) parse_expression(expr grammar.Expression, position int) ParseResult {
	match expr.kind {
		.sequence {
			return p.parse_sequence(expr, position)
		}
		.alternate {
			return p.parse_choice(expr, position)
		}
		.star, .plus, .query {
			return p.parse_repetition(expr, position)
		}
		.peek_for, .peek_not {
			return p.parse_predicate(expr, position)
		}
		.name {
			return p.parse_rule(expr.value, position)
		}
		.literal {
			return p.parse_literal(expr, position)
		}
		.character_class {
			return p.parse_character_class(expr, position)
		}
		.dot {
			return p.parse_dot(position)
		}
		.action {
			return p.parse_semantic_action(expr, position)
		}
		else {
			return ParseResult{false, actions.ActionValue{}, position}
		}
	}
}

// parse_sequence parses a sequence of expressions
fn (mut p PackratParser) parse_sequence(expr grammar.Expression, position int) ParseResult {
	mut current_pos := position
	mut values := []actions.ActionValue{}

	for sub_expr in expr.items {
		result := p.parse_expression(sub_expr, current_pos)

		if !result.success {
			return ParseResult{false, actions.ActionValue{}, position}
		}

		if result.value.kind != .void_kind {
			values << result.value
		}

		current_pos = result.end_position
	}

	// Combine values if needed
	mut final_value := actions.ActionValue{}
	if values.len == 1 {
		final_value = values[0]
	} else if values.len > 1 {
		final_value = actions.new_array_value(values)
	}

	return ParseResult{true, final_value, current_pos}
}

// parse_choice parses alternatives (first match wins)
fn (mut p PackratParser) parse_choice(expr grammar.Expression, position int) ParseResult {
	for sub_expr in expr.items {
		result := p.parse_expression(sub_expr, position)
		if result.success {
			return result
		}
	}

	return ParseResult{false, actions.ActionValue{}, position}
}

// parse_repetition parses repetition operators
fn (mut p PackratParser) parse_repetition(expr grammar.Expression, position int) ParseResult {
	mut current_pos := position
	mut values := []actions.ActionValue{}
	min_count := match expr.kind {
		.star { 0 }
		.plus { 1 }
		.query { 0 }
		else { 0 }
	}
	max_count := match expr.kind {
		.query { 1 }
		else { -1 } // unlimited
	}

	mut count := 0
	for {
		if max_count != -1 && count >= max_count {
			break
		}

		if expr.items.len == 0 {
			break
		}
		result := p.parse_expression(expr.items[0], current_pos)
		if !result.success {
			break
		}

		if result.value.kind != .void_kind {
			values << result.value
		}

		current_pos = result.end_position
		count++

		// Prevent infinite loops
		if current_pos == position && count > 1000 {
			break
		}
	}

	if count < min_count {
		return ParseResult{false, actions.ActionValue{}, position}
	}

	// Handle repetition results
	mut final_value := actions.ActionValue{}
	if values.len == 0 {
		final_value = actions.new_array_value([])
	} else if values.len == 1 && expr.kind == .query {
		final_value = values[0]
	} else {
		final_value = actions.new_array_value(values)
	}

	return ParseResult{true, final_value, current_pos}
}

// parse_predicate parses lookahead predicates
fn (mut p PackratParser) parse_predicate(expr grammar.Expression, position int) ParseResult {
	is_and := expr.kind == .peek_for

	if expr.items.len == 0 {
		return ParseResult{false, actions.ActionValue{}, position}
	}
	result := p.parse_expression(expr.items[0], position)

	if is_and {
		// AND predicate: succeeds if expression matches, doesn't consume input
		if result.success {
			return ParseResult{true, actions.ActionValue{}, position}
		}
	} else {
		// NOT predicate: succeeds if expression doesn't match
		if !result.success {
			return ParseResult{true, actions.ActionValue{}, position}
		}
	}

	return ParseResult{false, actions.ActionValue{}, position}
}

// parse_literal parses literal strings
fn (mut p PackratParser) parse_literal(expr grammar.Expression, position int) ParseResult {
	literal := expr.value

	// Check if we have enough input
	if position + literal.len > p.lexer.input.len {
		return ParseResult{false, actions.ActionValue{}, position}
	}

	// Match literal
	matched := p.lexer.input[position..position + literal.len] == literal

	if matched {
		value := actions.new_string_value(literal)
		return ParseResult{true, value, position + literal.len}
	}

	return ParseResult{false, actions.ActionValue{}, position}
}

// parse_character_class parses character classes
fn (mut p PackratParser) parse_character_class(expr grammar.Expression, position int) ParseResult {
	if position >= p.lexer.input.len {
		return ParseResult{false, actions.ActionValue{}, position}
	}

	c := p.lexer.input[position]
	// Pattern is in expr.value, e.g. "[a-z]"
	// Simple implementation for now: just check if char is in the pattern
	// In a real implementation, we would parse the character class pattern
	pattern := expr.value
	if pattern.len >= 3 && pattern.starts_with('[') && pattern.ends_with(']') {
		inner := pattern[1..pattern.len - 1]
		if inner.contains('-') && inner.len == 3 {
			start := inner[0]
			end := inner[2]
			if c >= start && c <= end {
				return ParseResult{true, actions.new_string_value(c.str()), position + 1}
			}
		} else if inner.contains(c.str()) {
			return ParseResult{true, actions.new_string_value(c.str()), position + 1}
		}
	}

	return ParseResult{false, actions.ActionValue{}, position}
}

// parse_dot parses any character
fn (mut p PackratParser) parse_dot(position int) ParseResult {
	if position >= p.lexer.input.len {
		return ParseResult{false, actions.ActionValue{}, position}
	}
	return ParseResult{true, actions.new_string_value(p.lexer.input[position..position + 1]),
		position + 1}
}

// parse_semantic_action executes user-defined actions
fn (mut p PackratParser) parse_semantic_action(expr grammar.Expression, position int) ParseResult {
	// First parse the inner expression if any
	mut current_pos := position
	mut val := actions.ActionValue{}

	if expr.items.len > 0 {
		result := p.parse_expression(expr.items[0], position)
		if !result.success {
			return result
		}
		val = result.value
		current_pos = result.end_position
	}

	// Execute the semantic action
	mut context := actions.new_action_context()
	context.set_value('result', val)

	// Execute action code
	action_result := p.actions.execute(expr.value, context) or {
		return ParseResult{false, actions.ActionValue{}, position}
	}

	return ParseResult{true, action_result, current_pos}
}
