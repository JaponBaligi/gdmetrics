extends RefCounted
class_name GDScriptTokenizer

# Tokenizer for GDScript
# Keywords, identifiers, operators, comments, strings, numbers 

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
	
	var file = File.new()
	if not file.file_exists(file_path):
		errors.append("File not found: %s" % file_path)
		return []
	
	if file.open(file_path, File.READ) != OK:
		errors.append("Failed to open file: %s" % file_path)
		return []
	
	var line_number = 1
	while not file.eof_reached():
		var line = file.get_line()
		tokenize_line(line, line_number)
		line_number += 1
	
	file.close()
	
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
		var char = line[i]
		if char in " \t":
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

		if char == "#":
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

		if char == '"' or char == "'":
			var string_result = _parse_string(line, i, line_number, column, char)
			if string_result.error:
				errors.append("Line %d:%d: %s" % [line_number, column, string_result.error])
				i += 1
				column += 1
			else:
				tokens.append(string_result.token)
				i = string_result.next_index
				column = string_result.next_column
			continue

		if char.is_valid_integer() or (char == "." and i + 1 < line.length() and line[i + 1].is_valid_integer()):
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
		
		if char in SINGLE_OPS:
			tokens.append(Token.new(TokenType.OPERATOR, char, line_number, column))
			i += 1
			column += 1
			continue

		if char.is_valid_identifier_char() or char == "_":
			var ident_result = _parse_identifier(line, i, line_number, column)
			tokens.append(ident_result.token)
			i = ident_result.next_index
			column = ident_result.next_column
			continue

		errors.append("Line %d:%d: Unknown character '%s'" % [line_number, column, char])
		i += 1
		column += 1

func _parse_string(line: String, start: int, line_num: int, col: int, quote_char: String) -> Dictionary:

	var i = start + 1
	var value = quote_char
	var escaped = false
	
	while i < line.length():
		var char = line[i]
		
		if escaped:
			if char == "n":
				value += "\\n"
			elif char == "t":
				value += "\\t"
			elif char == "r":
				value += "\\r"
			elif char == "\\":
				value += "\\\\"
			elif char == quote_char:
				value += "\\" + quote_char
			else:
				value += "\\" + char
			escaped = false
			i += 1
		elif char == "\\":
			escaped = true
			i += 1
		elif char == quote_char:
			value += quote_char
			var token = Token.new(TokenType.STRING, value, line_num, col)
			return {"token": token, "next_index": i + 1, "next_column": col + value.length(), "error": ""}
		else:
			value += char
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
	
	while i < line.length() and line[i].is_valid_integer():
		value += line[i]
		i += 1
	
	if i < line.length() and line[i] == ".":
		has_dot = true
		value += "."
		i += 1
		while i < line.length() and line[i].is_valid_integer():
			value += line[i]
			i += 1

	if i < line.length() and (line[i] == "e" or line[i] == "E"):
		value += line[i]
		i += 1
		if i < line.length() and (line[i] == "+" or line[i] == "-"):
			value += line[i]
			i += 1
		var exp_start = i
		while i < line.length() and line[i].is_valid_integer():
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

	if i < line.length() and (line[i].is_valid_identifier_char() or line[i] == "_"):
		value += line[i]
		i += 1

		while i < line.length() and (line[i].is_valid_identifier_char() or line[i].is_valid_integer() or line[i] == "_"):
			value += line[i]
			i += 1

	var token_type = TokenType.KEYWORD if value in KEYWORDS else TokenType.IDENTIFIER
	var token = Token.new(token_type, value, line_num, col)
	return {"token": token, "next_index": i, "next_column": col + value.length()}

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
		var char = line[i]
		
		if escaped:
			if char == "n":
				value += "\\n"
			elif char == "t":
				value += "\\t"
			elif char == "r":
				value += "\\r"
			elif char == "\\":
				value += "\\\\"
			elif char == quote_chars[0]:
				value += "\\" + quote_chars[0]
			else:
				value += "\\" + char
			escaped = false
			i += 1
		elif char == "\\":
			escaped = true
			i += 1
		elif i + 2 < line.length() and line.substr(i, 3) == quote_chars:
			value += quote_chars
			var token = Token.new(TokenType.STRING, value, line_num, col)
			return {"token": token, "next_index": i + 3, "next_column": col + value.length(), "multiline": false, "error": ""}
		else:
			value += char
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
