"""
title: Image Analyzer
author: Eugene Beauzec
author_url: https://github.com/ebeauzec
version: 0.1.0
license: Proprietary
description: Analyzes images using local vision models (LLaVA). Falls back to cloud vision APIs only when local analysis fails and privacy settings allow. All cloud usage is logged.
required_open_webui_version: 0.4.0
"""

import json
import os
import urllib.request
import urllib.error
import hashlib
from datetime import datetime
from pydantic import BaseModel, Field

class Tools:
    class Valves(BaseModel):
        ollama_url: str = Field(default="http://ollama:11434", description="Ollama server URL")
        vision_model: str = Field(default="llava:7b", description="Local vision model")
        cloud_fallback_enabled: bool = Field(default=True, description="Enable cloud fallback")
        cloud_vision_api: str = Field(default="openai", description="Cloud vision API to use (openai/google)")
        privacy_mode: str = Field(default="BALANCED", description="STRICT/BALANCED/PERMISSIVE")
        audit_log_path: str = Field(default="/app/backend/data/privacy-audit.json", description="Path to audit log")
        max_image_size_mb: int = Field(default=20, description="Max image size in MB")

    def __init__(self):
        self.valves = self.Valves()

    def _log_cloud_usage(self, action: str, destination: str, content_type: str, content_hash: str, user: dict):
        """Log cloud API usage to privacy audit file."""
        entry = {
            "timestamp": datetime.utcnow().isoformat(),
            "action": action,
            "destination": destination,
            "content_type": content_type,
            "content_hash": content_hash,
            "user": user.get("name", "unknown"),
            "privacy_mode": self.valves.privacy_mode
        }
        
        try:
            os.makedirs(os.path.dirname(self.valves.audit_log_path), exist_ok=True)
            logs = []
            if os.path.exists(self.valves.audit_log_path):
                with open(self.valves.audit_log_path, 'r') as f:
                    try:
                        logs = json.load(f)
                    except:
                        logs = []
            logs.append(entry)
            with open(self.valves.audit_log_path, 'w') as f:
                json.dump(logs, f, indent=2)
        except Exception as e:
            print(f"Failed to write audit log: {e}")

    async def analyze_image(self, image_path: str, prompt: str = "Describe this image in detail.", __user__: dict = {}) -> str:
        """
        Main function to analyze an image. Tries local vision model first.
        Use this to get a description or analysis of any image.
        """
        try:
            # Here we would normally read the image and call Ollama
            # For this tool implementation, simulating a failure to trigger cloud fallback logic
            local_success = False 
            
            with open(image_path, 'rb') as f:
                image_data = f.read()
            content_hash = hashlib.sha256(image_data).hexdigest()
            
            if local_success:
                return "Local analysis result (mocked)."
                
            if self.valves.privacy_mode == "STRICT":
                return "Local analysis failed and cloud fallback is disabled in STRICT privacy mode."
                
            self._log_cloud_usage("image_analysis", self.valves.cloud_vision_api, "image", content_hash, __user__)
            
            if self.valves.privacy_mode == "BALANCED":
                return f"Cloud fallback needed. Image will be sent to {self.valves.cloud_vision_api}. [Details logged]"
                
            if self.valves.privacy_mode == "PERMISSIVE":
                return f"Cloud analysis result from {self.valves.cloud_vision_api} (mocked)."
                
        except Exception as e:
            return f"Error analyzing image: {str(e)}"

    async def extract_text_from_image(self, image_path: str, __user__: dict = {}) -> str:
        """
        OCR via Tika or local vision model.
        Use this to extract text from images containing text.
        """
        try:
            return "Extracted text via local OCR (mocked)."
        except Exception as e:
            return f"Error extracting text: {str(e)}"

    async def describe_diagram(self, image_path: str, __user__: dict = {}) -> str:
        """
        Specialized function for technical diagrams.
        Use this when analyzing flowcharts, architecture diagrams, or schematics.
        """
        try:
            prompt = "Analyze this technical diagram. Describe its structure, components, relationships, and any text labels."
            return await self.analyze_image(image_path, prompt, __user__)
        except Exception as e:
            return f"Error describing diagram: {str(e)}"
