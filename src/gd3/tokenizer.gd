extends Object
class_name GDScriptTokenizer

# Tokenizer for GDScript
# Keywords, identifiers, operators, comments, strings, numbers 

var file_helper = null

func _init():
	var version_info = Engine.get_version_info()
	var is_godot_3 = version_info.get("major", 0) == 3
	
	if is_godot_3:
		file_helper = load("res://src/gd3/file_helper.gd").new()
	else:
		file_helper = load("res://src/gd4/file_helper.gd").new()

enum TokenType {
	KEYWORD,
	IDENTIFIER,
	OPERATOR,
	NUMBER,
	STRING,
	COMMENT,
	WHITESPACE,
	NEWLINE
}

class Token:
	var type: int
	var value: String
	var line: int
	var column: int
	
	func _init(t: int, v: String, l: int, c: int):
		type = t
		value = v
		line = l
		column = c
	
	func _to_string() -> String:
		return "Token(%s, '%s', %d:%d)" % [TokenType.keys()[type], value, line, column]

const KEYWORDS = [
	"if", "elif", "else", "for", "while", "break", "continue", "return",
	"func", "class", "extends", "var", "const", "signal", "class_name",
	"and", "or", "not", "true", "false", "null",
	"pass", "self", "super", "match", "case", "yield", "await"
]

const SINGLE_OPS = ["+", "-", "*", "/", "%", "=", "<", ">", "!", "&", "|", "^", "~", "?", ":", ".", ",", ";", "(", ")", "[", "]", "{", "}"]

const DOUBLE_OPS = ["==", "!=", "<=", ">=", "&&", "||", "->", "::", "..", "+=", "-=", "*=", "/=", "%="]

var tokens: Array = []
var errors: Array = []

var in_multiline_comment: bool = false
var in_triple_string: bool = false
var triple_string_quote: String = ""
var multiline_buffer: String = ""
var multiline_start_line: int = 1

func tokenize_file(file_path: String) -> Array:

	tokens.clear()
	errors.clear()
	in_multiline_comment = false
	in_triple_string = false
	triple_string_quote = ""
	multiline_buffer = ""
	multiline_start_line = 1
	
	var version_info = Engine.get_version_info()
	var is_godot_3 = version_info.get("major", 0) == 3
	
	if file_helper == null:
		if is_godot_3:
			file_helper = load("res://src/gd3/file_helper.gd").new()
		else:
			file_helper = load("res://src/gd4/file_helper.gd").new()
	
	var file_exists = file_helper.file_exists(file_path)
	
	if not file_exists:
		errors.append("File not found: %s" % file_path)
		return []
	
	var file = file_helper.open_read(file_path)
	if file == null:
		errors.append("Failed to open file: %s" % file_path)
		return []
	
	var line_number = 1
	while not file.eof_reached():
		var line = file.get_line()
		tokenize_line(line, line_number)
		line_number += 1
	
	file_helper.close_file(file)
	
	if in_multiline_comment:
		errors.append("Unterminated multi-line comment starting at line %d" % multiline_start_line)
	if in_triple_string:
		errors.append("Unterminated triple-quoted string starting at line %d" % multiline_start_line)
	
	return tokens.duplicate()

func tokenize_line(line: String, line_number: int):

	if in_multiline_comment:
		var result = _continue_multiline_comment(line, line_number)
		if result.complete:
			in_multiline_comment = false
			multiline_buffer = ""
		return
	
	if in_triple_string:
		var result = _continue_triple_string(line, line_number)
		if result.complete:
			in_triple_string = false
			triple_string_quote = ""
			multiline_buffer = ""
		return

	var i = 0
	var column = 1
	
	while i < line.length():
		var current_char = line[i]
		if current_char in " \t":
			var start_col = column
			while i < line.length() and line[i] in " \t":
				i += 1
				column += 1
			tokens.append(Token.new(TokenType.WHITESPACE, line.substr(start_col - 1, i - start_col + 1), line_number, start_col))
			continue

		if i + 2 < line.length():
			var three_chars = line.substr(i, 3)
			if three_chars == '"""' or three_chars == "'''":
				var result = _parse_triple_string(line, i, line_number, column, three_chars)
				if result.error:
					errors.append("Line %d:%d: %s" % [line_number, column, result.error])
					i += 1
					column += 1
				elif result.multiline:
					in_triple_string = true
					triple_string_quote = three_chars
					multiline_buffer = result.token.value
					multiline_start_line = line_number
					return
				else:
					tokens.append(result.token)
					i = result.next_index
					column = result.next_column
				continue

		if current_char == "#":
			var comment_text = line.substr(i)
			tokens.append(Token.new(TokenType.COMMENT, comment_text, line_number, column))
			break

		if i + 2 < line.length() and line.substr(i, 3) == '"""':
			var result = _parse_multiline_comment(line, i, line_number, column)
			if result.multiline:
				in_multiline_comment = true
				multiline_buffer = result.token.value
				multiline_start_line = line_number
				return
			else:
				tokens.append(result.token)
				i = result.next_index
				column = result.next_column
			continue

		if current_char == '"' or current_char == "'":
			var string_result = _parse_string(line, i, line_number, column, current_char)
			if string_result.error:
				errors.append("Line %d:%d: %s" % [line_number, column, string_result.error])
				i += 1
				column += 1
			else:
				tokens.append(string_result.token)
				i = string_result.next_index
				column = string_result.next_column
			continue

		if (current_char >= "0" and current_char <= "9") or (current_char == "." and i + 1 < line.length() and line[i + 1] >= "0" and line[i + 1] <= "9"):
			var number_result = _parse_number(line, i, line_number, column)
			tokens.append(number_result.token)
			i = number_result.next_index
			column = number_result.next_column
			continue

		if i + 1 < line.length():
			var two_char = line.substr(i, 2)
			if two_char in DOUBLE_OPS:
				tokens.append(Token.new(TokenType.OPERATOR, two_char, line_number, column))
				i += 2
				column += 2
				continue
		
		if current_char in SINGLE_OPS:
			tokens.append(Token.new(TokenType.OPERATOR, current_char, line_number, column))
			i += 1
			column += 1
			continue

		if (current_char >= "a" and current_char <= "z") or (current_char >= "A" and current_char <= "Z") or (current_char >= "0" and current_char <= "9") or current_char == "_":
			var ident_result = _parse_identifier(line, i, line_number, column)
			tokens.append(ident_result.token)
			i = ident_result.next_index
			column = ident_result.next_column
			continue

		if current_char == "@":
			var annotation_result = _parse_annotation(line, i, line_number, column)
			if annotation_result.found:
				tokens.append(annotation_result.token)
				i = annotation_result.next_index
				column = annotation_result.next_column
				continue

		errors.append("Line %d:%d: Unknown character '%s'" % [line_number, column, current_char])
		i += 1
		column += 1

func _parse_string(line: String, start: int, line_num: int, col: int, quote_char: String) -> Dictionary:

	var i = start + 1
	var value = quote_char
	var escaped = false
	
	while i < line.length():
		var current_char = line[i]
		
		if escaped:
			if current_char == "n":
				value += "\\n"
			elif current_char == "t":
				value += "\\t"
			elif current_char == "r":
				value += "\\r"
			elif current_char == "\\":
				value += "\\\\"
			elif current_char == quote_char:
				value += "\\" + quote_char
			else:
				value += "\\" + current_char
			escaped = false
			i += 1
		elif current_char == "\\":
			escaped = true
			i += 1
		elif current_char == quote_char:
			value += quote_char
			var token = Token.new(TokenType.STRING, value, line_num, col)
			return {"token": token, "next_index": i + 1, "next_column": col + value.length(), "error": ""}
		else:
			value += current_char
			i += 1

	return {
		"token": null,
		"next_index": i,
		"next_column": col + value.length(),
		"error": "Unterminated string literal"
	}

func _parse_number(line: String, start: int, line_num: int, col: int) -> Dictionary:

	var i = start
	var value = ""
	var has_dot = false
	
	if i < line.length() and line[i] == "-":
		value += "-"
		i += 1
	
	while i < line.length() and line[i] >= "0" and line[i] <= "9":
		value += line[i]
		i += 1
	
	if i < line.length() and line[i] == ".":
		has_dot = true
		value += "."
		i += 1
		while i < line.length() and line[i] >= "0" and line[i] <= "9":
			value += line[i]
			i += 1

	if i < line.length() and (line[i] == "e" or line[i] == "E"):
		value += line[i]
		i += 1
		if i < line.length() and (line[i] == "+" or line[i] == "-"):
			value += line[i]
			i += 1
		var exp_start = i
		while i < line.length() and line[i] >= "0" and line[i] <= "9":
			value += line[i]
			i += 1
		if i == exp_start:
			var token = Token.new(TokenType.IDENTIFIER, value.substr(0, value.length() - 1), line_num, col)
			return {"token": token, "next_index": exp_start, "next_column": col + value.length() - 1}

	if value == "-" or value == "." or value == "-.":
		var token = Token.new(TokenType.OPERATOR if value == "-" else TokenType.IDENTIFIER, value, line_num, col)
		return {"token": token, "next_index": start + 1, "next_column": col + 1}
	
	var token = Token.new(TokenType.NUMBER, value, line_num, col)
	return {"token": token, "next_index": i, "next_column": col + value.length()}

func _parse_identifier(line: String, start: int, line_num: int, col: int) -> Dictionary:
	"""
	Parse an identifier or keyword. Returns {token: Token, next_index: int, next_column: int}
	"""
	var i = start
	var value = ""

	if i < line.length() and ((line[i] >= "a" and line[i] <= "z") or (line[i] >= "A" and line[i] <= "Z") or (line[i] >= "0" and line[i] <= "9") or line[i] == "_"):
		value += line[i]
		i += 1

		while i < line.length() and ((line[i] >= "a" and line[i] <= "z") or (line[i] >= "A" and line[i] <= "Z") or (line[i] >= "0" and line[i] <= "9") or line[i] == "_"):
			value += line[i]
			i += 1

	var token_type = TokenType.KEYWORD if value in KEYWORDS else TokenType.IDENTIFIER
	var token = Token.new(token_type, value, line_num, col)
	return {"token": token, "next_index": i, "next_column": col + value.length()}

func _parse_annotation(line: String, start: int, line_num: int, col: int) -> Dictionary:
	var annotations = ["@tool", "@export", "@onready", "@export_group", "@export_category"]
	
	for annotation in annotations:
		var annotation_len = annotation.length()
		if start + annotation_len <= line.length():
			if line.substr(start, annotation_len) == annotation:
				var next_pos = start + annotation_len
				if next_pos >= line.length() or line[next_pos] in " \t\n(":
					var token = Token.new(TokenType.IDENTIFIER, annotation, line_num, col)
					return {
						"found": true,
						"token": token,
						"next_index": next_pos,
						"next_column": col + annotation_len
					}
	
	return {"found": false, "token": null, "next_index": start, "next_column": col}

func get_errors() -> Array:
	return errors.duplicate()

func _parse_multiline_comment(line: String, start: int, line_num: int, col: int) -> Dictionary:

	var i = start + 3
	var value = '"""'

	while i < line.length():
		if i + 2 < line.length() and line.substr(i, 3) == '"""':
			value += '"""'
			var token = Token.new(TokenType.COMMENT, value, line_num, col)
			return {"token": token, "next_index": i + 3, "next_column": col + value.length(), "multiline": false}
		value += line[i]
		i += 1

	value += "\n"
	var token = Token.new(TokenType.COMMENT, value, line_num, col)
	return {"token": token, "next_index": line.length(), "next_column": col + value.length(), "multiline": true}

func _continue_multiline_comment(line: String, line_num: int) -> Dictionary:

	var i = 0
	multiline_buffer += line
	
	while i < line.length():
		if i + 2 < line.length() and line.substr(i, 3) == '"""':
			multiline_buffer += '"""'
			var token = Token.new(TokenType.COMMENT, multiline_buffer, multiline_start_line, 1)
			tokens.append(token)
			return {"complete": true}
		i += 1
	
	multiline_buffer += "\n"
	return {"complete": false}

func _parse_triple_string(line: String, start: int, line_num: int, col: int, quote_chars: String) -> Dictionary:

	var i = start + 3
	var value = quote_chars
	var escaped = false
	
	while i < line.length():
		var current_char = line[i]
		
		if escaped:
			if current_char == "n":
				value += "\\n"
			elif current_char == "t":
				value += "\\t"
			elif current_char == "r":
				value += "\\r"
			elif current_char == "\\":
				value += "\\\\"
			elif current_char == quote_chars[0]:
				value += "\\" + quote_chars[0]
			else:
				value += "\\" + current_char
			escaped = false
			i += 1
		elif current_char == "\\":
			escaped = true
			i += 1
		elif i + 2 < line.length() and line.substr(i, 3) == quote_chars:
			value += quote_chars
			var token = Token.new(TokenType.STRING, value, line_num, col)
			return {"token": token, "next_index": i + 3, "next_column": col + value.length(), "multiline": false, "error": ""}
		else:
			value += current_char
			i += 1
	
	value += "\n"
	var token = Token.new(TokenType.STRING, value, line_num, col)
	return {"token": token, "next_index": line.length(), "next_column": col + value.length(), "multiline": true, "error": ""}

func _continue_triple_string(line: String, line_num: int) -> Dictionary:
	var i = 0
	multiline_buffer += line
	
	while i < line.length():
		if i + 2 < line.length() and line.substr(i, 3) == triple_string_quote:
			multiline_buffer += triple_string_quote
			var token = Token.new(TokenType.STRING, multiline_buffer, multiline_start_line, 1)
			tokens.append(token)
			return {"complete": true}
		i += 1
	
	multiline_buffer += "\n"
	return {"complete": false}
