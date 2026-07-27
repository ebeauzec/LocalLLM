# Copyright (c) 2025-2026 Eugene Beauzec. All Rights Reserved.
#
# LocalLLM Auto-Router Filter — Intelligent Model Selection
# Works WITH Open WebUI's RAG pipeline (files, knowledge bases).
# Analyzes user requests and changes the model before inference.

"""
title: LocalLLM Auto-Router
description: Automatically selects the best specialist model based on your request. Supports file uploads and RAG.
author: Eugene Beauzec
version: 2.0.0
licence: Proprietary
"""

import re
from typing import Optional
from pydantic import BaseModel, Field


class Filter:
    """
    Open WebUI Filter that intercepts requests, classifies them,
    and routes to the optimal model — while preserving RAG/file support.
    """

    class Valves(BaseModel):
        FAST_MODEL: str = Field(
            default="qwen3:8b",
            description="Fast model for simple/quick requests"
        )
        POWER_MODEL: str = Field(
            default="llama3.3:70b-instruct-q4_K_M",
            description="Powerful model for complex requests"
        )
        CODE_MODEL: str = Field(
            default="qwen2.5-coder:32b-instruct-q8_0",
            description="Specialized code model"
        )
        COMPLEXITY_THRESHOLD: int = Field(
            default=50,
            description="Word count threshold: below = fast model, above = power model"
        )
        SHOW_ROUTING: bool = Field(
            default=True,
            description="Prepend routing indicator to responses"
        )

    def __init__(self):
        self.valves = self.Valves()

        # Task classification patterns
        self.PATTERNS = {
            "code": {
                "keywords": [
                    r"\bcode\b", r"\bprogram\b", r"\bscript\b", r"\bfunction\b",
                    r"\bclass\b", r"\bapi\b", r"\bdebug\b", r"\bbug\b",
                    r"\bpython\b", r"\bjavascript\b", r"\btypescript\b",
                    r"\bjava\b", r"\bc\+\+\b", r"\bc#\b", r"\brust\b", r"\bgo\b",
                    r"\bsql\b", r"\bhtml\b", r"\bcss\b", r"\breact\b",
                    r"\bgit\b", r"\brefactor\b", r"\bcompile\b",
                    r"\bsyntax\b", r"\bvariable\b", r"\barray\b",
                    r"\bjson\b", r"\byaml\b", r"\bregex\b",
                    r"\bunit\s*test\b", r"\bdocker(?:file)?\b",
                    r"```", r"\bdef\b", r"\breturn\b", r"\bimport\b",
                ],
                "model": "code",
                "weight": 3,
            },
            "architecture": {
                "keywords": [
                    r"\barchitect\b", r"\barchitecture\b", r"\bmicroservices?\b",
                    r"\bscalable\b", r"\bscaling\b", r"\bload\s*balanc\b",
                    r"\bhigh\s*availability\b", r"\bfault\s*toleran\b",
                    r"\baws\b", r"\bazure\b", r"\bgcp\b", r"\bcloud\b",
                    r"\binfrastructure\b", r"\bsystem\s*design\b",
                    r"\bserverless\b", r"\bwell.architected\b",
                ],
                "model": "power",
                "weight": 3,
            },
            "storage": {
                "keywords": [
                    r"\bstorage\b", r"\bsan\b", r"\bnas\b", r"\braid\b",
                    r"\blun\b", r"\bvolume\b", r"\bsnapshot\b", r"\breplicat\b",
                    r"\bnetapp\b", r"\bpure\s*storage\b", r"\bdell\s*emc\b",
                    r"\biscsi\b", r"\bnfs\b", r"\bcifs\b", r"\bsmb\b",
                    r"\bfibre\s*channel\b", r"\bceph\b", r"\bs3\b",
                    r"\bbackup\b", r"\brestore\b", r"\btiering\b",
                ],
                "model": "power",
                "weight": 4,
            },
            "security": {
                "keywords": [
                    r"\bsecurity\b", r"\bvulnerab\b", r"\bexploit\b",
                    r"\bfirewall\b", r"\bcve\b", r"\bpentesting\b",
                    r"\bencrypt\b", r"\bcyber\b", r"\bthreat\b",
                    r"\bcompliance\b", r"\bgdpr\b", r"\bnist\b",
                    r"\biam\b", r"\bauthenticat\b", r"\bauthoriz\b",
                    r"\bxss\b", r"\bsql\s*inject\b",
                ],
                "model": "power",
                "weight": 4,
            },
            "devops": {
                "keywords": [
                    r"\bdevops\b", r"\bci/?cd\b", r"\bpipeline\b",
                    r"\bterraform\b", r"\bansible\b", r"\bjenkins\b",
                    r"\bgithub\s*actions\b", r"\bdeployment\b",
                    r"\bmonitoring\b", r"\bprometheus\b", r"\bgrafana\b",
                    r"\bsre\b", r"\bhelm\b", r"\bargocd\b",
                ],
                "model": "power",
                "weight": 3,
            },
            "data_analysis": {
                "keywords": [
                    r"\bdata\s*analy\b", r"\bstatistic\b", r"\bvisuali[sz]\b",
                    r"\bchart\b", r"\bmetric\b", r"\bkpi\b", r"\bdashboard\b",
                    r"\bpandas\b", r"\bmatplotlib\b", r"\btableau\b",
                    r"\bforecast\b", r"\btrend\b", r"\bcorrelat\b",
                    r"\bmachine\s*learning\b",
                ],
                "model": "power",
                "weight": 3,
            },
            "document": {
                "keywords": [
                    r"\bsummar[iy]\b", r"\bextract\b", r"\bparse\b",
                    r"\brestructure\b", r"\breformat\b", r"\bconvert\b",
                    r"\bmeeting\s*notes\b", r"\btranscri\b",
                    r"\breorganize\b", r"\bcondense\b", r"\bdocument\b",
                    r"\bexplain\s*(this|the)\b", r"\banalyze\s*(this|the)\b",
                    r"\bwhat\s*(does|is)\s*(this|the)\b",
                ],
                "model": "power",
                "weight": 2,
            },
            "business": {
                "keywords": [
                    r"\bstrateg\b", r"\broi\b", r"\bbusiness\s*case\b",
                    r"\bexecutive\b", r"\bswot\b", r"\bcompetit\b",
                    r"\brfp\b", r"\bsow\b", r"\bqbr\b", r"\brevenue\b",
                    r"\bforecast\b", r"\bprofit\b",
                ],
                "model": "power",
                "weight": 2,
            },
            "reasoning": {
                "keywords": [
                    r"\breason\b", r"\blogic\b", r"\bproof\b",
                    r"\bparadox\b", r"\bfallacy\b",
                    r"\bstep.by.step\b", r"\bchain.of.thought\b",
                    r"\bthink\s*(through|about|carefully)\b",
                    r"\bcomplex\s*(problem|question)\b",
                ],
                "model": "power",
                "weight": 2,
            },
        }

    def _classify(self, text: str) -> dict:
        """Classify user request by pattern matching."""
        text_lower = text.lower()
        scores = {}

        for category, config in self.PATTERNS.items():
            score = 0
            for pattern in config["keywords"]:
                matches = len(re.findall(pattern, text_lower))
                score += matches * config["weight"]
            if score > 0:
                scores[category] = score

        if not scores:
            return {"category": "general", "model_type": "auto"}

        best = max(scores, key=scores.get)
        return {"category": best, "model_type": self.PATTERNS[best]["model"]}

    def _select_model(self, model_type: str, text: str) -> str:
        """Select the actual model ID based on classification."""
        if model_type == "code":
            return self.valves.CODE_MODEL
        elif model_type == "power":
            return self.valves.POWER_MODEL
        else:
            # Auto: select based on complexity
            word_count = len(text.split())
            if word_count < self.valves.COMPLEXITY_THRESHOLD:
                return self.valves.FAST_MODEL
            return self.valves.POWER_MODEL

    def inlet(self, body: dict, __user__: Optional[dict] = None) -> dict:
        """
        Inlet filter: runs BEFORE the model processes the request.
        Analyzes the message and switches the model accordingly.
        File/RAG content is already injected by Open WebUI at this point.
        """
        messages = body.get("messages", [])
        if not messages:
            return body

        # Extract last user message
        last_user_msg = ""
        has_files = False
        for msg in reversed(messages):
            if msg.get("role") == "user":
                content = msg.get("content", "")
                if isinstance(content, str):
                    last_user_msg = content
                elif isinstance(content, list):
                    last_user_msg = " ".join(
                        item.get("text", "") for item in content
                        if isinstance(item, dict) and item.get("type") == "text"
                    )
                break

        # Check if files are attached
        if body.get("files") or body.get("metadata", {}).get("files"):
            has_files = True

        if not last_user_msg:
            return body

        # Classify and route
        classification = self._classify(last_user_msg)
        category = classification["category"]
        model_type = classification["model_type"]

        # If files are present and category is general, route to document processing
        if has_files and category == "general":
            category = "document"
            model_type = "power"

        # Select the actual model
        selected_model = self._select_model(model_type, last_user_msg)

        # Override the model in the request body
        body["model"] = selected_model

        # Store routing info for the outlet to use
        body["__auto_route_category"] = category
        body["__auto_route_model"] = selected_model

        return body

    def outlet(self, body: dict, __user__: Optional[dict] = None) -> dict:
        """
        Outlet filter: runs AFTER the model generates a response.
        Prepends the routing indicator to the response.
        """
        if not self.valves.SHOW_ROUTING:
            return body

        category = body.pop("__auto_route_category", None)
        model = body.pop("__auto_route_model", None)

        if category and model:
            messages = body.get("messages", [])
            if messages and messages[-1].get("role") == "assistant":
                model_short = model.split(":")[0] if ":" in model else model
                prefix = f"[🎯 Auto-routed → **{category.replace('_', ' ').title()}** ({model_short})]\n\n"
                content = messages[-1].get("content", "")
                messages[-1]["content"] = prefix + content

        return body
