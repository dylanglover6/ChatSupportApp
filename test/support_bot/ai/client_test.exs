defmodule SupportBot.AI.ClientTest do
  # async: false — these tests toggle the process-global LLM_PROVIDER env var.
  use ExUnit.Case, async: false

  alias SupportBot.AI.Client
  alias SupportBot.KB.Search

  setup do
    original = System.get_env("LLM_PROVIDER")

    on_exit(fn ->
      if original,
        do: System.put_env("LLM_PROVIDER", original),
        else: System.delete_env("LLM_PROVIDER")
    end)

    :ok
  end

  test "max_message_chars/0 exposes the input cap" do
    assert Client.max_message_chars() == 2000
  end

  describe "chat/4 on the deterministic fallback provider" do
    setup do
      System.put_env("LLM_PROVIDER", "fallback")
      :ok
    end

    test "returns a :fallback status and a non-empty reply, with no network call" do
      {reply, status} = Client.chat("Where has Dylan worked?", [], [], "/")
      assert status == :fallback
      assert is_binary(reply) and reply != ""
    end

    test "points at the top matching doc when snippets are supplied" do
      snippets = Search.search("Where has Dylan worked?")
      {reply, :fallback} = Client.chat("Where has Dylan worked?", [], snippets, "/")
      # fallback_response/2 links the top snippet's slug as [[work-history]].
      assert reply =~ "work-history"
    end
  end
end
