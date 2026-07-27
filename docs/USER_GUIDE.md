# User Guide

This guide will help you get the most out of your LocalLLM installation.

## First-Time Setup

1. Open your browser and navigate to the address provided at the end of the installation (usually `http://localhost:3000`).
2. You will be prompted to create the first account. This account will automatically be granted **Administrator** privileges.
3. Fill in your name, email, and a secure password.

## Chat Interface Overview

The interface is powered by Open WebUI, offering a familiar, clean layout:
- **Sidebar**: Access your chat history, create new chats, and manage settings.
- **Message Area**: Where your conversation takes place.
- **Input Box**: Type your prompts here, attach files, or trigger web search.

## Selecting and Switching Models

Click the model dropdown at the top of the chat window. You will see:
- **Local Models**: E.g., `llama3.3`, `qwen2.5`. These run entirely on your machine.
- **Cloud Models**: E.g., `gpt-4o`, `claude-3-5-sonnet` (if configured in LiteLLM).

## RAG: Document Analysis

LocalLLM natively supports Retrieval-Augmented Generation (RAG):
1. Click the **+** or **attachment icon** in the input box.
2. Upload your PDF, DOCX, or text file.
3. Once processed, ask questions like "Summarize this document" or "What are the key takeaways?"

## Web Search Integration

Need current information?
1. Click the **web search icon** (globe) in the input box.
2. Ask your question. The model will securely query SearXNG, retrieve search results, and synthesize an up-to-date answer.

## Tool Calling and Functions

Many models support tool calling (e.g., executing Python code or fetching APIs). If a model is capable, it will automatically decide when to use available tools to answer complex queries.

## Using Cloud Models (Fallback)

If you have complex queries that local models struggle with, you can seamlessly switch to cloud models:
1. Go to **Settings > Admin > Connections** (or configure via LiteLLM dashboard).
2. Enter your API keys for OpenAI, Anthropic, or Google.
3. The models will now appear in your dropdown list.

## Customizing the Interface

- **Dark/Light Mode**: Toggle via the user profile menu in the bottom left.
- **System Prompts**: Set custom instructions for the AI in Settings > General.

## Managing Conversations

- Chats are automatically saved locally.
- You can rename, delete, or tag chats in the sidebar.
- Export your chat history from the settings menu.

## Keyboard Shortcuts

- `Enter`: Send message
- `Shift + Enter`: New line
- `Ctrl + /`: Focus input box

## Tips for Best Results

- **Reasoning vs General Models**: Use models like `DeepSeek-R1` for complex logic, math, or coding. Use general models like `Llama 3` or `Qwen` for creative writing, summarization, and general chat.
- **Clear Prompting**: Be specific about the format and constraints you want.
