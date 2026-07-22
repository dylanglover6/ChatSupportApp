defmodule SupportBot.AI.PageContext do
  @moduledoc """
  Page-aware context blocks for DylanBot, keyed by the visitor's current path.

  Pure prompt engineering, no model capability required (see DylanDocs colophon).
  """

  alias SupportBot.KB.Loader

  def for_path("/") do
    %{
      name: "Home",
      description:
        "Dylan's portfolio landing page: hero, about/skills, projects, resume, and a DylanDocs teaser.",
      actions: ["Show me Dylan's skills", "Show me Dylan's projects", "How do I get the resume?"]
    }
  end

  def for_path("/docs") do
    %{
      name: "DylanDocs index",
      description:
        "The documentation site about Dylan: skills, projects, career, personal, and meta docs.",
      actions: [
        "What's in DylanDocs?",
        "What are Dylan's skills?",
        "Tell me about this platform's architecture"
      ]
    }
  end

  def for_path("/docs/" <> slug) do
    case Loader.get_by_slug(slug) do
      nil ->
        unknown_page()

      doc ->
        %{
          name: "DylanDocs: #{doc.title}",
          description: doc.summary,
          actions: [
            "Summarize this page",
            "What else should I read next?",
            "Take me back to DylanDocs"
          ]
        }
    end
  end

  def for_path("/support/" <> _id) do
    %{
      name: "DylanSupport ticket workspace",
      description:
        "A single mock support ticket: chat history, AI summary, and agent replies for one escalated conversation.",
      actions: [
        "What is DylanSupport?",
        "How do tickets get assigned?",
        "Take me back to the queue"
      ]
    }
  end

  def for_path("/support") do
    %{
      name: "DylanSupport",
      description:
        "The mock support agent desk: agent overview, open ticket queue, and recent activity.",
      actions: [
        "What is DylanSupport?",
        "How do tickets get assigned?",
        "Leave a message for Dylan"
      ]
    }
  end

  def for_path("/chat") do
    %{
      name: "Full-page chat",
      description: "The full-page version of this same DylanBot conversation.",
      actions: ["What are Dylan's skills?", "Tell me about this platform", "Leave a message for Dylan"]
    }
  end

  def for_path(_other), do: unknown_page()

  defp unknown_page do
    %{
      name: "Unknown page",
      description: "The visitor's current page couldn't be identified.",
      actions: ["What is this site?", "What are Dylan's skills?", "Browse DylanDocs"]
    }
  end
end
