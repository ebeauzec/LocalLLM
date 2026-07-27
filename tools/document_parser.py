"""
title: Document Parser
author: Eugene Beauzec
author_url: https://github.com/ebeauzec
version: 0.1.0
license: Proprietary
description: Universal document parser supporting PDF, Word, Excel, PowerPoint, HTML, Markdown, CSV, images (OCR), and 100+ formats via Apache Tika. All parsing is local — no data leaves your machine.
required_open_webui_version: 0.4.0
"""

import json
import urllib.request
import urllib.error
from pydantic import BaseModel, Field

class Tools:
    class Valves(BaseModel):
        tika_url: str = Field(default="http://tika:9998", description="Apache Tika server URL")
        max_file_size_mb: int = Field(default=50, description="Max file size in MB")
        ocr_enabled: bool = Field(default=True, description="Enable OCR")
        ocr_language: str = Field(default="eng", description="OCR language")
        extract_metadata: bool = Field(default=True, description="Extract file metadata")
        chunk_size: int = Field(default=1000, description="Chunk size for splitting large documents")

    def __init__(self):
        self.valves = self.Valves()

    async def parse_document(self, file_path: str, __user__: dict = {}) -> str:
        """
        Main function to parse a document. Send file to Tika via HTTP PUT to extract text.
        Use this when you need to extract text from ANY supported document format.
        """
        try:
            with open(file_path, 'rb') as f:
                data = f.read()
            
            req = urllib.request.Request(f"{self.valves.tika_url}/tika", data=data, method='PUT')
            req.add_header('Accept', 'text/plain')
            req.add_header('X-Tika-PDFextractInlineImages', 'true')
            
            with urllib.request.urlopen(req, timeout=30) as response:
                text = response.read().decode('utf-8')
                return text[:self.valves.chunk_size * 10] # Truncate logic
        except Exception as e:
            return f"Error parsing document: {str(e)}"

    async def extract_metadata(self, file_path: str, __user__: dict = {}) -> str:
        """
        Extract file metadata (author, creation date, page count, etc.).
        Use this when you need metadata instead of full content.
        """
        try:
            with open(file_path, 'rb') as f:
                data = f.read()
                
            req = urllib.request.Request(f"{self.valves.tika_url}/meta", data=data, method='PUT')
            req.add_header('Accept', 'application/json')
            
            with urllib.request.urlopen(req, timeout=10) as response:
                meta = json.loads(response.read().decode('utf-8'))
                
            res = "| Key | Value |\n|---|---|\n"
            for k, v in meta.items():
                res += f"| {k} | {v} |\n"
            return res
        except Exception as e:
            return f"Error extracting metadata: {str(e)}"

    async def parse_with_ocr(self, file_path: str, __user__: dict = {}) -> str:
        """
        Force OCR on a document/image.
        Use this for scanned PDFs and images where standard parsing fails to find text.
        """
        try:
            with open(file_path, 'rb') as f:
                data = f.read()
                
            req = urllib.request.Request(f"{self.valves.tika_url}/tika", data=data, method='PUT')
            req.add_header('Accept', 'text/plain')
            req.add_header('X-Tika-PDFocrStrategy', 'OCR_ONLY')
            
            with urllib.request.urlopen(req, timeout=60) as response:
                return response.read().decode('utf-8')
        except Exception as e:
            return f"Error parsing with OCR: {str(e)}"

    async def summarize_document(self, file_path: str, __user__: dict = {}) -> str:
        """
        Parse document and provide a summary of its contents.
        Use this to get a brief overview and statistics of a document.
        """
        try:
            text = await self.parse_document(file_path, __user__)
            if text.startswith("Error"):
                return text
                
            word_count = len(text.split())
            char_count = len(text)
            
            summary = f"**Document Summary**\n- Word Count: {word_count}\n- Character Count: {char_count}\n\n**Preview (First 2000 chars):**\n\n{text[:2000]}"
            return summary
        except Exception as e:
            return f"Error summarizing document: {str(e)}"

    async def list_supported_formats(self, __user__: dict = {}) -> str:
        """
        Return a formatted list of all supported formats, organized by category.
        Use this to check if a file type is supported.
        """
        return '''
**Supported Document Formats (Apache Tika)**
* **Text**: PDF, HTML, Markdown, CSV, TXT, XML
* **Microsoft Office**: Word (doc, docx), Excel (xls, xlsx), PowerPoint (ppt, pptx)
* **Images (via OCR)**: JPEG, PNG, TIFF, GIF
* **Audio/Video (Metadata only)**: MP3, MP4, WAV
* **Other**: RTF, EPUB, OpenDocument (odt, ods, odp)
'''
