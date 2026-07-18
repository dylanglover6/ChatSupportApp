defmodule SupportBot.AI.Client do
  @moduledoc """
  Single boundary for DylanBot's chat calls, behind a configurable provider.

  `LLM_PROVIDER` selects the adapter: `ollama` (local dev, default), `anthropic`
  (hosted Claude in production), or `fallback` (deterministic, no live model).
  Every provider path falls through to the same deterministic fallback on any
  error, so the site never breaks no matter which one is configured.
  """

  alias SupportBot.AI.{PageContext, Prompts}

  @doc """
  Sends a chat turn to the configured model, grounded in DylanDocs snippets and
  the visitor's current page. Returns `{content, status}` where `status` is
  `:live` (a hosted/local model answered) or `:fallback`, so callers can show
  whether a live model served the reply.
  """
  # Keep only the most recent turns in the prompt — long histories are the main driver
  # of slow local inference (every token in the context is re-processed each call).
  @history_window 8
  # Cap generated tokens so verbose models can't run for 20s+ on a short answer.
  @num_predict 256
  # Cheapest hosted option for a portfolio; override with ANTHROPIC_MODEL.
  @anthropic_model "claude-haiku-4-5"
  @anthropic_max_tokens 1024

  def chat(user_message, history, doc_snippets, path \\ "/") do
    recent_history =
      history
      |> Enum.take(-@history_window)
      |> Enum.map(&Map.take(&1, [:role, :content]))

    case provider() do
      :anthropic -> anthropic_chat(user_message, recent_history, doc_snippets, path)
      :ollama -> ollama_chat(user_message, recent_history, doc_snippets, path)
      :fallback -> {fallback_response(user_message, doc_snippets), :fallback}
    end
  end

  defp provider do
    case System.get_env("LLM_PROVIDER") do
      "anthropic" -> :anthropic
      "fallback" -> :fallback
      _ -> :ollama
    end
  end

  defp ollama_chat(user_message, recent_history, doc_snippets, path) do
    model = System.get_env("OLLAMA_MODEL", "llama3.2")

    messages =
      [
        %{role: "system", content: Prompts.system_prompt()},
        %{role: "system", content: context_message(doc_snippets, path)}
      ] ++
        recent_history ++
        [%{role: "user", content: user_message}]

    case Req.post("http://localhost:11434/api/chat",
           json: %{
             model: model,
             messages: messages,
             stream: false,
             # Keep the model resident between messages so we don't pay reload latency.
             keep_alive: "30m",
             options: %{num_predict: @num_predict}
           },
           receive_timeout: 30_000,
           retry: false
         ) do
      {:ok, %{status: 200, body: %{"message" => %{"content" => content}}}} ->
        {content, :live}

      _ ->
        {fallback_response(user_message, doc_snippets), :fallback}
    end
  end

  # Elixir has no official Anthropic SDK, so this is raw HTTP via Req — same shape
  # as the Ollama call. The system prompt goes in the top-level `system` field
  # (not a `role: "system"` message), `messages` is user/assistant only, and
  # `max_tokens` is required. See DEPLOY.md §7.
  defp anthropic_chat(user_message, recent_history, doc_snippets, path) do
    api_key = System.get_env("ANTHROPIC_API_KEY")
    model = System.get_env("ANTHROPIC_MODEL", @anthropic_model)
    system = Prompts.system_prompt() <> "\n\n" <> context_message(doc_snippets, path)
    messages = to_anthropic_messages(recent_history, user_message)

    result =
      if api_key do
        Req.post("https://api.anthropic.com/v1/messages",
          headers: [
            {"x-api-key", api_key},
            {"anthropic-version", "2023-06-01"}
          ],
          json: %{
            model: model,
            max_tokens: @anthropic_max_tokens,
            system: system,
            messages: messages
          },
          receive_timeout: 30_000,
          retry: false
        )
      else
        :no_key
      end

    with {:ok, %{status: 200, body: %{"content" => blocks}}} <- result,
         %{"text" => text} when is_binary(text) <- List.first(blocks) do
      {text, :live}
    else
      _ -> {fallback_response(user_message, doc_snippets), :fallback}
    end
  end

  # Anthropic requires user/assistant roles only and a leading user turn. Map
  # agent replies to assistant, drop internal/system messages, and trim any
  # leading assistant turns so the sequence starts with the visitor.
  defp to_anthropic_messages(recent_history, user_message) do
    recent_history
    |> Enum.map(&%{role: normalize_role(&1.role), content: &1.content})
    |> Enum.filter(&(&1.role in ["user", "assistant"]))
    |> Enum.drop_while(&(&1.role == "assistant"))
    |> Kernel.++([%{role: "user", content: user_message}])
  end

  defp normalize_role("assistant"), do: "assistant"
  defp normalize_role("agent"), do: "assistant"
  defp normalize_role("user"), do: "user"
  defp normalize_role(_), do: "system"

  @doc """
  Quick reachability check for the widget's status dot — not used for the chat
  call itself. For the hosted provider this reports whether a key is configured
  (avoiding a billed request just to light the dot); for Ollama it pings the
  local server.
  """
  def llm_reachable? do
    case provider() do
      :anthropic -> System.get_env("ANTHROPIC_API_KEY") not in [nil, ""]
      :ollama -> ollama_reachable?()
      :fallback -> false
    end
  end

  defp ollama_reachable? do
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
      missing_information:
        "The specific question Dylan should follow up on, and the best way to reach the visitor back.",
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
