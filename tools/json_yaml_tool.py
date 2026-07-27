"""
title: JSON & YAML Operations
author: Eugene Beauzec
version: 0.1.0
license: Proprietary
description: Parse, convert, and query JSON and YAML data.

Copyright: (c) 2025-2026 Eugene Beauzec. All Rights Reserved.
"""

import json
import csv
import io
from pydantic import BaseModel

class Tools:
    class Valves(BaseModel):
        pass
        
    def __init__(self):
        self.valves = self.Valves()
        
    async def parse_json(self, text: str, __user__: dict = {}) -> str:
        """Parse a JSON string and pretty-print it to ensure validity.
        
        :param text: The JSON string to parse.
        :return: Pretty-printed JSON or an error if invalid.
        """
        try:
            data = json.loads(text)
            return json.dumps(data, indent=2)
        except json.JSONDecodeError as e:
            return f"Invalid JSON: {str(e)}"
            
    async def json_to_yaml(self, json_str: str, __user__: dict = {}) -> str:
        """Convert a JSON string to YAML format natively (basic implementation without PyYAML).
        
        :param json_str: The JSON string to convert.
        :return: A basic YAML string.
        """
        try:
            data = json.loads(json_str)
            
            def dict_to_yaml(obj, indent=0):
                lines = []
                ind = "  " * indent
                if isinstance(obj, dict):
                    for k, v in obj.items():
                        if isinstance(v, (dict, list)) and len(v) > 0:
                            lines.append(f"{ind}{k}:")
                            lines.extend(dict_to_yaml(v, indent + 1))
                        else:
                            lines.append(f"{ind}{k}: {json.dumps(v)}")
                elif isinstance(obj, list):
                    for item in obj:
                        if isinstance(item, (dict, list)):
                            # Basic representation for complex lists
                            lines.append(f"{ind}- {json.dumps(item)}")
                        else:
                            lines.append(f"{ind}- {json.dumps(item)}")
                return lines
                
            return "\n".join(dict_to_yaml(data))
        except Exception as e:
            return f"Error converting JSON to YAML: {str(e)}"
            
    async def yaml_to_json(self, yaml_str: str, __user__: dict = {}) -> str:
        """Convert a basic YAML string to JSON.
        Note: This is a placeholder that reminds the user PyYAML is required for true YAML parsing.
        
        :param yaml_str: The YAML string.
        :return: Error or explanation since standard library lacks YAML parsing.
        """
        return "Error: Proper YAML to JSON conversion requires the PyYAML library which is not available in standard library."
        
    async def json_query(self, json_str: str, query_key: str, __user__: dict = {}) -> str:
        """Query a JSON string for a specific key (dot notation).
        
        :param json_str: The JSON string.
        :param query_key: A dot-notation key path (e.g. 'user.address.city').
        :return: The extracted value or error.
        """
        try:
            data = json.loads(json_str)
            keys = query_key.split('.')
            
            current = data
            for k in keys:
                if isinstance(current, dict) and k in current:
                    current = current[k]
                elif isinstance(current, list) and k.isdigit() and int(k) < len(current):
                    current = current[int(k)]
                else:
                    return f"Key '{k}' not found in the current object context."
                    
            return json.dumps(current, indent=2) if isinstance(current, (dict, list)) else str(current)
        except Exception as e:
            return f"Error querying JSON: {str(e)}"

    async def csv_to_json(self, csv_str: str, __user__: dict = {}) -> str:
        """Convert a CSV string to a JSON array of objects.
        
        :param csv_str: The CSV content.
        :return: A JSON array of dictionaries.
        """
        try:
            reader = csv.DictReader(io.StringIO(csv_str.strip()))
            data = [row for row in reader]
            return json.dumps(data, indent=2)
        except Exception as e:
            return f"Error converting CSV to JSON: {str(e)}"
            
    async def validate_json(self, json_str: str, schema_str: str, __user__: dict = {}) -> str:
        """Validate JSON against a basic type schema (Standard Lib only).
        Schema format example: {"name": "str", "age": "int", "active": "bool"}
        
        :param json_str: The JSON to validate.
        :param schema_str: The basic schema structure as JSON.
        :return: Validation result.
        """
        try:
            data = json.loads(json_str)
            schema = json.loads(schema_str)
            
            errors = []
            if not isinstance(data, dict):
                return "Root of JSON must be an object to validate against this basic schema."
                
            for key, expected_type in schema.items():
                if key not in data:
                    errors.append(f"Missing required key: '{key}'")
                    continue
                    
                val = data[key]
                if expected_type == "str" and not isinstance(val, str):
                    errors.append(f"Key '{key}' expected str, got {type(val).__name__}")
                elif expected_type == "int" and not isinstance(val, int):
                    errors.append(f"Key '{key}' expected int, got {type(val).__name__}")
                elif expected_type == "bool" and not isinstance(val, bool):
                    errors.append(f"Key '{key}' expected bool, got {type(val).__name__}")
                elif expected_type == "float" and not isinstance(val, float):
                    errors.append(f"Key '{key}' expected float, got {type(val).__name__}")
                elif expected_type == "list" and not isinstance(val, list):
                    errors.append(f"Key '{key}' expected list, got {type(val).__name__}")
                elif expected_type == "dict" and not isinstance(val, dict):
                    errors.append(f"Key '{key}' expected dict, got {type(val).__name__}")
                    
            if errors:
                return "Validation failed:\n" + "\n".join(errors)
            return "Validation successful!"
            
        except Exception as e:
            return f"Error during validation: {str(e)}"
