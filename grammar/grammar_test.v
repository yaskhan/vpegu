// grammar_test.v - Tests for grammar data structures
//
// Tests the core data structures used in PEG grammar representation.
//
// Author: VPEGU Team
// 
module grammar

fn test_create_expr() {
    expr := create_expr(.literal, "hello")
    assert expr.kind == .literal
    assert expr.value == "hello"
    assert expr.items.len == 0
}

fn test_create_composite_expr() {
    items := [
        create_expr(.name, "A"),
        create_expr(.name, "B")
    ]
    expr := create_composite_expr(.sequence, items)
    assert expr.kind == .sequence
    assert expr.items.len == 2
    assert expr.items[0].value == "A"
    assert expr.items[1].value == "B"
}

fn test_create_rule() {
    expr := create_expr(.literal, "test")
    rule := create_rule("TestRule", expr)
    assert rule.name == "TestRule"
    assert rule.expr.kind == .literal
    assert rule.expr.value == "test"
}

fn test_create_tree() {
    tree := create_tree()
    assert tree.package_name == ""
    assert tree.imports.len == 0
    assert tree.peg_name == ""
    assert tree.rules.len == 0
    assert tree.comments.len == 0
    assert tree.spaces.len == 0
}

fn test_expr_kind_str() {
    assert ExprKind.sequence.str() == "sequence"
    assert ExprKind.alternate.str() == "alternate"
    assert ExprKind.peek_for.str() == "peek_for"
    assert ExprKind.peek_not.str() == "peek_not"
    assert ExprKind.query.str() == "query"
    assert ExprKind.star.str() == "star"
    assert ExprKind.plus.str() == "plus"
    assert ExprKind.name.str() == "name"
    assert ExprKind.literal.str() == "literal"
    assert ExprKind.character_class.str() == "character_class"
    assert ExprKind.dot.str() == "dot"
    assert ExprKind.action.str() == "action"
    assert ExprKind.push.str() == "push"
}

fn test_complex_tree() {
    mut tree := create_tree()
    tree.package_name = "test"
    tree.imports << "os"
    tree.peg_name = "TestPeg"
    
    // Create a complex rule
    expr1 := create_expr(.name, "A")
    expr2 := create_expr(.literal, "hello")
    seq := create_composite_expr(.sequence, [expr1, expr2])
    rule := create_rule("TestRule", seq)
    
    tree.rules << rule
    
    assert tree.package_name == "test"
    assert tree.imports.len == 1
    assert tree.peg_name == "TestPeg"
    assert tree.rules.len == 1
    assert tree.rules[0].name == "TestRule"
    assert tree.rules[0].expr.kind == .sequence
}