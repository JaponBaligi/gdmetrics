extends Reference
class_name ControlFlowDetector

# Control flow detector
# Detects: if, elif, for, while, and logical operators (and, or, not)

class ControlFlowNode:
	var type: String
	var line: int
	var column: int
	
	func _init(t: String, l: int, c: int):
		type = t
		line = l
		column = c
	
	func _to_string() -> String:
		return "%s at %d:%d" % [type, line, column]

var detected_nodes: Array = []
var errors: Array = []

func detect_control_flow(tokens: Array) -> Array:
	detected_nodes.clear()
	errors.clear()
	
	if tokens.empty():
		return []
	
	var i = 0
	while i < tokens.size():
		var token = tokens[i]
		if token.type == GDScriptTokenizer.TokenType.WHITESPACE or token.type == GDScriptTokenizer.TokenType.COMMENT:
			i += 1
			continue
		if token.type == GDScriptTokenizer.TokenType.KEYWORD:
			if token.value == "if":
				detected_nodes.append(ControlFlowNode.new("if", token.line, token.column))
			elif token.value == "elif":
				detected_nodes.append(ControlFlowNode.new("elif", token.line, token.column))
			elif token.value == "for":
				detected_nodes.append(ControlFlowNode.new("for", token.line, token.column))
			elif token.value == "while":
				detected_nodes.append(ControlFlowNode.new("while", token.line, token.column))
			elif token.value == "and":
				detected_nodes.append(ControlFlowNode.new("and", token.line, token.column))
			elif token.value == "or":
				detected_nodes.append(ControlFlowNode.new("or", token.line, token.column))
			elif token.value == "not":
				detected_nodes.append(ControlFlowNode.new("not", token.line, token.column))
		
		i += 1
	
	return detected_nodes.duplicate()

func get_errors() -> Array:
	return errors.duplicate()

func count_by_type(type: String) -> int:
	var count = 0
	for node in detected_nodes:
		if node.type == type:
			count += 1
	return count

