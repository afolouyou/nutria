defmodule Nutria.StreamCleanerTest do
  use ExUnit.Case, async: true

  alias Nutria.Tools.StreamCleaner

  defp pump(chunks) do
    {outs, pending} =
      Enum.reduce(chunks, {[], ""}, fn chunk, {outs, pending} ->
        {visible, pending2} = StreamCleaner.stream(pending, chunk)
        {[visible | outs], pending2}
      end)

    StreamCleaner.finalize(pending)
    |> then(fn final -> Enum.reverse([final | outs]) |> Enum.join() end)
  end

  describe "stream/2" do
    test "strips a full PANTRY block present in a single chunk" do
      assert pump(["Olá! Atualizei sua despensa. <PANTRY>{\"add\":[]}</PANTRY> tudo certo."]) ==
               "Olá! Atualizei sua despensa.  tudo certo."
    end

    test "never leaks an opening tag when the block is split across chunks" do
      chunks = ["<PANTRY>", "{\"add\":[{\"name\":\"maçã\",", "\"quantity\":2,\"unit\":\"un\"}]}", "</PANTRY>", "Pronto!"]

      {outs, _} =
        Enum.reduce(chunks, {[], ""}, fn chunk, {outs, pending} ->
          {visible, pending2} = StreamCleaner.stream(pending, chunk)
          {[visible | outs], pending2}
        end)

      for out <- outs do
        assert StreamCleaner.clean?(out)
        refute out =~ "<PAN"
      end

      assert pump(chunks) == "Pronto!"
    end

    test "trims a trailing partial opening tag when the stream ends" do
      assert pump(["Texto", " da resposta <PAN"]) == "Texto da resposta "
    end

    test "trims the longest partial tag (<PANTRY) at the end of a chunk" do
      {visible_prev, pending} = StreamCleaner.stream("", "Pronto! <PANTRY")
      assert visible_prev == "Pronto! "
      refute pending == ""
      assert pump([pending, ">{\"add\":[]}</PANTRY>", "e fim"]) == "e fim"
    end

    test "trims a dangling full opening tag without closing when the stream ends" do
      assert pump(["Resposta ", "<PANTRY>{\"add\":[]}"]) == "Resposta "
    end

    test "keeps text that follows a complete block" do
      assert pump(["A", "<USAGE>[{\"name\":\"x\",\"quantity\":1}]</USAGE>", "B", "<RECIPE>{}</RECIPE>", "C"]) ==
               "ABC"
    end

    test "passes plain text through unchanged and in order" do
      assert pump(["olá", ", plan", "o de hoje"]) == "olá, plano de hoje"
    end

    test "handles a closing tag in a separate chunk from the opening" do
      assert pump(["x<RECIPE>", "{\"name\":\"Bolo\"}", "</RECIPE>", "y"]) == "xy"
    end

    test "passes text that merely resembles a tag name but is not a full tag" do
      assert pump(["veja a se", "ção PANTRY no texto"]) == "veja a seção PANTRY no texto"
    end
  end
end