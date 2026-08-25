defmodule SupportBot.KB.SearchTest do
  # Pure: reads Markdown from priv/kb, no database.
  use ExUnit.Case, async: true

  alias SupportBot.KB.Search

  describe "search/2 relevance" do
    test "ranks the on-topic doc first for an inflected query" do
      # "worked" must stem to "work" and hit the Work History doc.
      assert [%{slug: "work-history"} | _] = Search.search("Where has Dylan worked?")
    end

    test "surfaces a doc referenced by name" do
      assert [%{slug: "project-plot-twist"} | _] = Search.search("tell me about plot twist")
    end

    test "returns no sources for an off-topic query" do
      assert Search.search("what is the meaning of life") == []
    end

    test "honors the result limit" do
      assert length(Search.search("skills projects work docs career", 3)) <= 3
    end

    test "each result carries the fields callers depend on" do
      [first | _] = Search.search("what programming languages does he know")
      assert is_binary(first.title) and first.title != ""
      assert is_binary(first.slug) and first.slug != ""
      assert is_binary(first.snippet)
    end
  end
end
