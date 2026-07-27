# Copyright (c) 2025-2026 Eugene Beauzec. All Rights Reserved.
#
# LocalLLM Auto-Router — Intelligent Model Selection Pipe
# Analyzes user requests and routes to the optimal specialist persona.
# Appears as "LocalLLM Auto" in the model dropdown.

"""
title: LocalLLM Auto-Router
description: Automatically selects the best specialist model based on your request
author: Eugene Beauzec
version: 1.0.0
licence: Proprietary
"""

import re
import requests
from typing import Optional, Generator
from pydantic import BaseModel, Field


class Pipe:
    """
    Open WebUI Pipe that intelligently routes requests to the best
    specialist model based on content analysis.
    """

    class Valves(BaseModel):
        OLLAMA_BASE_URL: str = Field(
            default="http://ollama:11434",
            description="Ollama API base URL"
        )
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

    def __init__(self):
        self.valves = self.Valves()
        self.type = "manifold"

        # Task classification patterns (keyword → category)
        self.PATTERNS = {
            "code": {
                "keywords": [
                    r"\bcode\b", r"\bprogram\b", r"\bscript\b", r"\bfunction\b",
                    r"\bclass\b", r"\bapi\b", r"\bdebug\b", r"\bbug\b",
                    r"\bpython\b", r"\bjavascript\b", r"\btypescript\b",
                    r"\bjava\b", r"\bc\+\+\b", r"\bc#\b", r"\brust\b", r"\bgo\b",
                    r"\bsql\b", r"\bhtml\b", r"\bcss\b", r"\breact\b", r"\bvue\b",
                    r"\bgit\b", r"\bcommit\b", r"\bmerge\b", r"\bbranch\b",
                    r"\brefactor\b", r"\bimplements?\b", r"\bcompile\b",
                    r"\bsyntax\b", r"\bvariable\b", r"\bloop\b", r"\barray\b",
                    r"\bjson\b", r"\byaml\b", r"\bxml\b", r"\bregex\b",
                    r"\bunit\s*test\b", r"\btdd\b", r"\bcicd\b",
                    r"\bdocker(?:file)?\b", r"\bkubernetes\b", r"\bhelm\b",
                    r"\bnpm\b", r"\bpip\b", r"\bcargo\b",
                    r"```", r"\bdef\b", r"\breturn\b", r"\bimport\b",
                ],
                "model": "code",
                "system_prompt": None,  # Uses CODE_MODEL directly
                "weight": 3,
            },
            "architecture": {
                "keywords": [
                    r"\barchitect\b", r"\barchitecture\b", r"\bmicroservices?\b",
                    r"\bscalable\b", r"\bscaling\b", r"\bload\s*balanc\b",
                    r"\bhigh\s*availability\b", r"\bfault\s*toleran\b",
                    r"\bdisaster\s*recovery\b", r"\brpo\b", r"\brto\b",
                    r"\baws\b", r"\bazure\b", r"\bgcp\b", r"\bcloud\b",
                    r"\binfrastructure\b", r"\bsystem\s*design\b",
                    r"\bcap\s*theorem\b", r"\bmessage\s*queue\b",
                    r"\bkafka\b", r"\brabbitmq\b", r"\bevent.driven\b",
                    r"\bserverless\b", r"\blambda\b", r"\btogaf\b",
                    r"\bc4\s*model\b", r"\bwell.architected\b",
                    r"\bcontainer\s*orchestrat\b",
                ],
                "model": "power",
                "system_prompt": "solutions-architect",
                "weight": 3,
            },
            "storage": {
                "keywords": [
                    r"\bstorage\b", r"\bsan\b", r"\bnas\b", r"\braid\b",
                    r"\blun\b", r"\bvolume\b", r"\bsnapshot\b", r"\breplicat\b",
                    r"\bnetapp\b", r"\bpure\s*storage\b", r"\bdell\s*emc\b",
                    r"\bvmax\b", r"\bpowerstore\b", r"\bflasharray\b",
                    r"\biscsi\b", r"\bnfs\b", r"\bcifs\b", r"\bsmb\b",
                    r"\bfibre\s*channel\b", r"\bfc\b", r"\bzfs\b",
                    r"\bceph\b", r"\bs3\b", r"\bobject\s*storage\b",
                    r"\bblock\s*storage\b", r"\bfile\s*system\b",
                    r"\btiering\b", r"\bdedup\b", r"\bcompression\b",
                    r"\bbackup\b", r"\brestore\b",
                ],
                "model": "power",
                "system_prompt": "storage-engineer",
                "weight": 4,
            },
            "security": {
                "keywords": [
                    r"\bsecurity\b", r"\bvulnerab\b", r"\bexploit\b",
                    r"\bmalware\b", r"\bfirewall\b", r"\bcve\b",
                    r"\bpentesting\b", r"\bpentest\b", r"\bsoc\b",
                    r"\bsiem\b", r"\bencrypt\b", r"\bcyber\b",
                    r"\bthreat\b", r"\bincident\s*response\b",
                    r"\bcompliance\b", r"\bgdpr\b", r"\bhipaa\b",
                    r"\bpci.dss\b", r"\biso\s*27001\b", r"\bnist\b",
                    r"\biam\b", r"\baccess\s*control\b", r"\brbac\b",
                    r"\bauthenticat\b", r"\bauthoriz\b",
                    r"\bxss\b", r"\bsql\s*inject\b", r"\bcsrf\b",
                    r"\bzero.day\b", r"\bransomware\b",
                ],
                "model": "power",
                "system_prompt": "security-analyst",
                "weight": 4,
            },
            "devops": {
                "keywords": [
                    r"\bdevops\b", r"\bci/?cd\b", r"\bpipeline\b",
                    r"\bterraform\b", r"\bansible\b", r"\bpulumi\b",
                    r"\bjenkins\b", r"\bgithub\s*actions\b", r"\bgitlab\b",
                    r"\bdeployment\b", r"\brolling\s*update\b",
                    r"\bblue.green\b", r"\bcanary\b", r"\bmonitoring\b",
                    r"\bprometheus\b", r"\bgrafana\b", r"\binfra\s*as\s*code\b",
                    r"\bsre\b", r"\breliab\b", r"\buptime\b", r"\bsla\b",
                    r"\bhelm\b", r"\bargocd\b", r"\bflux\b",
                ],
                "model": "power",
                "system_prompt": "devops-engineer",
                "weight": 3,
            },
            "data_analysis": {
                "keywords": [
                    r"\bdata\s*analy\b", r"\bstatistic\b", r"\bregression\b",
                    r"\bvisuali[sz]\b", r"\bchart\b", r"\bgraph\b",
                    r"\bmetric\b", r"\bkpi\b", r"\bdashboard\b",
                    r"\bpandas\b", r"\bnumpy\b", r"\bmatplotlib\b",
                    r"\btableau\b", r"\bpower\s*bi\b", r"\bexcel\b",
                    r"\bpivot\b", r"\baggregate\b", r"\bforecast\b",
                    r"\btrend\b", r"\bcorrelat\b", r"\boutlier\b",
                    r"\bcluster\b", r"\bclassif\b", r"\bml\b",
                    r"\bmachine\s*learning\b", r"\bneural\b",
                    r"\banalyze\s*(this|the|my)\s*data\b",
                ],
                "model": "power",
                "system_prompt": "data-analyst",
                "weight": 3,
            },
            "writing": {
                "keywords": [
                    r"\bwrite\b.*\b(document|article|blog|essay|report)\b",
                    r"\bdocumentat\b", r"\btechnical\s*writ\b",
                    r"\brunbook\b", r"\bplaybook\b", r"\bsop\b",
                    r"\breadme\b", r"\bchangelog\b", r"\brelease\s*notes\b",
                    r"\buser\s*guide\b", r"\bman\s*page\b",
                    r"\bapi\s*doc\b", r"\bswagger\b", r"\bopenapi\b",
                ],
                "model": "power",
                "system_prompt": "technical-writer",
                "weight": 2,
            },
            "creative": {
                "keywords": [
                    r"\bcreative\b", r"\bstory\b", r"\bpoem\b", r"\bfiction\b",
                    r"\bnarrative\b", r"\bblog\s*post\b", r"\bcopy\s*writ\b",
                    r"\bslogan\b", r"\btagline\b", r"\bmarketing\b",
                    r"\bbrand\b", r"\btone\b", r"\bvoice\b",
                    r"\bengage\b", r"\bcaptivat\b", r"\bcompell\b",
                    r"\brewrite\b", r"\brephrase\b", r"\bparaphrase\b",
                ],
                "model": "power",
                "system_prompt": "creative-writer",
                "weight": 2,
            },
            "business": {
                "keywords": [
                    r"\bstrateg\b", r"\broi\b", r"\bbudget\b",
                    r"\bbusiness\s*case\b", r"\bstakehold\b",
                    r"\bexecutive\b", r"\bc-level\b", r"\bceo\b", r"\bcfo\b",
                    r"\bswot\b", r"\bpestle\b", r"\bporter\b",
                    r"\bgrowth\b", r"\bmarket\b", r"\bcompetit\b",
                    r"\bproposal\b", r"\brfp\b", r"\bsow\b",
                    r"\bqbr\b", r"\bquarterly\b", r"\brevenue\b",
                    r"\bforecast\b", r"\bp&l\b", r"\bprofit\b",
                ],
                "model": "power",
                "system_prompt": "executive-advisor",
                "weight": 2,
            },
            "project_mgmt": {
                "keywords": [
                    r"\bproject\s*(plan|manag)\b", r"\bgantt\b", r"\bwbs\b",
                    r"\bmileston\b", r"\bsprint\b", r"\bagile\b",
                    r"\bscrum\b", r"\bkanban\b", r"\bjira\b",
                    r"\bbacklog\b", r"\bepic\b", r"\buser\s*stor\b",
                    r"\bstakehold\b", r"\brisk\s*regist\b",
                    r"\bproject\s*timeline\b", r"\bresource\s*allocat\b",
                    r"\bdependenc\b", r"\bcritical\s*path\b",
                ],
                "model": "power",
                "system_prompt": "project-manager",
                "weight": 3,
            },
            "tam": {
                "keywords": [
                    r"\bcustomer\b", r"\bclient\b", r"\baccount\b",
                    r"\bescalat\b", r"\bsla\b", r"\bsupport\b",
                    r"\bticket\b", r"\bincident\b", r"\bpostmortem\b",
                    r"\bonboard\b", r"\benablement\b", r"\bsuccess\b",
                    r"\brenewal\b", r"\bchurn\b", r"\bretent\b",
                    r"\brelationship\b", r"\btechnical\s*account\b",
                ],
                "model": "power",
                "system_prompt": "technical-account-manager",
                "weight": 2,
            },
            "document": {
                "keywords": [
                    r"\brestructure\b", r"\breformat\b", r"\bsummar[iy]\b",
                    r"\bextract\b", r"\bconvert\b", r"\bparse\b",
                    r"\bmeeting\s*notes\b", r"\bminutes\b",
                    r"\baction\s*items\b", r"\btranscri\b",
                    r"\breorganize\b", r"\bcondense\b",
                    r"\bbullet\s*point\b", r"\bformat\b",
                ],
                "model": "power",
                "system_prompt": "document-processor",
                "weight": 2,
            },
            "reasoning": {
                "keywords": [
                    r"\breason\b", r"\blogic\b", r"\bproof\b",
                    r"\btheorem\b", r"\bparadox\b", r"\bfallacy\b",
                    r"\bdeduct\b", r"\binduct\b", r"\bhypothes\b",
                    r"\bcritical\s*think\b", r"\bphilosoph\b",
                    r"\bethic\b", r"\bmoral\b", r"\bdilemma\b",
                    r"\bstep.by.step\b", r"\bchain.of.thought\b",
                    r"\bthink\s*(through|about|carefully)\b",
                    r"\bcomplex\s*(problem|question)\b",
                ],
                "model": "power",
                "system_prompt": "reasoning-engine",
                "weight": 2,
            },
        }

        # System prompts for each persona (loaded from modelfiles)
        self.PERSONA_PROMPTS = {
            "solutions-architect": "You are LocalLLM Solutions Architect, a highly specialized expert in enterprise system design, cloud architecture, and scalable software systems.",
            "storage-engineer": "You are LocalLLM Storage Engineer, an expert in enterprise storage systems, data management, and storage infrastructure.",
            "security-analyst": "You are LocalLLM Security Analyst, a cybersecurity expert specializing in threat analysis, vulnerability assessment, and security architecture.",
            "devops-engineer": "You are LocalLLM DevOps Engineer, an expert in CI/CD pipelines, infrastructure automation, and site reliability engineering.",
            "data-analyst": "You are LocalLLM Data Analyst, an expert in data analysis, statistical methods, and data visualization.",
            "technical-writer": "You are LocalLLM Technical Writer, an expert in creating clear, comprehensive technical documentation.",
            "creative-writer": "You are LocalLLM Creative Writer, an expert in creative, engaging, and compelling writing across all formats.",
            "executive-advisor": "You are LocalLLM Executive Advisor, a strategic business advisor with expertise in corporate strategy and leadership.",
            "project-manager": "You are LocalLLM Project Manager, an expert in project planning, execution, and agile methodologies.",
            "technical-account-manager": "You are LocalLLM Technical Account Manager, an expert in client relations, technical guidance, and account management.",
            "document-processor": "You are LocalLLM Document Processor, an expert in document structuring, analysis, and transformation.",
            "reasoning-engine": "You are LocalLLM Reasoning Engine, an expert in advanced logical reasoning, critical analysis, and step-by-step problem solving.",
        }

    def pipes(self):
        """Register this pipe as a single 'Auto' model."""
        return [
            {
                "id": "auto-router",
                "name": "🎯 Auto (Smart Router)",
                "description": "Automatically selects the best specialist based on your request",
            }
        ]

    def _classify(self, text: str) -> dict:
        """
        Classify the user's request by matching patterns.
        Returns the best matching category with confidence score.
        """
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
            return {
                "category": "general",
                "model": self._select_by_complexity(text),
                "system_prompt": None,
                "confidence": 0,
            }

        best_category = max(scores, key=scores.get)
        best_config = self.PATTERNS[best_category]
        total_score = scores[best_category]

        # Determine model based on category
        if best_config["model"] == "code":
            model = self.valves.CODE_MODEL
        elif best_config["model"] == "power":
            model = self.valves.POWER_MODEL
        else:
            model = self._select_by_complexity(text)

        return {
            "category": best_category,
            "model": model,
            "system_prompt": best_config.get("system_prompt"),
            "confidence": min(total_score / 10.0, 1.0),
        }

    def _select_by_complexity(self, text: str) -> str:
        """Select model based on message complexity (word count)."""
        word_count = len(text.split())
        if word_count < self.valves.COMPLEXITY_THRESHOLD:
            return self.valves.FAST_MODEL
        return self.valves.POWER_MODEL

    def pipe(self, body: dict) -> Generator[str, None, None] | str:
        """
        Main pipe method. Analyzes the request, selects the best model,
        and streams the response.
        """
        messages = body.get("messages", [])
        if not messages:
            return "No message provided."

        # Get the last user message for classification
        last_user_msg = ""
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

        if not last_user_msg:
            return "Could not extract user message."

        # Classify the request
        classification = self._classify(last_user_msg)
        selected_model = classification["model"]
        category = classification["category"]
        confidence = classification["confidence"]

        # Build the system prompt
        persona_key = classification.get("system_prompt")
        system_prompt = self.PERSONA_PROMPTS.get(persona_key, "")

        # Prepare the Ollama request
        chat_messages = list(messages)  # Copy

        # Handle file attachments — Open WebUI passes file content in body
        file_contents = []
        if "files" in body:
            for file_info in body.get("files", []):
                if isinstance(file_info, dict):
                    # Try to get file content from various formats
                    content = file_info.get("content", "")
                    name = file_info.get("name", file_info.get("filename", "document"))
                    if content:
                        file_contents.append(f"--- Document: {name} ---\n{content}\n--- End of {name} ---")

        # If we have file contents, inject them into the user message
        if file_contents:
            file_context = "\n\n".join(file_contents)
            # Find the last user message and augment it
            for i in range(len(chat_messages) - 1, -1, -1):
                if chat_messages[i].get("role") == "user":
                    original = chat_messages[i].get("content", "")
                    if isinstance(original, str):
                        chat_messages[i]["content"] = f"{original}\n\n<attached_documents>\n{file_context}\n</attached_documents>"
                    break
            # If document-related, route to document processor
            if category == "general":
                category = "document"
                selected_model = self.valves.POWER_MODEL
                system_prompt = self.PERSONA_PROMPTS.get("document-processor", "")

        # Inject system prompt if we have a persona match
        if system_prompt:
            # Prepend or replace system message
            if chat_messages and chat_messages[0].get("role") == "system":
                chat_messages[0]["content"] = system_prompt
            else:
                chat_messages.insert(0, {"role": "system", "content": system_prompt})

        # Add routing metadata as a subtle prefix
        routing_note = f"[🎯 Auto-routed → **{category.replace('_', ' ').title()}** ({selected_model.split(':')[0]})]"

        ollama_payload = {
            "model": selected_model,
            "messages": chat_messages,
            "stream": body.get("stream", True),
        }

        # Copy parameters if present
        for param in ["temperature", "top_p", "top_k", "num_ctx", "num_predict"]:
            if param in body:
                ollama_payload["options"] = ollama_payload.get("options", {})
                ollama_payload["options"][param] = body[param]

        try:
            # Yield the routing indicator first
            yield routing_note + "\n\n"

            # Stream from Ollama
            url = f"{self.valves.OLLAMA_BASE_URL}/api/chat"
            response = requests.post(
                url,
                json=ollama_payload,
                stream=True,
                timeout=300,
            )
            response.raise_for_status()

            for line in response.iter_lines():
                if line:
                    try:
                        import json
                        data = json.loads(line)
                        content = data.get("message", {}).get("content", "")
                        if content:
                            yield content
                        if data.get("done", False):
                            break
                    except (json.JSONDecodeError, KeyError):
                        continue

        except requests.exceptions.ConnectionError:
            yield f"\n\n❌ Could not connect to Ollama at {self.valves.OLLAMA_BASE_URL}. Is the service running?"
        except requests.exceptions.Timeout:
            yield "\n\n❌ Request timed out. The model may be loading — try again in a moment."
        except Exception as e:
            yield f"\n\n❌ Error: {str(e)}"
