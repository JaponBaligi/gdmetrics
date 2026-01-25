extends RefCounted
class_name ClassDetector

# class definition detector
# detects: class_name, extends, class declarations

class ClassInfo:
	var name: String
	var class_name_decl: String = ""
	var extends_class: String = ""
	var start_line: int
	var start_column: int
	var end_line: int
	
	func _init(n: String, line: int, col: int):
		name = n
		start_line = line
		start_column = col
		end_line = line
	
	func _to_string() -> String:
		var result = "class %s" % name
		if class_name_decl != "":
			result += " (class_name: %s)" % class_name_decl
		if extends_class != "":
			result += " extends %s" % extends_class
		result += " at %d:%d-%d" % [start_line, start_column, end_line]
		return result

var classes: Array = []
var errors: Array = []

func detect_classes(tokens: Array) -> Array:
	classes.clear()
	errors.clear()
	
	if tokens.is_empty():
		return []
	
	var TokenType = load("res://src/tokenizer.gd").TokenType
	
	var i = 0
	var current_class: ClassInfo = null
	var class_indent = -1
	
	while i < tokens.size():
		var token = tokens[i]

		if token.type == TokenType.WHITESPACE:
			var indent = _count_indent(token.value)

			if current_class != null and indent >= 0 and indent <= class_indent:
				current_class.end_line = token.line - 1
				current_class = null
				class_indent = -1
			
			i += 1
			continue
		
		if token.type == TokenType.COMMENT:
			i += 1
			continue

		if token.type == TokenType.KEYWORD:
			if token.value == "class_name":
				var class_name_result = _parse_class_name_declaration(tokens, i)
				if class_name_result.class_name != "":
					if current_class != null:
						current_class.class_name_decl = class_name_result.class_name
					else:
						errors.append("class_name declaration without class definition at line %d" % token.line)
					i = class_name_result.next_index
					continue
			elif token.value == "extends":
				var extends_result = _parse_extends_declaration(tokens, i)
				if extends_result.extends_class != "":
					if current_class != null:
						current_class.extends_class = extends_result.extends_class
					else:
						errors.append("extends declaration without class definition at line %d" % token.line)
					i = extends_result.next_index
					continue
			elif token.value == "class":
				var class_result = _parse_class_declaration(tokens, i)
				if class_result.class_info != null:
					if current_class != null:
						current_class.end_line = token.line - 1
					
					current_class = class_result.class_info
					class_indent = _get_line_indent(tokens, i)
					classes.append(current_class)
					i = class_result.next_index
					continue
		
		i += 1

	if current_class != null:
		if tokens.size() > 0:
			current_class.end_line = tokens[tokens.size() - 1].line
		else:
			current_class.end_line = current_class.start_line
	
	return classes.duplicate()

func _get_line_indent(tokens: Array, token_index: int) -> int:
	if token_index <= 0:
		return 0
	
	var TokenType = load("res://src/tokenizer.gd").TokenType
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
	if whitespace.is_empty():
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

func _parse_class_name_declaration(tokens: Array, start: int) -> Dictionary:
	var TokenType = load("res://src/tokenizer.gd").TokenType
	var i = start + 1
	var name_value = ""
	
	while i < tokens.size() and tokens[i].type == TokenType.WHITESPACE:
		i += 1
	
	if i >= tokens.size() or tokens[i].type != TokenType.IDENTIFIER:
		return {"class_name": "", "next_index": start + 1}
	
	name_value = tokens[i].value
	i += 1
	
	return {"class_name": name_value, "next_index": i}

func _parse_extends_declaration(tokens: Array, start: int) -> Dictionary:
	var TokenType = load("res://src/tokenizer.gd").TokenType
	var i = start + 1
	var extends_class = ""
	
	while i < tokens.size() and tokens[i].type == TokenType.WHITESPACE:
		i += 1
	
	if i >= tokens.size() or tokens[i].type != TokenType.IDENTIFIER:
		return {"extends_class": "", "next_index": start + 1}
	
	extends_class = tokens[i].value
	i += 1
	
	return {"extends_class": extends_class, "next_index": i}

func _parse_class_declaration(tokens: Array, start: int) -> Dictionary:
	var TokenType = load("res://src/tokenizer.gd").TokenType
	var i = start + 1
	var name_value = ""
	
	while i < tokens.size() and tokens[i].type == TokenType.WHITESPACE:
		i += 1
	
	if i >= tokens.size() or tokens[i].type != TokenType.IDENTIFIER:
		return {"class_info": null, "next_index": start + 1}
	
	name_value = tokens[i].value
	var class_line = tokens[i].line
	var class_col = tokens[i].column
	i += 1
	
	var class_info = ClassInfo.new(name_value, class_line, class_col)
	
	return {"class_info": class_info, "next_index": i}

func get_errors() -> Array:
	return errors.duplicate()

