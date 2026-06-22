defmodule SupportBot.AI.Client do
  @moduledoc "Ollama chat client with a deterministic fallback for demos."

  alias SupportBot.AI.Prompts

  def chat(user_message, history, kb_snippets, task_type \\ "troubleshooting") do
    model = System.get_env("OLLAMA_MODEL", "llama3.2")

    messages =
      [
        %{role: "system", content: Prompts.system_prompt()},
        %{role: "system", content: context_message(kb_snippets, task_type)}
      ] ++
        Enum.map(history, &Map.take(&1, [:role, :content])) ++
        [%{role: "user", content: user_message}]

    case Req.post("http://localhost:11434/api/chat",
           json: %{model: model, messages: messages, stream: false},
           receive_timeout: 20_000
         ) do
      {:ok, %{status: 200, body: %{"message" => %{"content" => content}}}} -> content
      _ -> fallback_response(user_message, kb_snippets)
    end
  end

  def summarize_ticket(messages, details, sources) do
    text = Enum.map_join(messages, "\n", &"#{&1.role}: #{&1.content}")
    source_titles = Enum.map_join(sources, ", ", & &1["title"])

    %{
      issue_summary: details["title"],
      conversation_summary: String.slice(text, 0, 900),
      steps_tried: "See chatbot history. The assistant used KB sources: #{source_titles}.",
      likely_cause: infer_likely_cause(details["title"] <> " " <> details["details"]),
      missing_information:
        "Exact timestamps, workspace ID, request IDs, screenshots, and recent configuration changes.",
      priority: detect_priority(details["title"] <> " " <> details["details"]),
      category: detect_category(details["title"] <> " " <> details["details"])
    }
  end

  def agent_assist(ticket, messages) do
    """
    Suggested customer reply:
    Thanks for the details. I reviewed the chatbot history and the #{ticket.category} troubleshooting path. Please send any missing IDs, timestamps, and recent configuration changes so we can verify the next step.

    Suggested next troubleshooting step:
    Reproduce the issue once, capture the exact error or request ID, and compare it against the relevant FlowDesk KB article.

    Missing information checklist:
    - Workspace ID
    - Timestamp and timezone
    - Error text or request ID
    - Recent admin or configuration changes

    Escalation summary:
    Customer reported #{ticket.title}. Conversation contains #{length(messages)} chatbot messages and should be escalated if the issue blocks production usage or requires backend log inspection.
    """
  end

  def detect_category(text) do
    text = String.downcase(text || "")

    cond do
      text =~ ~r/sso|saml|okta|login/ -> "SSO"
      text =~ ~r/api|token|401|unauthorized/ -> "API"
      text =~ ~r/webhook|delivery|retry/ -> "Webhooks"
      text =~ ~r/permission|invite|workspace|access/ -> "Permissions"
      text =~ ~r/upload|file|size|type/ -> "File Uploads"
      text =~ ~r/billing|invoice|account/ -> "Billing"
      true -> "Other"
    end
  end

  def detect_priority(text) do
    text = String.downcase(text || "")

    cond do
      text =~ ~r/down|outage|production|blocked|urgent/ -> "Urgent"
      text =~ ~r/error|failing|cannot|can't|unable/ -> "High"
      text =~ ~r/question|how do|can i/ -> "Low"
      true -> "Normal"
    end
  end

  defp context_message(snippets, task_type) do
    context =
      snippets
      |> Enum.map_join("\n\n", fn item -> "#{item.title}\n#{item.snippet}" end)

    "Task: #{task_type}\nKnowledge base context:\n#{context}"
  end

  defp fallback_response(message, []) do
    if vague_help_request?(message) do
      """
      I can help with FlowDesk issues like SSO login, API tokens, webhooks, permissions, file uploads, or billing.

      What are you trying to do, and what error or unexpected behavior are you seeing?
      """
    else
      """
      I do not see a direct match in the FlowDesk knowledge base yet.

      Can you share the exact error, the affected workspace or user, and what you were trying to do when it happened?
      """
    end
  end

  defp fallback_response(message, snippets) do
    top = List.first(snippets)

    if detailed_troubleshooting_request?(message) do
      detailed_fallback(top)
    else
      """
      This sounds like it may relate to #{top.title}.

      A good next step is to share the exact error message, when it happened, and the affected workspace or user. If you want, I can also turn this into a support ticket.
      """
    end
  end

  defp detailed_fallback(top) do
    """
    1. Likely cause
    This looks related to #{top.title}. The most likely cause is a configuration mismatch or missing request detail covered by that KB article.

    2. Next steps
    Review the article steps, reproduce the issue, and compare the customer's configuration against the expected FlowDesk settings.

    3. Information to collect
    Workspace ID, affected user, timestamp, full error text, request ID, and recent configuration changes.

    4. Escalation criteria
    Escalate if the customer remains blocked after the KB checks or if backend logs are required.
    """
  end

  defp vague_help_request?(message) do
    normalized =
      message
      |> String.downcase()
      |> String.replace(~r/[^a-z0-9\s]/, " ")
      |> String.trim()

    normalized in ["help", "hi", "hello", "hey", "support", "i need help"] or
      String.length(normalized) < 12
  end

  defp detailed_troubleshooting_request?(message) do
    text = String.downcase(message || "")

    String.length(text) > 60 or
      text =~
        ~r/error|failing|failed|cannot|can't|unable|401|403|500|saml|webhook|upload|permission|token|api|sso/
  end

  defp infer_likely_cause(text),
    do: "Likely related to #{detect_category(text)} configuration or request context."
end
