module parser

import lexer
import actions

// PackratMemoizationCache stores memoized parse results for Packrat parsing
pub struct PackratMemoizationCache {
mut:
	// Key: rule_name + position, Value: ParseResult
	cache map[string]ParseResult
}

// PackratParser generates and executes Packrat parsers with memoization
pub struct PackratParser {
pub:
	grammar     Grammar
	lexer       lexer.Lexer
	memo_cache  PackratMemoizationCache
	actions     actions.ActionExecutor
}

// ParseResult represents the result of a parsing operation
pub struct ParseResult {
pub:
	success     bool
	value       actions.ActionValue
	end_position int
}

// NewPackratParser creates a new Packrat parser from a grammar
pub fn new_packrat_parser(grammar Grammar) &PackratParser {
	return &PackratParser{
		grammar: grammar
		lexer: lexer.new_lexer("")
		memo_cache: PackratMemoizationCache{}
		actions: actions.new_action_executor()
	}
}

// Parse parses input using the Packrat algorithm
pub fn (mut p PackratParser) Parse(input string) !actions.ActionValue {
	p.lexer = lexer.new_lexer(input)
	p.memo_cache.cache.clear()
	
	// Find the start rule
	start_rule := p.grammar.find_start_rule() or {
		return error("No start rule found in grammar")
	}
	
	result := p.parse_rule(start_rule.name, 0)
	
	if !result.success {
		return error("Parse failed at position ${result.end_position}")
	}
	
	return result.value
}

// parse_rule implements the core Packrat parsing with memoization
fn (mut p PackratParser) parse_rule(rule_name string, position int) ParseResult {
	// Create cache key
	cache_key := "${rule_name}_${position}"
	
	// Check memoization cache
	if cache_key in p.memo_cache.cache {
		return p.memo_cache.cache[cache_key]
	}
	
	// Find the rule
	rule := p.grammar.find_rule(rule_name) or {
		return ParseResult{false, actions.ActionValue{}, position}
	}
	
	// Parse the rule's expression
	result := p.parse_expression(rule.expression, position)
	
	// Memoize the result
	p.memo_cache.cache[cache_key] = result
	
	return result
}

// parse_expression parses an expression starting at position
fn (mut p PackratParser) parse_expression(expr Expression, position int) ParseResult {
	match expr.type_of() {
		.sequence {
			return p.parse_sequence(expr, position)
		}
		.choice {
			return p.parse_choice(expr, position)
		}
		.zero_or_more, .one_or_more, .optional {
			return p.parse_repetition(expr, position)
		}
		.and_predicate, .not_predicate {
			return p.parse_predicate(expr, position)
		}
		.rule_reference {
			return p.parse_rule(expr.rule_name, position)
		}
		.literal {
			return p.parse_literal(expr, position)
		}
		.character_class {
			return p.parse_character_class(expr, position)
		}
		.group {
			return p.parse_expression(expr.expression, position)
		}
		.semantic_action {
			return p.parse_semantic_action(expr, position)
		}
	}
}

// parse_sequence parses a sequence of expressions
fn (mut p PackratParser) parse_sequence(expr Expression, position int) ParseResult {
	mut current_pos := position
	mut values := []actions.ActionValue{}
	
	for sub_expr in expr.sequence_expressions {
		result := p.parse_expression(sub_expr, current_pos)
		
		if !result.success {
			return ParseResult{false, actions.ActionValue{}, position}
		}
		
		if result.value.type_of() != .void {
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
fn (mut p PackratParser) parse_choice(expr Expression, position int) ParseResult {
	for sub_expr in expr.choice_expressions {
		result := p.parse_expression(sub_expr, position)
		if result.success {
			return result
		}
	}
	
	return ParseResult{false, actions.ActionValue{}, position}
}

// parse_repetition parses repetition operators
fn (mut p PackratParser) parse_repetition(expr Expression, position int) ParseResult {
	mut current_pos := position
	mut values := []actions.ActionValue{}
	min_count := match expr.type_of() {
		.zero_or_more { 0 }
		.one_or_more { 1 }
		.optional { 0 }
		else { 0 }
	}
	max_count := match expr.type_of() {
		.optional { 1 }
		else { -1 } // unlimited
	}
	
	count := 0
	for {
		if max_count != -1 && count >= max_count {
			break
		}
		
		result := p.parse_expression(expr.repetition_expression, current_pos)
		if !result.success {
			break
		}
		
		if result.value.type_of() != .void {
			values << result.value
		}
		
		current_pos = result.end_position
		count++
		
		// Prevent infinite loops
		if current_pos == position && count > 1000 {
			return ParseResult{false, actions.ActionValue{}, position}
		}
	}
	
	if count < min_count {
		return ParseResult{false, actions.ActionValue{}, position}
	}
	
	// Handle repetition results
	mut final_value := actions.ActionValue{}
	if values.len == 0 {
		final_value = actions.new_array_value([])
	} else if values.len == 1 && expr.type_of() == .optional {
		final_value = values[0]
	} else {
		final_value = actions.new_array_value(values)
	}
	
	return ParseResult{true, final_value, current_pos}
}

// parse_predicate parses lookahead predicates
fn (mut p PackratParser) parse_predicate(expr Expression, position int) ParseResult {
	is_and := expr.type_of() == .and_predicate
	
	result := p.parse_expression(expr.predicate_expression, position)
	
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
fn (mut p PackratParser) parse_literal(expr Expression, position int) ParseResult {
	literal := expr.literal_value
	
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
fn (mut p PackratParser) parse_character_class(expr Expression, position int) ParseResult {
	if position >= p.lexer.input.len {
		return ParseResult{false, actions.ActionValue{}, position}
	}
	
	char := p.lexer.input[position]
	
	for range_expr in expr.character_ranges {
		if char >= range_expr.start && char <= range_expr.end {
			value := actions.new_string_value(char.str())
			return ParseResult{true, value, position + 1}
		}
	}
	
	return ParseResult{false, actions.ActionValue{}, position}
}

// parse_semantic_action executes user-defined actions
fn (mut p PackratParser) parse_semantic_action(expr Expression, position int) ParseResult {
	// First parse the inner expression
	result := p.parse_expression(expr.action_expression, position)
	
	if !result.success {
		return result
	}
	
	// Execute the semantic action
	mut context := actions.new_action_context()
	context.set_value("result", result.value)
	
	// Execute action code
	action_result := p.actions.execute(expr.action_code, context) or {
		return ParseResult{false, actions.ActionValue{}, position}
	}
	
	return ParseResult{true, action_result, result.end_position}
}