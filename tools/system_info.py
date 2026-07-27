"""
title: System Information
author: Eugene Beauzec
version: 0.1.0
license: Proprietary
description: Retrieves local system information, processes, and network details.

Copyright: (c) 2025-2026 Eugene Beauzec. All Rights Reserved.
"""

import os
import platform
import subprocess
import json
from pydantic import BaseModel

class Tools:
    class Valves(BaseModel):
        pass
        
    def __init__(self):
        self.valves = self.Valves()
        
    async def system_status(self, __user__: dict = {}) -> str:
        """Get general system status (OS, Memory, Disk).
        Note: Python standard library limitations prevent deep cross-platform metrics without psutil.
        
        :return: Formatted system dashboard.
        """
        info = [
            f"OS: {platform.system()} {platform.release()} ({platform.version()})",
            f"Architecture: {platform.machine()}",
            f"Processor: {platform.processor()}",
            f"Node Name: {platform.node()}"
        ]
        
        if platform.system() == 'Windows':
            try:
                # Basic disk space check for Windows C:
                import ctypes
                free_bytes = ctypes.c_ulonglong(0)
                total_bytes = ctypes.c_ulonglong(0)
                ctypes.windll.kernel32.GetDiskFreeSpaceExW(ctypes.c_wchar_p(u'C:\\'), None, ctypes.pointer(total_bytes), ctypes.pointer(free_bytes))
                free_gb = free_bytes.value / (1024**3)
                total_gb = total_bytes.value / (1024**3)
                info.append(f"C: Drive: {free_gb:.1f} GB free of {total_gb:.1f} GB")
            except:
                pass
        else:
            try:
                st = os.statvfs('/')
                free_gb = (st.f_bavail * st.f_frsize) / (1024**3)
                total_gb = (st.f_blocks * st.f_frsize) / (1024**3)
                info.append(f"Root FS: {free_gb:.1f} GB free of {total_gb:.1f} GB")
            except:
                pass
                
        return "\n".join(info)

    async def process_list(self, __user__: dict = {}) -> str:
        """List running processes (Top 20).
        
        :return: Formatted list of running processes.
        """
        try:
            if platform.system() == 'Windows':
                # Use tasklist on Windows
                proc = subprocess.run(['tasklist', '/NH', '/FO', 'CSV'], capture_output=True, text=True)
                lines = [line for line in proc.stdout.split('\n') if line.strip()]
                output = ["Running Processes (Sample):"]
                for i, line in enumerate(lines[:20]):
                    parts = line.split('","')
                    if len(parts) >= 5:
                        name = parts[0].strip('"')
                        pid = parts[1].strip('"')
                        mem = parts[4].strip('"')
                        output.append(f"[{pid}] {name} - {mem}")
                return "\n".join(output)
            else:
                # Use ps on Linux/Mac
                proc = subprocess.run(['ps', '-eo', 'pid,comm,%mem,%cpu', '--sort=-%mem'], capture_output=True, text=True)
                lines = proc.stdout.split('\n')
                output = ["Running Processes (Top Memory):"]
                output.extend(lines[:21])
                return "\n".join(output)
        except Exception as e:
            return f"Error listing processes: {str(e)}"

    async def network_info(self, __user__: dict = {}) -> str:
        """Get network interfaces and connectivity info.
        
        :return: Network info.
        """
        try:
            if platform.system() == 'Windows':
                proc = subprocess.run(['ipconfig'], capture_output=True, text=True)
                return proc.stdout
            else:
                proc = subprocess.run(['ifconfig'], capture_output=True, text=True)
                if proc.returncode != 0:
                    proc = subprocess.run(['ip', 'addr'], capture_output=True, text=True)
                return proc.stdout
        except Exception as e:
            return f"Error getting network info: {str(e)}"
