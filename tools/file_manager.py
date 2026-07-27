"""
title: Local File Manager
author: Eugene Beauzec
version: 0.1.0
license: Proprietary
description: Read, write, and manage files on the local system for document processing.

Copyright: (c) 2025-2026 Eugene Beauzec. All Rights Reserved.
"""

import os
import glob
from pydantic import BaseModel, Field

class Tools:
    class Valves(BaseModel):
        allowed_directories: str = Field(default="", description="Comma-separated list of allowed absolute directories (empty for all)")
        max_file_size_kb: int = Field(default=1024, description="Maximum file size to read in KB")
    
    def __init__(self):
        self.valves = self.Valves()
        
    def _is_path_allowed(self, path: str) -> bool:
        if not self.valves.allowed_directories:
            return True
            
        allowed = [d.strip() for d in self.valves.allowed_directories.split(',') if d.strip()]
        abs_path = os.path.abspath(path)
        
        for d in allowed:
            if abs_path.startswith(os.path.abspath(d)):
                return True
        return False

    async def read_file(self, path: str, __user__: dict = {}) -> str:
        """Read a file and return its contents.
        
        :param path: The absolute or relative path to the file.
        :return: The file contents or error message.
        """
        if not self._is_path_allowed(path):
            return f"Error: Access to path '{path}' is not allowed by configuration."
            
        if not os.path.exists(path) or not os.path.isfile(path):
            return f"Error: File '{path}' does not exist or is not a file."
            
        file_size = os.path.getsize(path) / 1024
        if file_size > self.valves.max_file_size_kb:
            return f"Error: File exceeds maximum allowed size ({file_size:.1f} KB > {self.valves.max_file_size_kb} KB)."
            
        try:
            with open(path, 'r', encoding='utf-8') as f:
                return f.read()
        except Exception as e:
            return f"Error reading file: {str(e)}"

    async def write_file(self, path: str, content: str, __user__: dict = {}) -> str:
        """Write content to a file.
        
        :param path: The path to write to.
        :param content: The content to write.
        :return: Success or error message.
        """
        if not self._is_path_allowed(path):
            return f"Error: Access to path '{path}' is not allowed by configuration."
            
        try:
            os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
            with open(path, 'w', encoding='utf-8') as f:
                f.write(content)
            return f"Successfully wrote {len(content)} characters to '{path}'."
        except Exception as e:
            return f"Error writing file: {str(e)}"

    async def list_directory(self, path: str, __user__: dict = {}) -> str:
        """List files and subdirectories in a directory.
        
        :param path: The directory path to list.
        :return: Formatted list of contents.
        """
        if not self._is_path_allowed(path):
            return f"Error: Access to path '{path}' is not allowed by configuration."
            
        if not os.path.exists(path) or not os.path.isdir(path):
            return f"Error: Directory '{path}' does not exist or is not a directory."
            
        try:
            items = os.listdir(path)
            result = [f"Contents of {path}:"]
            for item in items:
                item_path = os.path.join(path, item)
                if os.path.isdir(item_path):
                    result.append(f"[DIR]  {item}")
                else:
                    size = os.path.getsize(item_path)
                    result.append(f"[FILE] {item} ({size} bytes)")
            return "\n".join(result)
        except Exception as e:
            return f"Error listing directory: {str(e)}"

    async def search_files(self, directory: str, pattern: str, __user__: dict = {}) -> str:
        """Search for files matching a pattern within a directory recursively.
        
        :param directory: The directory to search in.
        :param pattern: The glob pattern (e.g., '*.py').
        :return: List of matching file paths.
        """
        if not self._is_path_allowed(directory):
            return f"Error: Access to path '{directory}' is not allowed by configuration."
            
        try:
            search_path = os.path.join(directory, "**", pattern)
            matches = glob.glob(search_path, recursive=True)
            
            if not matches:
                return f"No files matched pattern '{pattern}' in '{directory}'."
                
            return "Matches found:\n" + "\n".join(matches)
        except Exception as e:
            return f"Error searching files: {str(e)}"
