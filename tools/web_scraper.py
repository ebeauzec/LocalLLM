"""
title: Web Page Reader
author: Eugene Beauzec
version: 0.1.0
license: Proprietary
description: Fetches and extracts text content from web pages for analysis.

Copyright: (c) 2025-2026 Eugene Beauzec. All Rights Reserved.
"""

import urllib.request
import urllib.error
import urllib.parse
from html.parser import HTMLParser
from pydantic import BaseModel, Field

class SimpleHTMLTextExtractor(HTMLParser):
    def __init__(self):
        super().__init__()
        self.text = []
        self.hide_content = False
        self.ignore_tags = {'script', 'style', 'head', 'meta', 'title'}

    def handle_starttag(self, tag, attrs):
        if tag in self.ignore_tags:
            self.hide_content = True

    def handle_endtag(self, tag):
        if tag in self.ignore_tags:
            self.hide_content = False

    def handle_data(self, data):
        if not self.hide_content:
            text = data.strip()
            if text:
                self.text.append(text)

    def get_text(self):
        return ' '.join(self.text)

class Tools:
    class Valves(BaseModel):
        max_content_size: int = Field(default=50000, description="Max characters to return")
        timeout_seconds: int = Field(default=15, description="Network timeout in seconds")
    
    def __init__(self):
        self.valves = self.Valves()
    
    async def fetch_webpage(self, url: str, __user__: dict = {}) -> str:
        """Fetch URL content, extract clean text, and return it.
        Use this to read articles, documentation, or any text from a web page.
        
        :param url: The URL of the web page to fetch.
        :return: Extracted text from the web page.
        """
        try:
            req = urllib.request.Request(
                url, 
                headers={'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) LocalLLM/0.1.0'}
            )
            
            with urllib.request.urlopen(req, timeout=self.valves.timeout_seconds) as response:
                content_type = response.headers.get('Content-Type', '')
                if 'text/html' not in content_type and 'text/plain' not in content_type:
                    return f"Error: Unsupported content type {content_type}. Only HTML/text is supported."
                
                html_content = response.read().decode('utf-8', errors='ignore')
                
                extractor = SimpleHTMLTextExtractor()
                extractor.feed(html_content)
                text = extractor.get_text()
                
                if len(text) > self.valves.max_content_size:
                    text = text[:self.valves.max_content_size] + "\n... [Content Truncated]"
                    
                return text
        except urllib.error.URLError as e:
            return f"Network Error: {str(e)}"
        except Exception as e:
            return f"Error fetching webpage: {str(e)}"
