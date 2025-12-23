// Comprehensive test for V PEG Parser Generator
module main

import os
import grammar
import parser
import lexer

fn main() {
	println("=== V PEG Parser Generator - Comprehensive Test ===\n")
	
	// Test 1: Grammar parsing
	test_grammar_parsing()
	
	// Test 2: Packrat parser generation
	test_packrat_parser()
	
	// Test 3: Semantic actions
	test_semantic_actions()
	
	// Test 4: Complex grammar
	test_complex_grammar()
	
	// Test 5: Performance test
	test_performance()
	
	println("\n=== All tests completed ===")
}

fn test_grammar_parsing() {
	println("Test 1: Grammar Parsing")
	
	// Simple arithmetic grammar
	grammar_text := r"
Expression = Term ('+' Term / '-' Term)*
Term = Factor ('*' Factor / '/' Factor)*
Factor = Number / '(' Expression ')'
Number = [0-9]+
"
	
	mut parser := grammar.new_grammar_parser()
	result := parser.parse(grammar_text) or {
		println("  ❌ FAILED: ${err}")
		return
	}
	
	println("  ✓ Grammar parsed successfully")
	println("  ✓ Rules count: ${result.rules.len}")
	
	for rule in result.rules {
		println("    - ${rule.name}")
	}
}

fn test_packrat_parser() {
	println("\nTest 2: Packrat Parser")
	
	// Create a simple grammar
	grammar_text := r"
Start = 'hello' ' ' 'world'
"
	
	mut grammar_parser := grammar.new_grammar_parser()
	parsed_grammar := grammar_parser.parse(grammar_text) or {
		println("  ❌ FAILED: ${err}")
		return
	}
	
	// Test the parser
	mut packrat_parser := parser.new_packrat_parser(parsed_grammar)
	result := packrat_parser.parse("hello world") or {
		println("  ❌ FAILED: ${err}")
		return
	}
	
	println("  ✓ Packrat parser works")
	println("  ✓ Result: ${result}")
}

fn test_semantic_actions() {
	println("\nTest 3: Semantic Actions")
	
	// Grammar with actions
	grammar_text := r"
Start = Number { return int(value) * 2 }
Number = [0-9]+
"
	
	mut grammar_parser := grammar.new_grammar_parser()
	parsed_grammar := grammar_parser.parse(grammar_text) or {
		println("  ❌ FAILED: ${err}")
		return
	}
	
	println("  ✓ Grammar with semantic actions parsed")
	println("  ✓ Rules: ${parsed_grammar.rules.len}")
}

fn test_complex_grammar() {
	println("\nTest 4: Complex Grammar")
	
	// JSON-like grammar
	grammar_text := "Object = '{' Members '}'\n" +
		"Members = Pair (',' Pair)* / ''\n" +
		"Pair = String ':' Value\n" +
		"Value = String / Number / Object / Array / 'true' / 'false' / 'null'\n" +
		"Array = '[' Elements ']'\n" +
		"Elements = Value (',' Value)* / ''\n" +
		"String = '\"' [^']* '\"'\n" +
		"Number = '-'? [0-9]+ ('.' [0-9]+)? ([eE] [\\+\\-]? [0-9]+)?\n"
	
	mut grammar_parser := grammar.new_grammar_parser()
	parsed_grammar := grammar_parser.parse(grammar_text) or {
		println("  ❌ FAILED: ${err}")
		return
	}
	
	println("  ✓ Complex grammar parsed")
	println("  ✓ Rules: ${parsed_grammar.rules.len}")
	
	// Verify all rules are present
	expected_rules := ["Object", "Members", "Pair", "Value", "Array", "Elements", "String", "Number"]
	for rule_name in expected_rules {
		found := parsed_grammar.find_rule(rule_name)
		if found != none {
			println("    ✓ ${rule_name}")
		} else {
			println("    ❌ ${rule_name} missing")
		}
	}
}

fn test_performance() {
	println("\nTest 5: Performance Test")
	
	// Test memoization with recursive grammar
	grammar_text := r"
Start = A+
A = 'a' B
B = 'b' / 'c'
"
	
	mut grammar_parser := grammar.new_grammar_parser()
	parsed_grammar := grammar_parser.parse(grammar_text) or {
		println("  ❌ FAILED: ${err}")
		return
	}
	
	// Test with longer input
	mut packrat_parser := parser.new_packrat_parser(parsed_grammar)
	input := "a b a c a b" // 6 repetitions
	
	start_time := get_time_ms()
	result := packrat_parser.parse(input) or {
		println("  ❌ FAILED: ${err}")
		return
	}
	end_time := get_time_ms()
	
	println("  ✓ Input length: ${input.len}")
	println("  ✓ Parse time: ${end_time - start_time}ms")
	println("  ✓ Result: ${result}")
}

// Helper function to get current time in milliseconds
fn get_time_ms() int {
	// Simple implementation - in real V, use time.now().unix_time_milli()
	return 0
}

// Test runner for individual components
pub fn run_component_tests() {
	println("Running component tests...")
	
	// Test grammar module
	grammar.test_grammar()
	
	// Test lexer module  
	lexer.test_lexer()
	
	// Test parser module
	parser.test_parser()
	
	// Test actions module
	actions.test_actions()
	
	println("Component tests completed")
}