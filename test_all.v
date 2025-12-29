// Comprehensive test for V PEG Parser Generator
module main

import os
import parser

fn main() {
	println('=== V PEG Parser Generator - Comprehensive Test ===\n')

	// Test 1: Grammar parsing
	test_grammar_parsing()

	// Test 2: Packrat parser
	test_packrat_parser()

	// Test 3: Complex grammar
	test_complex_grammar()

	// Test 4: Generator
	test_generator()

	println('\n=== All tests completed ===')
}

fn test_generator() {
	println('\nTest 4: Generator')

	grammar_file := 'test_gen.peg'
	grammar_text := "Start <- 'abc' / 'def'\n"
	os.write_file(grammar_file, grammar_text) or { return }
	defer { os.rm(grammar_file) or {} }

	// Use the compiled vpegu binary
	res := os.execute('./vpegu ${grammar_file} --output generated_parser.v')
	if res.exit_code != 0 {
		println('  ❌ FAILED to run vpegu: ${res.output}')
		return
	}
	defer { os.rm('generated_parser.v') or {} }

	// Compile and run the generated parser
	res_abc := os.execute('v run generated_parser.v abc')
	if res_abc.exit_code == 0 && res_abc.output.contains('Parse successful!') {
		println("  ✓ Generated parser works for 'abc'")
	} else {
		println("  ❌ Generated parser failed for 'abc'")
		println(res_abc.output)
	}

	res_def := os.execute('v run generated_parser.v def')
	if res_def.exit_code == 0 && res_def.output.contains('Parse successful!') {
		println("  ✓ Generated parser works for 'def'")
	} else {
		println("  ❌ Generated parser failed for 'def'")
	}

	res_ghi := os.execute('v run generated_parser.v ghi')
	if res_ghi.exit_code == 0 && res_ghi.output.contains('Parse failed') {
		println("  ✓ Generated parser correctly fails for 'ghi'")
	} else {
		println("  ❌ Generated parser should have failed for 'ghi'")
	}
}

fn test_grammar_parsing() {
	println('Test 1: Grammar Parsing')

	// Simple arithmetic grammar
	grammar_text := r"
Expression <- Term (('+' / '-') Term)*
Term <- Factor (('*' / '/') Factor)*
Factor <- Number / '(' Expression ')'
Number <- [0-9]+
"

	mut p := parser.new_parser()
	result := p.parse(grammar_text) or {
		println('  ❌ FAILED: ${err}')
		return
	}

	println('  ✓ Grammar parsed successfully')
	println('  ✓ Rules count: ${result.rules.len}')

	expected_rules := ['Expression', 'Term', 'Factor', 'Number']
	for i, rule_name in expected_rules {
		if result.rules[i].name == rule_name {
			println('    ✓ ${rule_name}')
		} else {
			println('    ❌ Expected ${rule_name}, got ${result.rules[i].name}')
		}
	}
}

fn test_packrat_parser() {
	println('\nTest 2: Packrat Parser')

	// Create a simple grammar
	grammar_text := r"
Start <- 'hello' ' ' 'world'
"

	mut grammar_parser := parser.new_parser()
	parsed_grammar := grammar_parser.parse(grammar_text) or {
		println('  ❌ FAILED: ${err}')
		return
	}

	// Test the parser
	mut packrat_parser := parser.new_packrat_parser(parsed_grammar)
	result := packrat_parser.parse('hello world') or {
		println('  ❌ FAILED: ${err}')
		return
	}

	println('  ✓ Packrat parser works')
	println('  ✓ Result: ${result.str()}')
}

fn test_complex_grammar() {
	println('\nTest 3: Complex Grammar')

	// JSON-like grammar (simplified)
	grammar_text := "Object <- '{' Members '}'\n" + "Members <- Pair (',' Pair)* / ''\n" +
		"Pair <- String ':' Value\n" +
		"Value <- String / Number / Object / Array / 'true' / 'false' / 'null'\n" +
		"Array <- '[' Elements ']'\n" + "Elements <- Value (',' Value)* / ''\n" +
		'String <- \'"\' [a-z]* \'"\'\n' + 'Number <- [0-9]+\n'

	mut grammar_parser := parser.new_parser()
	parsed_grammar := grammar_parser.parse(grammar_text) or {
		println('  ❌ FAILED: ${err}')
		return
	}

	println('  ✓ Complex grammar parsed')
	println('  ✓ Rules: ${parsed_grammar.rules.len}')

	// Verify some rules are present
	expected_rules := ['Object', 'Members', 'Pair', 'Value', 'Array', 'Elements', 'String', 'Number']
	for rule_name in expected_rules {
		mut found := false
		for rule in parsed_grammar.rules {
			if rule.name == rule_name {
				found = true
				break
			}
		}
		if found {
			println('    ✓ ${rule_name}')
		} else {
			println('    ❌ ${rule_name} missing')
		}
	}
}
