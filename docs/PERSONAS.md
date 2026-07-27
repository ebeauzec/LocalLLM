# AI Personas

LocalLLM features 14 highly tuned AI personas designed for enterprise workflows.

## 1. General Assistant
- **ID:** `general-assistant`
- **Description:** All-purpose chat, Q&A, and summarization.
- **Best for:** Daily inquiries, brainstorming, drafting emails.
- **Parameters:** Temperature 0.7, Context Window 8192
- **Example Prompts:**
  - "Draft an email to the team about the new office layout."
  - "Summarize this article for me."
  - "Give me 5 ideas for our next hackathon."

## 2. Reasoning Engine
- **ID:** `reasoning-engine`
- **Description:** Deep thinking with visible chain-of-thought.
- **Best for:** Complex problem solving, logic puzzles, multi-step planning.
- **Parameters:** Temperature 0.1, Context Window 16384, CoT enabled
- **Example Prompts:**
  - "Solve this logic puzzle..."
  - "What is the optimal path for this workflow?"
  - "Break down this complex mathematical equation."

## 3. Code Developer
- **ID:** `code-developer`
- **Description:** Software engineering with code gen, review, debugging.
- **Best for:** Writing scripts, reviewing pull requests, architecture design.
- **Parameters:** Temperature 0.2, Context Window 16384
- **Example Prompts:**
  - "Write a Python script to parse this JSON."
  - "Review this React component for performance issues."
  - "Implement a retry mechanism for this API call."

## 4. Data Analyst
- **ID:** `data-analyst`
- **Description:** Statistics, data manipulation, visualization.
- **Best for:** Data cleaning, SQL generation, charting insights.
- **Parameters:** Temperature 0.5, Context Window 8192
- **Example Prompts:**
  - "Write a pandas script to clean this CSV."
  - "Generate a graph showing month-over-month growth."
  - "What statistical test should I use for this A/B test?"

## 5. Creative Writer
- **ID:** `creative-writer`
- **Description:** Content creation, copywriting, storytelling.
- **Best for:** Blog posts, marketing copy, creative writing.
- **Parameters:** Temperature 0.9, Context Window 8192
- **Example Prompts:**
  - "Write a catchy headline for our new product."
  - "Draft a blog post about the future of AI."
  - "Create a short story about a time traveler."

## 6. Security Analyst
- **ID:** `security-analyst`
- **Description:** Cybersecurity auditing, threat modeling.
- **Best for:** Code security review, architecture threat modeling.
- **Parameters:** Temperature 0.1, Context Window 16384
- **Example Prompts:**
  - "Identify vulnerabilities in this Node.js code."
  - "Generate a threat model for our new web application."
  - "What are the security implications of this configuration?"

## 7. Solutions Architect
- **ID:** `solutions-architect`
- **Description:** System design and architecture planning.
- **Best for:** Evaluating proposals, designing microservices, scaling systems.
- **Parameters:** Temperature 0.3, Context Window 16384
- **Example Prompts:**
  - "Review this vendor proposal for our new cloud infrastructure."
  - "Design a highly available architecture for a global web app."
  - "What are the trade-offs of using GraphQL vs REST here?"

## 8. Storage Engineer
- **ID:** `storage-engineer`
- **Description:** SAN/NAS management and storage operations.
- **Best for:** Planning storage migrations, optimizing IOPS, troubleshooting latency.
- **Parameters:** Temperature 0.2, Context Window 8192
- **Example Prompts:**
  - "Plan a storage migration from Dell EMC to Pure Storage."
  - "Troubleshoot this high latency issue on our iSCSI LUN."
  - "Write a script to report on volume usage."

## 9. Technical Account Manager (TAM)
- **ID:** `tam`
- **Description:** Client relationship and account management.
- **Best for:** Preparing Quarterly Business Reviews (QBRs), incident reporting.
- **Parameters:** Temperature 0.6, Context Window 8192
- **Example Prompts:**
  - "Prepare an executive summary for our QBR with Client X."
  - "Draft a post-incident report for the outage yesterday."
  - "Suggest talking points for renewing this enterprise contract."

## 10. Document Processor
- **ID:** `document-processor`
- **Description:** Structuring and organizing messy text.
- **Best for:** OCR cleanup, formatting meeting notes, data extraction.
- **Parameters:** Temperature 0.1, Context Window 32768
- **Example Prompts:**
  - "Restructure this messy OCR text into a clean Markdown table."
  - "Extract all action items from this meeting transcript."
  - "Format this raw data into a structured JSON object."

## 11. Project Manager
- **ID:** `project-manager`
- **Description:** Agile planning, sprint management, risk assessment.
- **Best for:** Creating project plans, writing user stories, managing timelines.
- **Parameters:** Temperature 0.4, Context Window 8192
- **Example Prompts:**
  - "Create a project plan for migrating our database."
  - "Write user stories for the new authentication feature."
  - "Identify potential risks for this software release."

## 12. Technical Writer
- **ID:** `technical-writer`
- **Description:** Creating clear, concise technical documentation.
- **Best for:** API docs, user guides, release notes.
- **Parameters:** Temperature 0.4, Context Window 16384
- **Example Prompts:**
  - "Write API documentation for this Python endpoint."
  - "Draft release notes for version 2.0."
  - "Create a user guide for the new dashboard feature."

## 13. UX Researcher
- **ID:** `ux-researcher`
- **Description:** Usability analysis and interface feedback.
- **Best for:** Critiquing UI designs, suggesting accessibility improvements.
- **Parameters:** Temperature 0.6, Context Window 8192
- **Example Prompts:**
  - "Critique this login screen design for usability."
  - "How can we improve the accessibility of this form?"
  - "Suggest a user testing plan for our new mobile app."

## 14. SQL Expert
- **ID:** `sql-expert`
- **Description:** Database querying and optimization.
- **Best for:** Writing complex joins, optimizing query performance, schema design.
- **Parameters:** Temperature 0.1, Context Window 8192
- **Example Prompts:**
  - "Write a SQL query to find the top 10 customers by revenue."
  - "Optimize this slow-running query."
  - "Design a database schema for an e-commerce platform."

## Customization Guide
To create your own personas, navigate to the WebUI Settings -> Personas. You can define custom system prompts, adjust temperature and context limits, and assign specific models.

---
Copyright (c) 2025-2026 Eugene Beauzec. All Rights Reserved.
