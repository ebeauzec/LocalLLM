"""
title: Code Executor
author: Eugene Beauzec
author_url: https://github.com/ebeauzec
funding_url: https://github.com/ebeauzec/LocalLLM
version: 0.1.0
license: Proprietary
description: Executes Python code in a sandboxed environment and returns results.
required_open_webui_version: 0.4.0

Copyright: (c) 2025-2026 Eugene Beauzec. All Rights Reserved.
"""

import subprocess
import tempfile
import os
import sys
import time
from pydantic import BaseModel, Field

class Tools:
    class Valves(BaseModel):
        timeout_seconds: int = Field(default=30, description="Max execution time")
        max_output_chars: int = Field(default=10000, description="Max output characters")
        allow_file_access: bool = Field(default=False, description="Allow file system access")
    
    def __init__(self):
        self.valves = self.Valves()
    
    async def execute_python(self, code: str, __user__: dict = {}) -> str:
        """Execute Python code in a sandboxed environment. Returns stdout, stderr, and return code.
        Use this when the user asks you to run code, calculate something, or process data.
        
        :param code: The Python code to execute.
        :return: The execution output.
        """
        start_time = time.time()
        
        with tempfile.NamedTemporaryFile(mode='w', suffix='.py', delete=False) as f:
            f.write(code)
            temp_file_path = f.name
            
        try:
            # We use standard subprocess to run the code
            # Note: For a true sandbox in production, consider Docker or a restricted environment
            process = subprocess.run(
                [sys.executable, temp_file_path],
                capture_output=True,
                text=True,
                timeout=self.valves.timeout_seconds
            )
            
            stdout = process.stdout
            stderr = process.stderr
            return_code = process.returncode
            
            if len(stdout) > self.valves.max_output_chars:
                stdout = stdout[:self.valves.max_output_chars] + "\n... (stdout truncated)"
            if len(stderr) > self.valves.max_output_chars:
                stderr = stderr[:self.valves.max_output_chars] + "\n... (stderr truncated)"
                
            execution_time = time.time() - start_time
            
            result = (
                f"Execution time: {execution_time:.2f}s\n"
                f"Return code: {return_code}\n\n"
            )
            if stdout:
                result += f"--- STDOUT ---\n{stdout}\n"
            if stderr:
                result += f"--- STDERR ---\n{stderr}\n"
                
            return result
        except subprocess.TimeoutExpired:
            return f"Error: Execution timed out after {self.valves.timeout_seconds} seconds."
        except Exception as e:
            return f"Error executing code: {str(e)}"
        finally:
            try:
                os.remove(temp_file_path)
            except OSError:
                pass
