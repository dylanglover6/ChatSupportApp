# SupportBot Codex Implementation Brief

I want to create a Phoenix/Elixir AI support chatbot project called **SupportBot**.

The goal is to build a small portfolio-ready technical support app that demonstrates:

- AI chatbot troubleshooting
- Local knowledge base lookup
- Ticket creation when the chatbot cannot resolve the issue
- Automatic assignment to available mock support agents
- A manager dashboard showing agents and open tickets
- Ticket detail pages with chatbot history and agent responses

The app should feel like a small AI-powered support operations platform, not just a generic chatbot.

---

## Tech stack

Please use:

- Elixir
- Phoenix
- Phoenix LiveView
- PostgreSQL
- Ecto
- Local Markdown knowledge base files
- Ollama local AI model API for the MVP
- Optional future support for OpenAI or Anthropic

The fictional product being supported can be called **FlowDesk**.

FlowDesk is a mock SaaS product with:

- SSO/SAML login
- API tokens
- Webhooks
- Workspace permissions
- File uploads
- Billing/account access

---

## Main app views

Create a simple top navigation/view switcher.

Suggested navigation:

```text
Chat | Manager Dashboard | Knowledge Base
```

Suggested routes:

```text
/chat
/tickets
/tickets/:id
/kb
/kb/:slug
```

The app does not need real authentication for the MVP. The views can simulate different roles:

```text
Chat = customer-style view
Manager Dashboard = support/manager-style view
Knowledge Base = source documentation view
```

---

## MVP workflow

The app should demonstrate this full workflow:

```text
1. Customer asks chatbot for help.
2. Chatbot searches the local KB and suggests troubleshooting steps.
3. Customer still needs help and creates a ticket.
4. Customer enters name, email, issue title, and optional details.
5. App summarizes the conversation into a support ticket.
6. App detects category and priority.
7. App assigns ticket to an available mock agent based on shift, specialty, workload, and color designation.
8. App shows a ticket-created notification.
9. Manager Dashboard shows agent availability and open ticket queue.
10. Ticket detail page shows chatbot history, summary, assignment reason, and KB sources.
11. Agent can add a customer reply or internal note.
12. Ticket timeline records replies, notes, and status changes.
```

---

## Stage 1: Create the Phoenix project

Create a Phoenix project with LiveView and PostgreSQL.

Suggested app name:

```text
support_bot
```

The app should include:

```text
Phoenix LiveView
PostgreSQL
Ecto
A basic layout
Top navigation
Chat page
Manager dashboard page
Knowledge base page
```

---

## Stage 2: Create the local knowledge base

Create a folder:

```text
priv/kb/
```

Add 5 Markdown KB articles:

```text
priv/kb/01_sso_saml_troubleshooting.md
priv/kb/02_api_authentication.md
priv/kb/03_webhook_delivery.md
priv/kb/04_workspace_permissions.md
priv/kb/05_file_upload_limits.md
```

Each article should include:

```text
Title
Overview
Common symptoms
Likely causes
Troubleshooting steps
Information to collect from the customer
Escalation criteria
Customer-facing response template
```

Each doc can be around 300 to 700 words.

Example topics:

```text
SSO SAML audience mismatch
API 401 Unauthorized errors
Webhook delivery delays
Workspace invite and permission issues
File upload size/type failures
```

---

## Stage 3: Build the KB loader

Create a module that loads Markdown files from `priv/kb`.

Suggested module:

```elixir
SupportBot.KB.Loader
```

It should:

```text
Read all Markdown files from priv/kb
Extract the title from the first heading
Store filename, title, slug, path, and body
Return a list of article maps
```

Example return shape:

```elixir
%{
  id: "01_sso_saml_troubleshooting",
  slug: "sso-saml-troubleshooting",
  title: "SSO SAML Troubleshooting",
  path: "priv/kb/01_sso_saml_troubleshooting.md",
  body: "..."
}
```

---

## Stage 4: Build simple KB search

Create a simple keyword search module.

Suggested module:

```elixir
SupportBot.KB.Search
```

For the MVP, do not use embeddings or vector search yet. Use basic keyword matching.

It should:

```text
Take the user message
Tokenize important words
Search article titles and bodies
Score articles by keyword matches
Return the top 2 or 3 relevant article snippets
```

Example function:

```elixir
SupportBot.KB.Search.search("Customer gets SAML audience mismatch from Okta")
```

Expected result:

```elixir
[
  %{
    title: "SSO SAML Troubleshooting",
    slug: "sso-saml-troubleshooting",
    snippet: "...",
    path: "priv/kb/01_sso_saml_troubleshooting.md"
  }
]
```

---

## Stage 5: Create the AI client

Create an AI client module.

Suggested module:

```elixir
SupportBot.AI.Client
```

Start with Ollama local support.

Ollama endpoint:

```text
http://localhost:11434/api/chat
```

The function should accept:

```text
User message
Conversation history
Relevant KB snippets
Optional task type
```

Use a model name configured through environment variables:

```text
OLLAMA_MODEL=llama3.2
```

Default to:

```text
llama3.2
```

---

## AI system prompt

Use a system prompt like this:

```text
You are a technical support copilot for FlowDesk, a fictional SaaS product.

Use the provided knowledge base context when answering. If the answer is not in the knowledge base, say what information is missing and ask clarifying questions. Do not invent product-specific facts.

For troubleshooting questions, structure your answer as:

1. Likely cause
2. Next troubleshooting steps
3. Information to collect
4. Suggested customer-facing reply
5. Escalation criteria, if relevant
```

---

## Stage 6: Build the LiveView chat interface

Create a LiveView chat page.

Route:

```text
/chat
```

The chat UI should include:

```text
Message list
Text input
Send button
Loading state while bot responds
Bot responses
Sources used
Create Support Ticket button
```

When a user submits a message:

```text
1. Add user message to the chat.
2. Search the local KB.
3. Send user message, KB snippets, and conversation history to the AI client.
4. Display the assistant response.
5. Show the source KB article titles used.
6. Show a prompt: “Still need help? Create a support ticket.”
```

Example prompt:

```text
Still need help?
[Create Support Ticket]
```

---

## Stage 7: Save chat conversations

Add database tables for conversations and messages.

Suggested schemas:

```text
conversations
- id
- title
- inserted_at
- updated_at

messages
- id
- conversation_id
- role
- content
- sources
- inserted_at
- updated_at
```

Roles:

```text
user
assistant
system
```

The chat page should save each user and assistant message.

---

## Stage 8: Create ticket from chatbot conversation

When the user clicks **Create Support Ticket**, show a simple form asking for:

```text
Name
Email
Issue title
Optional additional details
```

Then create a ticket from:

```text
Customer form details
Chat conversation history
AI-generated issue summary
KB sources used
Detected issue category
Detected priority
```

The ticket should include:

```text
Title
Customer name
Customer email
Customer issue summary
Conversation summary
Steps already tried
Likely cause, if known
Missing information
Priority
Issue category
Assigned agent
Status
Created timestamp
```

Suggested statuses:

```text
New
Open
Waiting on Customer
Waiting for Agent
Escalated
Resolved
```

Suggested priorities:

```text
Low
Normal
High
Urgent
```

Suggested categories:

```text
SSO
API
Webhooks
Permissions
File Uploads
Billing
Other
```

For the MVP, do not send real emails. Save the customer email on the ticket and show an on-screen confirmation.

Example confirmation:

```text
Ticket created.

We’ll follow up at: customer@example.com

Assigned Agent: Maya Chen
Team Color: Blue
Status: Open
Reason: Maya is currently in office, specializes in SSO, and has the fewest open tickets among available SSO agents.
```

Include placeholder text:

```text
In a production version, a confirmation summary would be emailed to the customer.
```

---

## Stage 9: Mock support agents

Create 3 to 4 mock agents.

Each agent should have:

```text
Name
Color designation
Specialties
Shift start time
Shift end time
Availability status
Current open ticket count
```

Example mock agents:

```text
1. Maya Chen
Color: Blue
Specialties: SSO, Permissions
Shift: 8:00 AM – 4:00 PM

2. Jordan Lee
Color: Green
Specialties: API, Webhooks
Shift: 12:00 PM – 8:00 PM

3. Sofia Ramirez
Color: Purple
Specialties: Billing, File Uploads
Shift: 4:00 PM – 12:00 AM

4. Marcus Taylor
Color: Orange
Specialties: API, SSO, Escalations
Shift: 10:00 PM – 6:00 AM
```

Agents can be seeded in the database or defined in code. If simple, prefer seeded database agents so ticket counts can be queried.

---

## Stage 10: Agent shift and availability logic

Add simple mock scheduling logic.

Agents should have 8 to 10 hour rotating shifts. The app should determine whether each agent is currently available based on current local server time and the agent’s shift.

Requirements:

```text
Agents are “In Office” if current time falls within their shift.
Agents are “Out of Office” if current time is outside their shift.
At least one agent should usually be available during normal demo hours.
Overnight shifts that cross midnight should work, such as 10:00 PM – 6:00 AM.
```

Suggested module:

```elixir
SupportBot.Agents.Schedule
```

Suggested function:

```elixir
SupportBot.Agents.Schedule.available?(agent, current_time)
```

---

## Stage 11: Automatic ticket assignment

When a ticket is created, automatically assign it to an available agent.

Assignment should consider:

```text
1. Agent availability
2. Issue category match with agent specialties
3. Current open ticket count
4. Color designation for visual routing
```

Suggested behavior:

```text
If one or more available agents specialize in the issue category, assign the ticket to the specialized available agent with the fewest open tickets.

If no available agent specializes in that category, assign the ticket to the available agent with the fewest open tickets.

If no agents are currently available, assign the ticket to the next agent whose shift starts soonest and mark the ticket as "Waiting for Agent."
```

The assignment result should include:

```text
Assigned agent name
Agent color
Agent availability
Assignment reason
```

Example assignment reason:

```text
Assigned to Maya Chen because she is currently in office, specializes in SSO, and has the fewest open tickets among available SSO agents.
```

---

## Stage 12: Ticket database tables

Add ticket-related database tables.

Suggested schemas:

```text
tickets
- id
- conversation_id
- customer_name
- customer_email
- title
- issue_summary
- conversation_summary
- steps_tried
- likely_cause
- missing_information
- priority
- category
- status
- assigned_agent_id
- assignment_reason
- kb_sources
- inserted_at
- updated_at

agents
- id
- name
- color
- specialties
- shift_start
- shift_end
- inserted_at
- updated_at

ticket_events
- id
- ticket_id
- event_type
- message
- inserted_at

ticket_replies
- id
- ticket_id
- author_name
- body
- reply_type
- inserted_at
```

Suggested `ticket_replies.reply_type` values:

```text
agent_reply
internal_note
```

---

## Stage 13: Ticket created notification

When a ticket is created from the chat, show an in-app notification or confirmation panel.

The notification should include:

```text
Ticket title
Assigned agent
Agent color
Assignment reason
Link to view ticket
```

Example notification:

```text
Ticket created and assigned to Jordan Lee.

Reason: Jordan is currently in office, specializes in API and Webhook issues, and has the fewest open tickets among available agents.

[View Ticket]
```

For the MVP, this can be a Phoenix LiveView flash message or visible confirmation panel.

---

## Stage 14: Manager dashboard

The `/tickets` page should act as a **Manager Dashboard**, not just a ticket list.

It should include:

```text
Agent overview
Open ticket queue
Recently assigned tickets
Recent activity
```

### Agent overview section

Show all mock agents in cards.

Each agent card should display:

```text
Agent name
Team color
Current availability: In Office or Out of Office
Shift time
Specialties
Current open ticket count
```

Example:

```text
Maya Chen
Team Color: Blue
Status: In Office
Shift: 8:00 AM – 4:00 PM
Specialties: SSO, Permissions
Open Tickets: 2
```

Use simple color badges for team color.

### Open ticket queue section

Show all open tickets in a table or card layout.

Each ticket should display:

```text
Ticket title
Customer email
Category
Priority
Status
Assigned agent
Agent color
Created timestamp
```

Include visual badges for:

```text
Priority
Status
Agent color
```

### Recent activity panel

Add a simple recent activity panel to the Manager Dashboard.

Examples of activity items:

```text
Ticket created from chatbot conversation.
Ticket assigned to Maya Chen.
Agent reply saved.
Status changed from Open to Waiting on Customer.
Ticket resolved.
```

Activity can be stored in the `ticket_events` table.

---

## Stage 15: Ticket detail page

Create a ticket detail page.

Route:

```text
/tickets/:id
```

The ticket detail page should be the main workspace for reviewing and responding to a ticket.

Show:

```text
Ticket title
Customer name
Customer email
Priority
Category
Status
Assigned agent
Agent color
Assignment reason
Created timestamp
```

Also show:

```text
AI-generated issue summary
Conversation summary
Steps already tried
Likely cause
Missing information
KB sources used
Full chatbot history
Ticket timeline
Agent responses
Internal notes
```

---

## Chatbot history inside each ticket

Each ticket detail page should include the original chatbot conversation history.

Display messages in chronological order:

```text
Customer message
Assistant response
Customer message
Assistant response
```

The purpose is so the support agent can see what the chatbot already suggested before replying.

---

## Stage 16: Agent response composer

Add a simple response box on the ticket detail page.

The agent should be able to write a response and save it to the ticket.

For the MVP, this does not need to send a real email.

The UI should include two reply options:

```text
Customer Reply
Internal Note
```

Behavior:

```text
Customer Reply = saved as a customer-facing response, but not actually emailed.
Internal Note = saved only in the ticket timeline.
```

When the agent saves a reply:

```text
Save the reply in the database.
Show it in the ticket timeline.
Create a recent activity item.
Optionally update ticket status to Waiting on Customer.
Show a confirmation message.
```

Add placeholder text:

```text
In a production version, customer replies would be emailed to the customer.
```

---

## Stage 17: AI agent-assist panel

On the ticket detail page, add an optional AI-assist section.

This can show AI-generated suggestions based on the ticket and chat history:

```text
Suggested customer reply
Suggested next troubleshooting step
Missing information checklist
Escalation summary
```

This can be generated when the ticket is created or triggered by a button:

```text
Generate Agent Assist
```

For the first version, it is okay to generate this from the same AI client used by the chatbot.

---

## Stage 18: Knowledge base viewer

Create a page where users can browse the local KB articles.

Suggested routes:

```text
/kb
/kb/:slug
```

The KB viewer should show:

```text
Article list
Article title
Article body
Slug
```

This lets someone viewing the project see the source docs that power the chatbot.

---

## Stage 19: Support-specific chatbot buttons

Add optional buttons below the chat input or bot response:

```text
Summarize as ticket
Draft customer reply
Create escalation summary
Classify issue type
```

Each button can send a specific instruction to the AI model using the current conversation.

Example instruction for “Summarize as ticket”:

```text
Summarize this conversation into an internal support ticket with:
- Issue summary
- Customer impact
- Steps already tried
- Suspected cause
- Missing information
- Recommended next action
```

---

## Stage 20: README and portfolio polish

Add a clean README explaining:

```text
What the app does
Tech stack
How the RAG-style KB search works
How the mock agent assignment works
How to run Ollama locally
How to start the Phoenix server
Example support questions to try
Future improvements
```

Example questions to include:

```text
Customer gets SAML audience mismatch from Okta. What should I check?
API returns 401 even though the token worked yesterday.
Webhook events are delayed and retries are not arriving.
A user was invited to a workspace but cannot access it.
A customer cannot upload a file larger than 100MB.
```

---

## Suggested project structure

```text
lib/support_bot/
  ai/
    client.ex
    prompts.ex

  kb/
    loader.ex
    search.ex

  chat/
    conversation.ex
    message.ex

  tickets/
    ticket.ex
    ticket_reply.ex
    ticket_event.ex
    assignment.ex

  agents/
    agent.ex
    schedule.ex

lib/support_bot_web/live/
  chat_live.ex
  ticket_live/index.ex
  ticket_live/show.ex
  kb_live/index.ex
  kb_live/show.ex

priv/kb/
  01_sso_saml_troubleshooting.md
  02_api_authentication.md
  03_webhook_delivery.md
  04_workspace_permissions.md
  05_file_upload_limits.md
```

---

## Important MVP constraints

Please keep the first version simple.

Do not add:

```text
Real authentication
Real email sending
Complex permissions
External ticketing integrations
Embeddings/vector databases
Fine-tuning
Complex SLA rules
Calendar integration
Multi-tenant accounts
```

The MVP should use:

```text
Phoenix LiveView
Local Markdown KB files
Basic keyword search
Ollama API
PostgreSQL conversation history
PostgreSQL tickets
Mock agents
Shift-based routing
Manager dashboard
Ticket detail pages
Agent replies/internal notes
```

---

## Future improvements after MVP

After the MVP works, suggest improvements such as:

```text
Vector search with embeddings
Admin UI for editing KB articles
Streaming model responses
User authentication
Real email notifications
Customer ticket status page
Manual ticket reassignment
SLA timers
Agent workload charts
Real-time manager dashboard updates
OpenAI/Anthropic provider option
Deployment instructions
```

---

## Final goal

The final MVP should tell this portfolio story:

```text
I built an AI support triage system in Phoenix/Elixir.

The chatbot uses a local knowledge base to troubleshoot customer issues. If the customer still needs help, the app creates a structured support ticket, summarizes the conversation, classifies the issue, and automatically routes it to the best available mock support agent based on shift availability, specialty, workload, and team color. A manager dashboard shows agent availability and open tickets, and each ticket includes chatbot history, AI summaries, KB sources, internal notes, and agent responses.
```

Please implement this incrementally. After each stage, explain what changed, list the files created or modified, and tell me the command I should run to test it.
