// actions_test.v - Tests for PEG grammar builder actions
//
// Tests the Peg struct and all add_* methods for building grammar trees.
//
// Author: VPEGU Team
// 
module actions

fn test_new_peg() {
    mut peg := actions.new_peg()
    tree := peg.get_tree()
    assert tree.package_name == ""
    assert tree.imports.len == 0
    assert tree.rules.len == 0
}

fn test_add_package() {
    mut peg := actions.new_peg()
    peg.add_package("test")
    assert peg.get_tree().package_name == "test"
}

fn test_add_import() {
    mut peg := actions.new_peg()
    peg.add_import("os")
    peg.add_import("json")
    assert peg.get_tree().imports.len == 2
    assert peg.get_tree().imports[0] == "os"
    assert peg.get_tree().imports[1] == "json"
}

fn test_add_peg() {
    mut peg := actions.new_peg()
    peg.add_peg("MyParser")
    assert peg.get_tree().peg_name == "MyParser"
}

fn test_add_rule() {
    mut peg := actions.new_peg()
    expr := peg.add_literal("hello")
    peg.add_rule("TestRule", expr)
    
    tree := peg.get_tree()
    assert tree.rules.len == 1
    assert tree.rules[0].name == "TestRule"
    assert tree.rules[0].expr.kind == .literal
    assert tree.rules[0].expr.value == "hello"
}

fn test_add_alternate() {
    mut peg := actions.new_peg()
    expr1 := peg.add_name("A")
    expr2 := peg.add_name("B")
    alt := peg.add_alternate([expr1, expr2])
    
    assert alt.kind == .alternate
    assert alt.items.len == 2
}

fn test_add_sequence() {
    mut peg := actions.new_peg()
    expr1 := peg.add_literal("hello")
    expr2 := peg.add_dot()
    seq := peg.add_sequence([expr1, expr2])
    
    assert seq.kind == .sequence
    assert seq.items.len == 2
}

fn test_add_peek_for() {
    mut peg := actions.new_peg()
    expr := peg.add_literal("a")
    peek := peg.add_peek_for(expr)
    
    assert peek.kind == .peek_for
    assert peek.items.len == 1
}

fn test_add_peek_not() {
    mut peg := actions.new_peg()
    expr := peg.add_literal("a")
    peek := peg.add_peek_not(expr)
    
    assert peek.kind == .peek_not
    assert peek.items.len == 1
}

fn test_add_query() {
    mut peg := actions.new_peg()
    expr := peg.add_name("A")
    query := peg.add_query(expr)
    
    assert query.kind == .query
    assert query.items.len == 1
}

fn test_add_star() {
    mut peg := actions.new_peg()
    expr := peg.add_name("A")
    star := peg.add_star(expr)
    
    assert star.kind == .star
    assert star.items.len == 1
}

fn test_add_plus() {
    mut peg := actions.new_peg()
    expr := peg.add_name("A")
    plus := peg.add_plus(expr)
    
    assert plus.kind == .plus
    assert plus.items.len == 1
}

fn test_add_name() {
    mut peg := actions.new_peg()
    name := peg.add_name("RuleName")
    
    assert name.kind == .name
    assert name.value == "RuleName"
}

fn test_add_literal() {
    mut peg := actions.new_peg()
    lit := peg.add_literal("hello")
    
    assert lit.kind == .literal
    assert lit.value == "hello"
}

fn test_add_character_class() {
    mut peg := actions.new_peg()
    cc := peg.add_character_class("[a-z]")
    
    assert cc.kind == .character_class
    assert cc.value == "[a-z]"
}

fn test_add_dot() {
    mut peg := actions.new_peg()
    dot := peg.add_dot()
    
    assert dot.kind == .dot
    assert dot.value == ""
}

fn test_add_action() {
    mut peg := actions.new_peg()
    action := peg.add_action("p.value = text")
    
    assert action.kind == .action
    assert action.value == "p.value = text"
}

fn test_add_push() {
    mut peg := actions.new_peg()
    expr := peg.add_name("Expr")
    push := peg.add_push(expr)
    
    assert push.kind == .push
    assert push.items.len == 1
}

fn test_add_comment() {
    mut peg := actions.new_peg()
    peg.add_comment("This is a comment")
    peg.add_comment("Another comment")
    
    assert peg.get_tree().comments.len == 2
    assert peg.get_tree().comments[0] == "This is a comment"
}

fn test_add_space() {
    mut peg := actions.new_peg()
    peg.add_space(" ")
    peg.add_space("\t")
    
    assert peg.get_tree().spaces.len == 2
}

fn test_reset() {
    mut peg := actions.new_peg()
    peg.add_package("test")
    peg.add_import("os")
    peg.add_rule("Rule", peg.add_literal("x"))
    
    assert peg.get_tree().package_name == "test"
    
    peg.reset()
    assert peg.get_tree().package_name == ""
    assert peg.get_tree().rules.len == 0
}

fn test_complex_grammar() {
    mut peg := actions.new_peg()
    
    // Build a complex grammar
    peg.add_package("math")
    peg.add_import("os")
    peg.add_peg("MathParser")
    
    // Expr <- Term ('+' Term)*
    term := peg.add_name("Term")
    plus := peg.add_literal("+")
    seq := peg.add_sequence([plus, term])
    star := peg.add_star(seq)
    expr_seq := peg.add_sequence([term, star])
    peg.add_rule("Expr", expr_seq)
    
    // Term <- Number
    number := peg.add_name("Number")
    peg.add_rule("Term", number)
    
    // Number <- [0-9]+
    cc := peg.add_character_class("[0-9]")
    num := peg.add_plus(cc)
    peg.add_rule("Number", num)
    
    tree := peg.get_tree()
    assert tree.package_name == "math"
    assert tree.imports.len == 1
    assert tree.peg_name == "MathParser"
    assert tree.rules.len == 3
    assert tree.rules[0].name == "Expr"
    assert tree.rules[1].name == "Term"
    assert tree.rules[2].name == "Number"
}