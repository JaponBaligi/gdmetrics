extends RefCounted
class_name CogComplexityCalculator

# Cognitive Complexity calculator
# Formula: C-COG = sum of (1 + depth) for each control flow structure
# Special rule: case statements count as +1 regardless of nesting depth

class CogComplexityResult:
	var total_cog: int = 0
	var breakdown: Dictionary = {}
	var per_function: Dictionary = {}
	
	func _init():
		breakdown = {
			"if": 0,
			"elif": 0,
			"for": 0,
			"while": 0,
			"match": 0,
			"case": 0,
			"and": 0,
			"or": 0,
			"not": 0
		}

var result: CogComplexityResult
var in_match_block: bool = false
var match_start_line: int = -1

func calculate_cog(control_flow_nodes: Array, functions: Array = []) -> CogComplexityResult:
	result = CogComplexityResult.new()
	in_match_block = false
	match_start_line = -1
	
	if control_flow_nodes.is_empty():
		return result
	
	var i = 0
	while i < control_flow_nodes.size():
		var node = control_flow_nodes[i]
		
		if node.type == "match":
			in_match_block = true
			match_start_line = node.line
			var contribution = 1 + node.depth
			result.total_cog += contribution
			result.breakdown["match"] += contribution
		elif node.type == "case":
			if in_match_block:
				var contribution = 1
				result.total_cog += contribution
				result.breakdown["case"] += contribution
		elif node.type == "if":
			var contribution = 1 + node.depth
			result.total_cog += contribution
			result.breakdown["if"] += contribution
		elif node.type == "elif":
			var contribution = 1 + node.depth
			result.total_cog += contribution
			result.breakdown["elif"] += contribution
		elif node.type == "for":
			var contribution = 1 + node.depth
			result.total_cog += contribution
			result.breakdown["for"] += contribution
		elif node.type == "while":
			var contribution = 1 + node.depth
			result.total_cog += contribution
			result.breakdown["while"] += contribution
		elif node.type == "and":
			var contribution = 1 + node.depth
			result.total_cog += contribution
			result.breakdown["and"] += contribution
		elif node.type == "or":
			var contribution = 1 + node.depth
			result.total_cog += contribution
			result.breakdown["or"] += contribution
		elif node.type == "not":
			var contribution = 1 + node.depth
			result.total_cog += contribution
			result.breakdown["not"] += contribution
		
		i += 1
	
	if not functions.is_empty():
		_calculate_per_function(control_flow_nodes, functions)
	
	return result

func _calculate_per_function(control_flow_nodes: Array, functions: Array):
	for func_info in functions:
		var func_nodes: Array = []
		for node in control_flow_nodes:
			if node.line >= func_info.start_line and node.line <= func_info.end_line:
				func_nodes.append(node)
		
		var func_result = CogComplexityResult.new()
		in_match_block = false
		match_start_line = -1
		
		for node in func_nodes:
			if node.type == "match":
				in_match_block = true
				match_start_line = node.line
				var contribution = 1 + node.depth
				func_result.total_cog += contribution
				func_result.breakdown["match"] += contribution
			elif node.type == "case":
				if in_match_block:
					var contribution = 1
					func_result.total_cog += contribution
					func_result.breakdown["case"] += contribution
			elif node.type == "if":
				var contribution = 1 + node.depth
				func_result.total_cog += contribution
				func_result.breakdown["if"] += contribution
			elif node.type == "elif":
				var contribution = 1 + node.depth
				func_result.total_cog += contribution
				func_result.breakdown["elif"] += contribution
			elif node.type == "for":
				var contribution = 1 + node.depth
				func_result.total_cog += contribution
				func_result.breakdown["for"] += contribution
			elif node.type == "while":
				var contribution = 1 + node.depth
				func_result.total_cog += contribution
				func_result.breakdown["while"] += contribution
			elif node.type == "and":
				var contribution = 1 + node.depth
				func_result.total_cog += contribution
				func_result.breakdown["and"] += contribution
			elif node.type == "or":
				var contribution = 1 + node.depth
				func_result.total_cog += contribution
				func_result.breakdown["or"] += contribution
			elif node.type == "not":
				var contribution = 1 + node.depth
				func_result.total_cog += contribution
				func_result.breakdown["not"] += contribution
		
		result.per_function[func_info.name] = func_result.total_cog

func get_total_cog() -> int:
	if result == null:
		return 0
	return result.total_cog

func get_breakdown() -> Dictionary:
	if result == null:
		return {}
	return result.breakdown.duplicate()

func get_per_function() -> Dictionary:
	if result == null:
		return {}
	return result.per_function.duplicate()

