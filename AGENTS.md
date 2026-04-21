FinSight AI: SME Financial Health Advisor
AI Agent & Team Technical Manifesto
# Most important rule (if you are a codex agent):
 - Do not run `dart ...` or `flutter ...`. Do not ever, ever run any dart or flutter commands

1. Project Overview

FinSight AI is a decision intelligence system designed to empower Malaysian SMEs (Cafes & Pet Stores) by transforming messy financial data into actionable, RM-quantifiable decisions using Z.AI GLM 5.1.

2. Technical Stack

Frontend: Flutter (Desktop Optimized)

Backend: Node.js (Express/FastAPI)

Database: MongoDB Atlas (AWS Singapore Region)

AI Engine: Z.AI GLM 5.1

Architecture: N-Tier Component-Based Architecture (Strict Separation)

3. Repository Structure & Folder Logic

To maintain Independence and Replaceability, the project must follow this exact structure:

Presentation Layer (Flutter)

This layer is structured into independent, modular components. Following the established system architecture and mock UI, this layer contains the following folders and no additional sub-directories:

/login: Manages user authentication, session initialization, and secure entry into the FinSight AI system.

/shared: Houses universal UI elements, standardized themes, and layout templates used consistently across the application to ensure a unified desktop experience.

/dashboard: The central hub displaying the current MYR balance, high-level financial health metrics, and the primary "Cash Balance Trend" chart.

/upload: The document ingestion component allowing users to tap, drag, or drop financial documents (PDF, JPG, PNG) for parsing.

/risks: Dedicated view for AI-detected financial risk alerts, categorizing threats by severity (Critical, High, Medium, Low) and providing risk scores.

/forecast: Displays the 8-week cash flow projection, integrating moving average models with historical and predictive inflow/outflow data.

/actions: The decision intelligence interface showing ranked AI recommendations sorted by quantifiable RM impact.

Application Layer (Node.js)

/routes: The Mediator. The only folder that communicates with the Presentation Layer. It coordinates calls between logic and ai-engine.

/logic: Deterministic business logic. Handles RM calculations, cash flow math, and tax rules. No AI code here.

/ai-engine: Z.AI integration. Handles prompt orchestration, reasoning, and recommendation generation.

Data Layer (Node.js)

/models: MongoDB schemas (The Blueprints).

/repositories: The "Librarians." The only place allowed to perform DB queries.

/database: Connection initialization for MongoDB Atlas.

/storage: Management of binary files (Receipts/PDFs).

4. Professional Coding Standards

Naming Conventions

Variables/Functions: camelCase (e.g., calculateNetCashFlow).

Classes/Models: PascalCase (e.g., TransactionRepository).

Files: kebab-case or snake_case (consistent per layer).

Database Fields: snake_case (e.g., is_recurring, affected_amount).

Error Handling

No Silent Failures: Every component must use try-catch blocks.

Standardized Responses: Routes must return a consistent JSON structure:

JSON
{ "success": true, "data": {}, "error": null }
AI/Prompt Engineering

Context Isolation: Prompts must be stored in a separate /prompts directory within ai-engine to allow for versioning without breaking logic.

Structured Output: Always request json_mode from Z.AI to ensure the Frontend can parse recommendations.

5. Communication Protocols (The "Rules of Engagement")

Downhill Only: High-level components (Routes) can call low-level components (Logic/Data), but never the reverse.

No Direct DB Access: The ai-engine and logic folders must ask the repositories for data. They are forbidden from importing mongoose or mongodb drivers directly.

Encapsulation: If the storage provider changes (e.g., from local to S3), zero changes should be required in the logic or presentation layers.

6. Implementation Guardrails

UI Integrity: The 7 core screens (login through actions) are finalized. Logic must be mapped to the existing UI elements shown in the mockups.

Quantifiable Impact: Every AI recommendation must include an affected_amount in MYR to satisfy the "Economic Empowerment" domain requirements.