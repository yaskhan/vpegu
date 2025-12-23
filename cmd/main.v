// vpegu - Packrat PEG Parser for V
// Main CLI interface for testing PEG grammatics
//
// Usage: v run main.v --input grammar.peg [--output ast.json]
//
// Author: VPEGU Team
// 
// License: MIT

import os
import json
import parser

fn main() {
    mut input_file := ''
    mut output_file := ''
    
    // Parse command line arguments
    // os.args contains: [executable, --input, file, --output, file]
    for i, arg in os.args {
        if arg == '--input' && i + 1 < os.args.len {
            input_file = os.args[i + 1]
        } else if arg == '--output' && i + 1 < os.args.len {
            output_file = os.args[i + 1]
        }
    }
    
    if input_file == '' {
        println('Usage: v run main.v --input <grammar.peg> [--output <ast.json>]')
        println('       v run main.v --help')
        return
    }
    
    if input_file == '--help' {
        println('VPEGU - Packrat PEG Parser')
        println('')
        println('Options:')
        println('  --input <file>    Input PEG grammar file')
        println('  --output <file>   Output JSON file (optional)')
        println('  --help            Show this help')
        println('')
        println('Examples:')
        println('  v run main.v --input grammar.peg')
        println('  v run main.v --input grammar.peg --output ast.json')
        return
    }
    
    if !os.exists(input_file) {
        eprintln('Error: Input file "$input_file" not found')
        return
    }
    
    // Read the grammar file
    content := os.read_file(input_file) or {
        eprintln('Error: Cannot read file "$input_file"')
        return
    }
    
    // Parse the grammar
    mut peg_parser := parser.new_parser()
    tree := peg_parser.parse(content) or {
        eprintln('Parse error: $err')
        return
    }
    
    // Output results
    if output_file != '' {
        // Write JSON output
        json_output := json.encode_pretty(tree)
        os.write_file(output_file, json_output) or {
            eprintln('Error: Cannot write to "$output_file"')
            return
        }
        println('AST written to $output_file')
    } else {
        // Print to console
        println('=== PEG Grammar AST ===')
        println(json.encode_pretty(tree))
    }
    
    println('\nParsing completed successfully!')
}
