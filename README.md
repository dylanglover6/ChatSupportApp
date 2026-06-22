# SupportBot

SupportBot is a Phoenix/Elixir portfolio MVP for an AI-powered FlowDesk support operations platform.

The app demonstrates a complete support triage workflow:

- Customer chats with an AI troubleshooting assistant.
- The assistant searches local Markdown knowledge base articles.
- The customer can create a structured support ticket from the chat.
- The app classifies category and priority.
- The ticket is assigned to a mock support agent based on shift availability, specialty, workload, and team color.
- A manager dashboard shows agent availability, open tickets, and recent activity.
- Ticket detail pages show the chatbot history, AI summaries, KB sources, timeline, customer replies, and internal notes.

## Tech Stack

- Elixir
- Phoenix
- Phoenix LiveView
- PostgreSQL
- Ecto
- Local Markdown knowledge base files
- Ollama local AI API, with a deterministic fallback response when Ollama is not running

## Setup

Install Elixir/Erlang, PostgreSQL, and Node.js. On Windows, the official Elixir installer is the most reliable path:

```powershell
elixir --version
mix --version
mix local.hex
mix archive.install hex phx_new
```

Install and set up the app:

```powershell
mix setup
mix phx.server
```

Visit:

```text
http://localhost:4000
```

The default database settings are in `config/dev.exs`:

```text
username: postgres
password: postgres
database: support_bot_dev
```

Adjust those values if your local PostgreSQL user is different.

## Ollama

SupportBot calls Ollama at:

```text
http://localhost:11434/api/chat
```

The model defaults to:

```text
llama3.2
```

Override it with:

```powershell
$env:OLLAMA_MODEL="llama3.2"
```

If Ollama is not running, the app still works with a local fallback response so the portfolio flow can be demonstrated.

## Knowledge Base Search

The local KB lives in `priv/kb/`. `SupportBot.KB.Loader` reads Markdown files and extracts article metadata. `SupportBot.KB.Search` tokenizes the customer message, scores article titles and bodies with keyword matches, and returns the top snippets as chat context.

This is intentionally simple for the MVP. It tells a RAG-style story without adding embeddings, a vector database, or external search infrastructure.

## Agent Assignment

Mock agents are seeded in `priv/repo/seeds.exs`. Assignment considers:

- Current shift availability
- Category specialty match
- Current open ticket count
- Team color designation

If no agent is in office, the app assigns the ticket to the agent whose shift starts soonest and marks the ticket as `Waiting for Agent`.

## Example Questions

Try these in the chat:

```text
Customer gets SAML audience mismatch from Okta. What should I check?
API returns 401 even though the token worked yesterday.
Webhook events are delayed and retries are not arriving.
A user was invited to a workspace but cannot access it.
A customer cannot upload a file larger than 100MB.
```

## Routes

```text
/chat
/tickets
/tickets/:id
/kb
/kb/:slug
```

## Future Improvements

- Vector search with embeddings
- Admin UI for editing KB articles
- Streaming model responses
- User authentication
- Real email notifications
- Customer ticket status page
- Manual ticket reassignment
- SLA timers
- Agent workload charts
- OpenAI or Anthropic provider option
- Deployment instructions
