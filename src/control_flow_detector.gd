extends Reference
class_name ControlFlowDetector

# Control flow detector 
# Detects: if, elif, for, while, match/case, and logical operators
# Tracks indentation-based nesting depth for C-COG calculations

class ControlFlowNode:
	var type: String
	var line: int
	var column: int
	var depth: int = 0
	
	func _init(t: String, l: int, c: int, d: int = 0):
		type = t
		line = l
		column = c
		depth = d
	
	func _to_string() -> String:
		return "%s at %d:%d (depth: %d)" % [type, line, column, depth]

var detected_nodes: Array = []
var errors: Array = []
var in_match_block: bool = false

func detect_control_flow(tokens: Array) -> Array:
	detected_nodes.clear()
	errors.clear()
	in_match_block = false
	
	if tokens.empty():
		return []
	
	var i = 0
	var indent_stack: Array = []  # Stack of indentation levels
	var last_line = -1
	var last_line_indent = 0
	
	while i < tokens.size():
		var token = tokens[i]
		
		if token.type == GDScriptTokenizer.TokenType.NEWLINE:
			last_line = token.line
			last_line_indent = 0
			i += 1
			continue
		
		if token.type == GDScriptTokenizer.TokenType.WHITESPACE:
			if token.line != last_line:
				var indent = _count_indent(token.value)
				if indent >= 0:
					last_line_indent = indent
					last_line = token.line
					_update_indent_stack(indent_stack, last_line_indent)
			i += 1
			continue
		
		if token.type == GDScriptTokenizer.TokenType.COMMENT:
			i += 1
			continue
		
		if token.type == GDScriptTokenizer.TokenType.KEYWORD:
			var line_indent = _get_line_indent(tokens, i)
			_update_indent_stack(indent_stack, line_indent)
			var nesting_depth = indent_stack.size()
			
			if token.value == "if":
				detected_nodes.append(ControlFlowNode.new("if", token.line, token.column, nesting_depth))
			elif token.value == "elif":
				detected_nodes.append(ControlFlowNode.new("elif", token.line, token.column, nesting_depth))
			elif token.value == "for":
				detected_nodes.append(ControlFlowNode.new("for", token.line, token.column, nesting_depth))
			elif token.value == "while":
				detected_nodes.append(ControlFlowNode.new("while", token.line, token.column, nesting_depth))
			elif token.value == "match":
				detected_nodes.append(ControlFlowNode.new("match", token.line, token.column, nesting_depth))
				in_match_block = true
			elif token.value == "case":
				if in_match_block:
					detected_nodes.append(ControlFlowNode.new("case", token.line, token.column, nesting_depth))
			elif token.value == "and":
				detected_nodes.append(ControlFlowNode.new("and", token.line, token.column, nesting_depth))
			elif token.value == "or":
				detected_nodes.append(ControlFlowNode.new("or", token.line, token.column, nesting_depth))
			elif token.value == "not":
				detected_nodes.append(ControlFlowNode.new("not", token.line, token.column, nesting_depth))
		
		if token.type == GDScriptTokenizer.TokenType.OPERATOR and token.value == ":":
			if in_match_block:
				pass
		
		i += 1
	
	return detected_nodes.duplicate()

func _get_line_indent(tokens: Array, token_index: int) -> int:
	if token_index <= 0:
		return 0
	
	var target_line = tokens[token_index].line
	var i = token_index - 1
	
	while i >= 0:
		var token = tokens[i]
		if token.line != target_line:
			break
		if token.type == GDScriptTokenizer.TokenType.WHITESPACE:
			return _count_indent(token.value)
		i -= 1
	
	return 0

func _count_indent(whitespace: String) -> int:
	if whitespace.empty():
		return 0
	
	var has_tabs = false
	var has_spaces = false
	var count = 0
	
	for i in range(whitespace.length()):
		if whitespace[i] == "\t":
			has_tabs = true
			count += 1
		elif whitespace[i] == " ":
			has_spaces = true
			count += 1
	
	if has_tabs and has_spaces:
		return -1
	
	return count

func _update_indent_stack(stack: Array, current_indent: int):
	while stack.size() > 0 and stack[stack.size() - 1] >= current_indent:
		stack.pop_back()
	
	if stack.size() == 0 or stack[stack.size() - 1] < current_indent:
		if current_indent > 0:
			stack.append(current_indent)

func get_errors() -> Array:
	return errors.duplicate()

func count_by_type(type: String) -> int:
	var count = 0
	for node in detected_nodes:
		if node.type == type:
			count += 1
	return count
