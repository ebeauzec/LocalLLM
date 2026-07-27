# User Guide

This guide will help you get the most out of your LocalLLM installation.

## First-Time Setup

1. Open your browser and navigate to the address provided at the end of the installation (usually `http://localhost:3100`).
2. You will be prompted to create the first account. This account will automatically be granted **Administrator** privileges.
3. Fill in your name, email, and a secure password.

## Chat Interface Overview

The interface is powered by Open WebUI, offering a familiar, clean layout:
- **Sidebar**: Access your chat history, create new chats, and manage settings.
- **Message Area**: Where your conversation takes place.
- **Input Box**: Type your prompts here, attach files, or trigger web search.

## Persona Switching

LocalLLM includes 14 specialized AI personas, such as a Solutions Architect, Storage Engineer, and Security Analyst.
1. Click the model dropdown at the top of the chat window.
2. Select the persona that best fits your current task. 
3. You can seamlessly switch models/personas mid-conversation to leverage different expertise.

## Document Processing Workflow (RAG)

LocalLLM natively supports Retrieval-Augmented Generation (RAG) for analyzing your documents locally:
1. Click the **+** or **attachment icon** in the input box.
2. Upload your PDF, DOCX, XLSX, or text file.
3. Once processed, you can type `#` to explicitly reference the document in your prompt.
4. Ask questions like "Summarize this document" or "Extract the action items."
5. For messy documents, try using the **Document Processor** persona to structure the data.

## Analytical Framework Usage

To tackle complex problems, combine reasoning models with our analytical frameworks:
1. Select the **Reasoning Engine** persona.
2. Provide a structured prompt breaking down the problem.
3. Use the **Code Executor** tool if data analysis (Python/Pandas) is required.
4. Review the visible chain-of-thought blocks to understand how the model reached its conclusion.

## Web Search Integration

Need current information?
1. Click the **web search icon** (globe) in the input box.
2. Ask your question. The model will securely query SearXNG on the backend to fetch live results without tracking your identity.

## Tool Calling and Functions

Many models support tool calling (e.g., executing Python code or fetching APIs). If a model is capable, it will automatically decide when to use available tools (like the Calculator, Web Page Reader, or Image Analyzer) to answer complex queries.

## Customizing the Interface

- **Dark/Light Mode**: Toggle via the user profile menu in the bottom left.
- **System Prompts**: Set custom instructions for the AI in Settings > General.

## Managing Conversations

- Chats are automatically saved locally in a persistent Docker volume.
- You can rename, delete, or tag chats in the sidebar.
- Export your chat history from the settings menu.

## Keyboard Shortcuts

- `Enter`: Send message
- `Shift + Enter`: New line
- `Ctrl + /`: Focus input box

---
Copyright (c) 2025-2026 Eugene Beauzec. All Rights Reserved.
