"""
title: Privacy Audit Filter
author: Eugene Beauzec
author_url: https://github.com/ebeauzec
version: 0.2.0
license: Proprietary
description: Intercepts all LLM requests, detects sensitive data, logs cloud API usage, enforces privacy policies, and tracks comprehensive metrics.
required_open_webui_version: 0.4.0
"""

from pydantic import BaseModel, Field
from typing import Optional, List, Dict, Any
import json
import os
import re
import hashlib
import time
from datetime import datetime

class Filter:
    class Valves(BaseModel):
        priority: int = Field(default=0, description="Filter priority (lower = runs first)")
        privacy_mode: str = Field(default="BALANCED", description="Privacy mode: STRICT, BALANCED, PERMISSIVE")
        audit_log_path: str = Field(default="/app/backend/data/privacy-audit.jsonl", description="Path to audit log")
        metrics_path: str = Field(default="/app/backend/data/localllm-metrics.json", description="Path to aggregated metrics")
        show_cost_notices: bool = Field(default=True, description="Show cost information in cloud responses")
        enable_sensitive_detection: bool = Field(default=True, description="Enable PII detection")
        block_on_sensitive: bool = Field(default=True, description="Block cloud requests containing sensitive data")

    CLOUD_PRICING = {
        "gpt-4o": 2.50,
        "gpt-4o-mini": 0.15,
        "gpt-4-turbo": 10.00,
        "gpt-3.5-turbo": 0.50,
        "claude-3.5-sonnet": 3.00,
        "claude-3-opus": 15.00,
        "claude-3-haiku": 0.25,
        "gemini-1.5-pro": 1.25,
        "gemini-1.5-flash": 0.075,
        "gemini-2.0-flash": 0.10,
        "default_cloud": 2.50,
    }

    def __init__(self):
        self.valves = self.Valves()
        
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

    def _estimate_tokens(self, text: str) -> int:
        """Rough token estimate: ~4 chars per token."""
        return max(1, len(text) // 4)

    def _estimate_cost(self, model: str, tokens: int) -> float:
        """Estimate cost in USD for the given model and token count."""
        for name, price in self.CLOUD_PRICING.items():
            if name in model.lower():
                return (tokens / 1_000_000) * price
        return (tokens / 1_000_000) * self.CLOUD_PRICING['default_cloud']

    def _estimate_savings(self, model: str, tokens: int, is_cloud: bool) -> float:
        """Calculate how much was saved by processing locally."""
        if not is_cloud:
            return (tokens / 1_000_000) * self.CLOUD_PRICING['default_cloud']
        return 0.0

    def _is_cloud_model(self, model: str) -> bool:
        local_prefixes = ['ollama/', 'localllm-', 'localhost']
        for prefix in local_prefixes:
            if prefix in model.lower():
                return False
        cloud_prefixes = ['gpt-', 'claude-', 'gemini-', 'openai/', 'anthropic/']
        for prefix in cloud_prefixes:
            if prefix in model.lower():
                return True
        return True 

    def _get_destination(self, is_cloud: bool, model: str) -> str:
        if not is_cloud:
            return "local"
        if "gpt" in model.lower() or "openai" in model.lower():
            return "OpenAI"
        if "claude" in model.lower() or "anthropic" in model.lower():
            return "Anthropic"
        if "gemini" in model.lower() or "google" in model.lower():
            return "Google"
        return "Unknown Cloud"

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

    def _load_metrics(self) -> dict:
        try:
            if os.path.exists(self.valves.metrics_path):
                with open(self.valves.metrics_path, 'r') as f:
                    return json.load(f)
        except Exception:
            pass
        return {}

    def _save_metrics(self, metrics: dict):
        try:
            os.makedirs(os.path.dirname(self.valves.metrics_path), exist_ok=True)
            with open(self.valves.metrics_path, 'w') as f:
                json.dump(metrics, f, indent=2)
        except Exception as e:
            print(f"Failed to write metrics: {e}")

    def _update_metrics(self, is_cloud: bool, tokens: int, cost: float, savings: float, model: str, findings: dict):
        """Update the aggregate metrics file."""
        metrics = self._load_metrics()
        today = datetime.utcnow().strftime("%Y-%m-%d")
        
        # Global totals
        metrics["total_requests"] = metrics.get("total_requests", 0) + 1
        metrics["total_local"] = metrics.get("total_local", 0) + (0 if is_cloud else 1)
        metrics["total_cloud"] = metrics.get("total_cloud", 0) + (1 if is_cloud else 0)
        metrics["total_tokens"] = metrics.get("total_tokens", 0) + tokens
        metrics["total_local_tokens"] = metrics.get("total_local_tokens", 0) + (tokens if not is_cloud else 0)
        metrics["total_cloud_tokens"] = metrics.get("total_cloud_tokens", 0) + (tokens if is_cloud else 0)
        metrics["total_cost_usd"] = metrics.get("total_cost_usd", 0) + cost
        metrics["total_savings_usd"] = metrics.get("total_savings_usd", 0) + savings
        metrics["total_sensitive_blocked"] = metrics.get("total_sensitive_blocked", 0) + (1 if findings else 0)
        
        # Daily breakdown
        daily = metrics.setdefault("daily", {})
        day = daily.setdefault(today, {"requests": 0, "local": 0, "cloud": 0, "tokens": 0, "cost": 0, "savings": 0})
        day["requests"] += 1
        day["local"] += 0 if is_cloud else 1
        day["cloud"] += 1 if is_cloud else 0
        day["tokens"] += tokens
        day["cost"] += cost
        day["savings"] += savings
        
        # Model usage
        model_stats = metrics.setdefault("models", {})
        ms = model_stats.setdefault(model, {"count": 0, "tokens": 0, "cost": 0})
        ms["count"] += 1
        ms["tokens"] += tokens
        ms["cost"] += cost
        
        metrics["last_updated"] = datetime.utcnow().isoformat() + "Z"
        self._save_metrics(metrics)

    def _log_audit(self, user_id: str, model: str, is_cloud: bool, findings: Dict[str, List[str]], action: str, content: str, content_type: str, tokens: int, cost: float, savings: float, response_time_ms: int = 0):
        content_hash = hashlib.sha256(content.encode('utf-8')).hexdigest()
        destination = self._get_destination(is_cloud, model)
        
        log_entry = {
            "timestamp": datetime.utcnow().isoformat() + "Z",
            "user": user_id,
            "model": model,
            "is_cloud": is_cloud,
            "sensitive_data_found": list(findings.keys()),
            "action_taken": action,
            "content_hash": content_hash,
            "request_tokens": tokens,
            "destination": destination,
            "privacy_mode": self.valves.privacy_mode,
            "content_type": content_type,
            "estimated_cost_usd": cost,
            "cost_saved_usd": savings,
            "response_time_ms": response_time_ms
        }
        
        try:
            os.makedirs(os.path.dirname(self.valves.audit_log_path), exist_ok=True)
            with open(self.valves.audit_log_path, 'a') as f:
                f.write(json.dumps(log_entry) + '\n')
        except Exception as e:
            print(f"Failed to write privacy audit log: {e}")

    async def inlet(self, body: dict, __user__: Optional[dict] = None) -> dict:
        """Intercept incoming requests before they reach the model."""
        body['metadata'] = body.get('metadata', {})
        body['metadata']['localllm_start_time'] = time.time()
        
        messages = body.get('messages', [])
        if not messages:
            return body
            
        latest_message = messages[-1].get('content', '')
        content_type = "text"
        
        if not isinstance(latest_message, str):
            text_content = " ".join([m.get("text", "") for m in latest_message if m.get("type") == "text"])
            original_content = str(latest_message)
            content_type = "multimodal"
        else:
            text_content = latest_message
            original_content = latest_message
            
        model = body.get('model', '')
        user_id = __user__.get('id', 'unknown') if __user__ else 'unknown'
        
        is_cloud = self._is_cloud_model(model)
        findings = self._detect_sensitive_data(text_content)
        has_sensitive = len(findings) > 0
        
        action = "ALLOWED"
        
        tokens = self._estimate_tokens(text_content)
        cost = self._estimate_cost(model, tokens) if is_cloud else 0.0
        savings = self._estimate_savings(model, tokens, is_cloud)
        
        if is_cloud:
            if self.valves.privacy_mode == "STRICT":
                action = "BLOCKED_STRICT"
                error_msg = "⚠️ BLOCKED: Cloud API request blocked by privacy policy. Switch to a local model or change privacy mode."
                self._update_metrics(is_cloud, tokens, 0.0, 0.0, model, findings)
                self._log_audit(user_id, model, is_cloud, findings, action, original_content, content_type, tokens, 0.0, 0.0)
                raise Exception(error_msg)
                
            elif self.valves.privacy_mode == "BALANCED":
                if has_sensitive and self.valves.block_on_sensitive:
                    action = "BLOCKED_SENSITIVE"
                    detected = ", ".join(findings.keys())
                    error_msg = f"⚠️ BLOCKED: Sensitive data ({detected}) detected in cloud request. Please remove it or use a local model."
                    self._update_metrics(is_cloud, tokens, 0.0, 0.0, model, findings)
                    self._log_audit(user_id, model, is_cloud, findings, action, original_content, content_type, tokens, 0.0, 0.0)
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
        
        self._update_metrics(is_cloud, tokens, cost, savings, model, findings)
        self._log_audit(user_id, model, is_cloud, findings, action, original_content, content_type, tokens, cost, savings)
        return body
        
    async def outlet(self, body: dict, __user__: Optional[dict] = None) -> dict:
        """Intercept outgoing responses before they reach the user."""
        model = body.get('model', '')
        is_cloud = self._is_cloud_model(model)
        
        messages = body.get('messages', [])
        response_text = ""
        if messages and messages[-1].get('role') == 'assistant':
            response_text = messages[-1].get('content', '')
            
        tokens = self._estimate_tokens(response_text)
        cost = self._estimate_cost(model, tokens) if is_cloud else 0.0
        savings = self._estimate_savings(model, tokens, is_cloud)
        
        start_time = body.get('metadata', {}).get('localllm_start_time', time.time())
        response_time_ms = int((time.time() - start_time) * 1000)
        user_id = __user__.get('id', 'unknown') if __user__ else 'unknown'
        
        # Log response metrics
        self._update_metrics(is_cloud, tokens, cost, savings, model, {})
        self._log_audit(user_id, model, is_cloud, {}, "RESPONSE", response_text, "text", tokens, cost, savings, response_time_ms)
        
        if is_cloud and self.valves.show_cost_notices:
            destination = self._get_destination(is_cloud, model)
            notice = f"\n\n---\n🔒 *Cloud response via {destination} ({model}) — ~{tokens:,} tokens — Est. cost: ${cost:.3f} — [View savings report](http://localhost:3000)*"
            
            if messages and messages[-1].get('role') == 'assistant':
                messages[-1]['content'] += notice
                
        return body
