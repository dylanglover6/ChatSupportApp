defmodule SupportBot.AI.Client do
  @moduledoc "Ollama chat client with a deterministic fallback for demos."

  alias SupportBot.AI.{PageContext, Prompts}

  @doc """
  Sends a chat turn to the local Ollama model, grounded in DylanDocs snippets and
  the visitor's current page. Returns `{content, status}` where `status` is
  `:ollama` or `:fallback`, so callers can show whether a live model answered.
  """
  def chat(user_message, history, doc_snippets, path \\ "/") do
    model = System.get_env("OLLAMA_MODEL", "llama3.2")

    messages =
      [
        %{role: "system", content: Prompts.system_prompt()},
        %{role: "system", content: context_message(doc_snippets, path)}
      ] ++
        Enum.map(history, &Map.take(&1, [:role, :content])) ++
        [%{role: "user", content: user_message}]

    case Req.post("http://localhost:11434/api/chat",
           json: %{model: model, messages: messages, stream: false},
           receive_timeout: 20_000,
           retry: false
         ) do
      {:ok, %{status: 200, body: %{"message" => %{"content" => content}}}} ->
        {content, :ollama}

      _ ->
        {fallback_response(user_message, doc_snippets), :fallback}
    end
  end

  @doc "Quick reachability check for the widget's status dot — not used for the chat call itself."
  def ollama_reachable? do
    case Req.get("http://localhost:11434/api/tags", receive_timeout: 1_000, retry: false) do
      {:ok, %{status: 200}} -> true
      _ -> false
    end
  rescue
    _ -> false
  end

  def summarize_ticket(messages, details, sources) do
    text = Enum.map_join(messages, "\n", &"#{&1.role}: #{&1.content}")
    source_titles = Enum.map_join(sources, ", ", & &1["title"])
    combined = "#{details["title"]} #{details["details"]}"

    support_level = detect_support_level(combined)

    %{
      issue_summary: details["title"],
      conversation_summary: String.slice(text, 0, 900),
      steps_tried: "See chatbot history. The assistant used DylanDocs sources: #{source_titles}.",
      likely_cause: infer_likely_cause(combined),
      missing_information: "The specific question Dylan should follow up on, and the best way to reach the visitor back.",
      priority: detect_priority(combined),
      category: detect_category(combined),
      support_level: support_level,
      urgent: support_level == 3
    }
  end

  def agent_assist(ticket, messages) do
    """
    Suggested reply:
    Thanks for reaching out! I looked over the conversation with DylanBot on the #{ticket.category} topic. Let me know if there's anything specific you'd like Dylan to follow up on.

    Suggested next step:
    Skim the chatbot history, then reply directly or leave an internal note for Dylan with any missing context.

    Missing information checklist:
    - Best way to reach the visitor back
    - Which DylanDocs page (if any) prompted the question
    - Anything DylanBot said it didn't know

    Escalation summary:
    Visitor asked about "#{ticket.title}". Conversation contains #{length(messages)} chatbot messages and should be escalated if it needs Dylan's direct, personal input.
    """
  end

  def detect_category(text) do
    text = String.downcase(text || "")

    cond do
      text =~ ~r/hire|hiring|job|role|position|recruit|interview|opportunit/ -> "Hiring"
      text =~ ~r/project|architecture|built|stack|repo|github|codebase/ -> "Projects"
      text =~ ~r/doc|documentation|typo|correct|broken link|kb page/ -> "Docs"
      true -> "General"
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

  def detect_support_level(text) do
    text = String.downcase(text || "")

    cond do
      text =~ ~r/urgent|asap|broken|down|production|blocked|critical|emergency/ -> 3
      text =~ ~r/error|bug|technical|integration|architecture|code|deploy|stack/ -> 2
      true -> 1
    end
  end

  defp context_message(snippets, path) do
    page = PageContext.for_path(path)

    docs =
      if snippets == [] do
        "No matching DylanDocs pages were found for this message."
      else
        Enum.map_join(snippets, "\n\n", fn item ->
          "#{item.title} (slug: #{item.slug})\n#{item.snippet}"
        end)
      end

    """
    Current page: #{page.name} — #{page.description}
    Suggested actions here: #{Enum.join(page.actions, "; ")}

    DylanDocs context:
    #{docs}
    """
  end

  defp fallback_response(message, []) do
    if vague_help_request?(message) do
      """
      Howdy! I can answer questions about Dylan — his skills, projects, work history, or how this site itself is built.

      What would you like to know?
      """
    else
      """
      I don't see a DylanDocs page that covers that yet, and I'd rather not guess.

      Want to leave a message for Dylan instead? He can follow up directly.
      """
    end
  end

  defp fallback_response(_message, snippets) do
    top = List.first(snippets)

    """
    This sounds related to [[#{top.slug}]].

    Want me to point you to more DylanDocs pages, or would you rather leave a message for Dylan?
    """
  end

  defp vague_help_request?(message) do
    normalized =
      message
      |> String.downcase()
      |> String.replace(~r/[^a-z0-9\s]/, " ")
      |> String.trim()

    normalized in ["help", "hi", "hello", "hey", "howdy", "i need help"] or
      String.length(normalized) < 12
  end

  defp infer_likely_cause(text),
    do: "Likely a question about #{detect_category(text)} — see the chatbot history for detail."
end
