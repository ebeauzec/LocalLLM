"""
title: Calculator
author: Eugene Beauzec
version: 0.1.0
license: Proprietary
description: Mathematical calculations, unit conversions, and statistics.

Copyright: (c) 2025-2026 Eugene Beauzec. All Rights Reserved.
"""

import ast
import operator
import math
import statistics as stats
from pydantic import BaseModel

# Safe math operators
_operators = {
    ast.Add: operator.add, ast.Sub: operator.sub, ast.Mult: operator.mul,
    ast.Div: operator.truediv, ast.Pow: operator.pow, ast.BitXor: operator.xor,
    ast.USub: operator.neg, ast.Mod: operator.mod, ast.FloorDiv: operator.floordiv
}

# Safe math functions
_functions = {
    'sqrt': math.sqrt, 'sin': math.sin, 'cos': math.cos, 'tan': math.tan,
    'log': math.log, 'log10': math.log10, 'exp': math.exp, 'abs': abs,
    'pi': math.pi, 'e': math.e, 'ceil': math.ceil, 'floor': math.floor
}

def _eval_expr(node):
    if isinstance(node, ast.Num): 
        return node.n
    elif isinstance(node, ast.BinOp):
        return _operators[type(node.op)](_eval_expr(node.left), _eval_expr(node.right))
    elif isinstance(node, ast.UnaryOp):
        return _operators[type(node.op)](_eval_expr(node.operand))
    elif isinstance(node, ast.Name):
        if node.id in _functions and not callable(_functions[node.id]):
            return _functions[node.id]
        raise ValueError(f"Unknown variable: {node.id}")
    elif isinstance(node, ast.Call):
        if isinstance(node.func, ast.Name) and node.func.id in _functions and callable(_functions[node.func.id]):
            args = [_eval_expr(arg) for arg in node.args]
            return _functions[node.func.id](*args)
        raise ValueError("Invalid function call")
    else:
        raise TypeError(f"Unsupported syntax: {type(node)}")

class Tools:
    class Valves(BaseModel):
        pass
        
    def __init__(self):
        self.valves = self.Valves()
        
    async def calculate(self, expression: str, __user__: dict = {}) -> str:
        """Evaluate a mathematical expression safely.
        Supports basic arithmetic (+, -, *, /, **), and math functions (sqrt, sin, cos, log, etc.).
        
        :param expression: The mathematical expression to evaluate (e.g., '2 + 2 * sqrt(16)').
        :return: The result of the calculation.
        """
        try:
            tree = ast.parse(expression, mode='eval')
            result = _eval_expr(tree.body)
            return str(result)
        except Exception as e:
            return f"Error evaluating expression: {str(e)}"
            
    async def unit_convert(self, value: float, from_unit: str, to_unit: str, __user__: dict = {}) -> str:
        """Convert a value from one unit to another.
        Currently supports simple length/weight conversions (m to ft, kg to lb, etc).
        
        :param value: The numerical value to convert.
        :param from_unit: The unit to convert from (e.g., 'm', 'kg', 'c').
        :param to_unit: The unit to convert to (e.g., 'ft', 'lb', 'f').
        :return: The converted value.
        """
        # A basic set of conversions to base units, then to target
        conversions = {
            'm': 1.0, 'cm': 0.01, 'mm': 0.001, 'km': 1000.0,
            'in': 0.0254, 'ft': 0.3048, 'yd': 0.9144, 'mi': 1609.344,
            
            'kg': 1.0, 'g': 0.001, 'mg': 0.000001,
            'lb': 0.45359237, 'oz': 0.02834952,
        }
        
        from_unit = from_unit.lower()
        to_unit = to_unit.lower()
        
        # Temperature is special
        if from_unit in ['c', 'f', 'k'] and to_unit in ['c', 'f', 'k']:
            celsius = value
            if from_unit == 'f': celsius = (value - 32) * 5/9
            elif from_unit == 'k': celsius = value - 273.15
            
            if to_unit == 'c': result = celsius
            elif to_unit == 'f': result = (celsius * 9/5) + 32
            elif to_unit == 'k': result = celsius + 273.15
            return f"{value} {from_unit} = {result:.4f} {to_unit}"
            
        if from_unit in conversions and to_unit in conversions:
            base_value = value * conversions[from_unit]
            target_value = base_value / conversions[to_unit]
            return f"{value} {from_unit} = {target_value:.4f} {to_unit}"
            
        return f"Error: Unsupported conversion from '{from_unit}' to '{to_unit}'."

    async def statistics(self, numbers_csv: str, __user__: dict = {}) -> str:
        """Calculate basic statistics (mean, median, stddev, min, max) for a list of numbers.
        
        :param numbers_csv: Comma-separated list of numbers (e.g., '1.5, 2.0, 3.1').
        :return: Formatted statistical summary.
        """
        try:
            nums = [float(x.strip()) for x in numbers_csv.split(',') if x.strip()]
            if not nums:
                return "Error: No valid numbers provided."
                
            n = len(nums)
            mean = stats.mean(nums)
            median = stats.median(nums)
            minimum = min(nums)
            maximum = max(nums)
            
            stdev = stats.stdev(nums) if n > 1 else 0.0
            
            return (
                f"Count: {n}\n"
                f"Sum: {sum(nums)}\n"
                f"Min: {minimum}\n"
                f"Max: {maximum}\n"
                f"Mean: {mean:.4f}\n"
                f"Median: {median:.4f}\n"
                f"StdDev: {stdev:.4f}"
            )
        except Exception as e:
            return f"Error calculating statistics: {str(e)}"
