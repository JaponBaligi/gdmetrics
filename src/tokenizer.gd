extends Reference
class_name GDScriptTokenizer

# Basic tokenizer for GDScript
# Keywords, identifiers, operators, single-line comments, single-line strings, integers/floats

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
	"func", "class", "extends", "var", "const", "signal",
	"and", "or", "not", "true", "false", "null",
	"pass", "self", "super"
]

const SINGLE_OPS = ["+", "-", "*", "/", "%", "=", "<", ">", "!", "&", "|", "^", "~", "?", ":", ".", ",", ";", "(", ")", "[", "]", "{", "}"]

const DOUBLE_OPS = ["==", "!=", "<=", ">=", "&&", "||", "->", "::", "..", "+=", "-=", "*=", "/=", "%="]

var tokens: Array = []
var errors: Array = []

func tokenize_file(file_path: String) -> Array:

	tokens.clear()
	errors.clear()
	
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
	return tokens.duplicate()

func tokenize_line(line: String, line_number: int):

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

		if char == "#":
			var comment_text = line.substr(i)
			tokens.append(Token.new(TokenType.COMMENT, comment_text, line_number, column))
			break

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

	if value == "-" or value == "." or value == "-.":
		# Not a valid number, treat as operator/identifier
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

