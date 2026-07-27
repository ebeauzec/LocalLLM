"""
title: Privacy Audit Filter
author: Eugene Beauzec
author_url: https://github.com/ebeauzec
version: 0.1.0
license: Proprietary
description: Intercepts all LLM requests, detects sensitive data, logs cloud API usage, and enforces privacy policies. This filter runs on EVERY request.
required_open_webui_version: 0.4.0
"""

from pydantic import BaseModel, Field
from typing import Optional, List, Dict, Any
import json
import os
import re
import hashlib
from datetime import datetime

class Filter:
    class Valves(BaseModel):
        priority: int = Field(default=0, description="Filter priority (lower = runs first)")
        privacy_mode: str = Field(default="BALANCED", description="Privacy mode: STRICT, BALANCED, PERMISSIVE")
        audit_log_path: str = Field(default="/app/backend/data/privacy-audit.jsonl", description="Path to audit log")
        enable_sensitive_detection: bool = Field(default=True, description="Enable PII detection")
        block_on_sensitive: bool = Field(default=True, description="Block cloud requests containing sensitive data")

    def __init__(self):
        self.valves = self.Valves()
        
        # Regex patterns for sensitive data
        self.sensitive_patterns = {
            "credit_card": re.compile(r'\b(?:4[0-9]{12}(?:[0-9]{3})?|5[1-5][0-9]{14}|3[47][0-9]{13})\b'),
            "ssn": re.compile(r'\b\d{3}-\d{2}-\d{4}\b'),
            "email": re.compile(r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b'),
            "api_key": re.compile(r'\b(?:sk-[a-zA-Z0-9]{32,}|ghp_[a-zA-Z0-9]{36,}|AKIA[0-9A-Z]{16})\b'),
            "private_key": re.compile(r'-----BEGIN (?:RSA |EC )?PRIVATE KEY-----'),
            "internal_ip": re.compile(r'\b(?:10\.\d{1,3}\.\d{1,3}\.\d{1,3}|192\.168\.\d{1,3}\.\d{1,3}|172\.(?:1[6-9]|2\d|3[0-1])\.\d{1,3}\.\d{1,3})\b'),
            "db_conn": re.compile(r'(?:Server=|mongodb://|postgres://)[^\s]+'),
            "password": re.compile(r'(?i)(?:password=|passwd:|secret=)[^\s]+')
        }
        
    def _is_cloud_model(self, model: str) -> bool:
        local_prefixes = ['ollama/', 'localllm-', 'localhost']
        for prefix in local_prefixes:
            if prefix in model.lower():
                return False
                
        cloud_prefixes = ['gpt-', 'claude-', 'gemini-', 'openai/', 'anthropic/']
        for prefix in cloud_prefixes:
            if prefix in model.lower():
                return True
                
        return True # Default to cloud if unknown to be safe

    def _detect_sensitive_data(self, text: str) -> Dict[str, List[str]]:
        findings = {}
        if not self.valves.enable_sensitive_detection:
            return findings
            
        for name, pattern in self.sensitive_patterns.items():
            matches = pattern.findall(text)
            if matches:
                findings[name] = matches
        return findings

    def _redact_sensitive_data(self, text: str, findings: Dict[str, List[str]]) -> str:
        redacted = text
        for name, matches in findings.items():
            for match in matches:
                redacted = redacted.replace(match, f"[REDACTED {name.upper()}]")
        return redacted

    def _log_audit(self, user_id: str, model: str, is_cloud: bool, findings: Dict[str, List[str]], action: str, content: str):
        content_hash = hashlib.sha256(content.encode('utf-8')).hexdigest()
        
        log_entry = {
            "timestamp": datetime.utcnow().isoformat() + "Z",
            "user": user_id,
            "model": model,
            "is_cloud": is_cloud,
            "sensitive_data_found": list(findings.keys()),
            "action_taken": action,
            "content_hash": content_hash
        }
        
        try:
            os.makedirs(os.path.dirname(self.valves.audit_log_path), exist_ok=True)
            with open(self.valves.audit_log_path, 'a') as f:
                f.write(json.dumps(log_entry) + '\n')
        except Exception as e:
            print(f"Failed to write privacy audit log: {e}")

    async def inlet(self, body: dict, __user__: Optional[dict] = None) -> dict:
        """Intercept incoming requests before they reach the model."""
        messages = body.get('messages', [])
        if not messages:
            return body
            
        latest_message = messages[-1].get('content', '')
        if not isinstance(latest_message, str):
            # Complex content (e.g., list with images), handle text parts
            text_content = " ".join([m.get("text", "") for m in latest_message if m.get("type") == "text"])
            original_content = str(latest_message)
        else:
            text_content = latest_message
            original_content = latest_message
            
        model = body.get('model', '')
        user_id = __user__.get('id', 'unknown') if __user__ else 'unknown'
        
        is_cloud = self._is_cloud_model(model)
        findings = self._detect_sensitive_data(text_content)
        has_sensitive = len(findings) > 0
        
        action = "ALLOWED"
        
        if is_cloud:
            if self.valves.privacy_mode == "STRICT":
                action = "BLOCKED_STRICT"
                error_msg = "⚠️ BLOCKED: Cloud API request blocked by privacy policy. Switch to a local model or change privacy mode."
                raise Exception(error_msg)
                
            elif self.valves.privacy_mode == "BALANCED":
                if has_sensitive and self.valves.block_on_sensitive:
                    action = "BLOCKED_SENSITIVE"
                    detected = ", ".join(findings.keys())
                    error_msg = f"⚠️ BLOCKED: Sensitive data ({detected}) detected in cloud request. Please remove it or use a local model."
                    raise Exception(error_msg)
                elif has_sensitive:
                    action = "WARNED_SENSITIVE"
                    detected = ", ".join(findings.keys())
                    warning = f"⚠️ WARNING: Sending sensitive data ({detected}) to a cloud provider.\n\n"
                    if isinstance(messages[-1]['content'], str):
                        messages[-1]['content'] = warning + messages[-1]['content']
            
            elif self.valves.privacy_mode == "PERMISSIVE":
                if has_sensitive:
                    action = "REDACTED"
                    if isinstance(messages[-1]['content'], str):
                        messages[-1]['content'] = self._redact_sensitive_data(messages[-1]['content'], findings)
                    else:
                        for part in messages[-1]['content']:
                            if part.get("type") == "text":
                                part["text"] = self._redact_sensitive_data(part["text"], findings)
        
        self._log_audit(user_id, model, is_cloud, findings, action, original_content)
        return body
        
    async def outlet(self, body: dict, __user__: Optional[dict] = None) -> dict:
        """Intercept outgoing responses before they reach the user."""
        model = body.get('model', '')
        is_cloud = self._is_cloud_model(model)
        
        if is_cloud:
            # Determine provider
            provider = "OpenAI" if "gpt" in model else "Anthropic" if "claude" in model else "Google" if "gemini" in model else "a Cloud Provider"
            
            notice = f"\n\n---\n🔒 *This response was generated by {model}. Content was sent to {provider}'s servers. [View privacy report](http://localhost:3000/privacy)*"
            
            # Open WebUI standard outlet format modification
            if 'messages' in body and len(body['messages']) > 0:
                last_msg = body['messages'][-1]
                if last_msg.get('role') == 'assistant':
                    last_msg['content'] += notice
        
        return body
