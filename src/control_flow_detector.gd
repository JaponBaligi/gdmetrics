extends Object
class_name ControlFlowDetector

# Control flow detector 
# Detects: if, elif, for, while, match/case, and logical operators
# Tracks indentation-based nesting depth for C-COG calculations

class ControlFlowNode:
	var type: String
	var line: int
	var column: int
	var depth: int = 0
	var in_control_flow: bool = false
	var lambda_depth: int = 0
	var case_pattern_count: int = 1
	var case_has_guard: bool = false
	
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
var version_adapter = null

func detect_control_flow(tokens: Array, adapter = null) -> Array:
	detected_nodes.clear()
	errors.clear()
	in_match_block = false
	version_adapter = adapter
	
	if tokens.size() == 0:
		return []
	
	var TokenType = load("res://src/gd3/tokenizer.gd" if Engine.get_version_info().get("major", 0) == 3 else "res://src/tokenizer.gd").TokenType
	
	var supports_match = true
	if version_adapter != null:
		supports_match = version_adapter.supports_match_statements()
	
	var i = 0
	var indent_stack: Array = []  # Stack of indentation levels
	var control_flow_stack: Array = []  # Stack of control flow contexts: {indent, type}
	var lambda_stack: Array = []  # Stack of lambda indents
	var last_line = -1
	var last_line_indent = 0
	var pending_lambda_indent: int = -1
	
	while i < tokens.size():
		var token = tokens[i]
		
		if token.type == TokenType.NEWLINE:
			last_line = token.line
			last_line_indent = 0
			i += 1
			continue
		
		if token.type == TokenType.WHITESPACE:
			if token.line != last_line:
				var indent = _count_indent(token.value)
				if indent >= 0:
					last_line_indent = indent
					last_line = token.line
					_update_indent_stack(indent_stack, last_line_indent)
					_update_control_flow_stack(control_flow_stack, last_line_indent)
					in_match_block = _is_match_active(control_flow_stack)
					_update_lambda_stack(lambda_stack, last_line_indent)
					if pending_lambda_indent >= 0 and indent > pending_lambda_indent:
						lambda_stack.append(indent)
						pending_lambda_indent = -1
			i += 1
			continue
		
		if token.type == TokenType.COMMENT:
			i += 1
			continue
		
		if token.type == TokenType.KEYWORD:
			var line_indent = _get_line_indent(tokens, i)
			_update_indent_stack(indent_stack, line_indent)
			_update_control_flow_stack(control_flow_stack, line_indent)
			in_match_block = _is_match_active(control_flow_stack)
			_update_lambda_stack(lambda_stack, line_indent)
			var nesting_depth = indent_stack.size()
			var in_control_flow = control_flow_stack.size() > 0
			var lambda_depth = lambda_stack.size()
			
			if token.value == "if":
				var node = ControlFlowNode.new("if", token.line, token.column, nesting_depth)
				node.in_control_flow = in_control_flow
				node.lambda_depth = lambda_depth
				detected_nodes.append(node)
				control_flow_stack.append({"indent": line_indent, "type": "if"})
			elif token.value == "elif":
				var node = ControlFlowNode.new("elif", token.line, token.column, nesting_depth)
				node.in_control_flow = in_control_flow
				node.lambda_depth = lambda_depth
				detected_nodes.append(node)
				control_flow_stack.append({"indent": line_indent, "type": "elif"})
			elif token.value == "for":
				var node = ControlFlowNode.new("for", token.line, token.column, nesting_depth)
				node.in_control_flow = in_control_flow
				node.lambda_depth = lambda_depth
				detected_nodes.append(node)
				control_flow_stack.append({"indent": line_indent, "type": "for"})
			elif token.value == "while":
				var node = ControlFlowNode.new("while", token.line, token.column, nesting_depth)
				node.in_control_flow = in_control_flow
				node.lambda_depth = lambda_depth
				detected_nodes.append(node)
				control_flow_stack.append({"indent": line_indent, "type": "while"})
			elif token.value == "match" and supports_match:
				var node = ControlFlowNode.new("match", token.line, token.column, nesting_depth)
				node.in_control_flow = in_control_flow
				node.lambda_depth = lambda_depth
				detected_nodes.append(node)
				in_match_block = true
				control_flow_stack.append({"indent": line_indent, "type": "match"})
			elif token.value == "case" and supports_match:
				if in_match_block:
					var details = _parse_case_details(tokens, i)
					var node = ControlFlowNode.new("case", token.line, token.column, nesting_depth)
					node.in_control_flow = in_control_flow
					node.lambda_depth = lambda_depth
					node.case_pattern_count = details.pattern_count
					node.case_has_guard = details.has_guard
					detected_nodes.append(node)
					control_flow_stack.append({"indent": line_indent, "type": "case"})
			elif token.value == "and":
				var node = ControlFlowNode.new("and", token.line, token.column, nesting_depth)
				node.in_control_flow = in_control_flow
				node.lambda_depth = lambda_depth
				detected_nodes.append(node)
			elif token.value == "or":
				var node = ControlFlowNode.new("or", token.line, token.column, nesting_depth)
				node.in_control_flow = in_control_flow
				node.lambda_depth = lambda_depth
				detected_nodes.append(node)
			elif token.value == "not":
				var node = ControlFlowNode.new("not", token.line, token.column, nesting_depth)
				node.in_control_flow = in_control_flow
				node.lambda_depth = lambda_depth
				detected_nodes.append(node)
			elif token.value == "return" or token.value == "break" or token.value == "continue":
				var node = ControlFlowNode.new(token.value, token.line, token.column, nesting_depth)
				node.in_control_flow = in_control_flow
				node.lambda_depth = lambda_depth
				detected_nodes.append(node)
			elif token.value == "func":
				var anon = _is_anonymous_func(tokens, i)
				if anon:
					var node = ControlFlowNode.new("lambda", token.line, token.column, nesting_depth)
					node.in_control_flow = in_control_flow
					node.lambda_depth = lambda_depth
					detected_nodes.append(node)
					pending_lambda_indent = line_indent
		
		if token.type == TokenType.OPERATOR and token.value == ":":
			if in_match_block:
				pass
		
		i += 1
	
	return detected_nodes.duplicate()

func _get_line_indent(tokens: Array, token_index: int) -> int:
	if token_index <= 0:
		return 0
	
	var TokenType = load("res://src/gd3/tokenizer.gd" if Engine.get_version_info().get("major", 0) == 3 else "res://src/tokenizer.gd").TokenType
	var target_line = tokens[token_index].line
	var i = token_index - 1
	
	while i >= 0:
		var token = tokens[i]
		if token.line != target_line:
			break
		if token.type == TokenType.WHITESPACE:
			return _count_indent(token.value)
		i -= 1
	
	return 0

func _count_indent(whitespace: String) -> int:
	if whitespace.length() == 0:
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

func _update_control_flow_stack(stack: Array, current_indent: int):
	while stack.size() > 0 and stack[stack.size() - 1]["indent"] >= current_indent:
		stack.pop_back()

func _update_lambda_stack(stack: Array, current_indent: int):
	while stack.size() > 0 and stack[stack.size() - 1] >= current_indent:
		stack.pop_back()

func _is_match_active(stack: Array) -> bool:
	for entry in stack:
		if entry.get("type", "") == "match":
			return true
	return false

func _parse_case_details(tokens: Array, start_index: int) -> Dictionary:
	var TokenType = load("res://src/gd3/tokenizer.gd" if Engine.get_version_info().get("major", 0) == 3 else "res://src/tokenizer.gd").TokenType
	var pattern_count = 1
	var has_guard = false
	var guard_mode = false
	var paren_depth = 0
	var line = tokens[start_index].line
	var i = start_index + 1
	
	while i < tokens.size():
		var token = tokens[i]
		if token.line != line:
			break
		if token.type == TokenType.OPERATOR and token.value == ":":
			break
		if token.type == TokenType.OPERATOR:
			if token.value == "(" or token.value == "[" or token.value == "{":
				paren_depth += 1
			elif token.value == ")" or token.value == "]" or token.value == "}":
				if paren_depth > 0:
					paren_depth -= 1
			elif token.value == "," and paren_depth == 0 and not guard_mode:
				pattern_count += 1
		elif token.type == TokenType.KEYWORD and token.value == "if" and paren_depth == 0:
			has_guard = true
			guard_mode = true
		i += 1
	
	return {
		"pattern_count": pattern_count,
		"has_guard": has_guard
	}

func _is_anonymous_func(tokens: Array, func_index: int) -> bool:
	var TokenType = load("res://src/gd3/tokenizer.gd" if Engine.get_version_info().get("major", 0) == 3 else "res://src/tokenizer.gd").TokenType
	var i = func_index + 1
	while i < tokens.size():
		var token = tokens[i]
		if token.type == TokenType.WHITESPACE or token.type == TokenType.COMMENT:
			i += 1
			continue
		if token.type == TokenType.IDENTIFIER:
			return false
		if token.type == TokenType.OPERATOR and token.value == "(":
			return true
		return false
	return false

func get_errors() -> Array:
	return errors.duplicate()

func count_by_type(type: String) -> int:
	var count = 0
	for node in detected_nodes:
		if node.type == type:
			count += 1
	return count
