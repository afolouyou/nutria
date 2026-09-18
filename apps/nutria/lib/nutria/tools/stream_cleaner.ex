defmodule Nutria.Tools.StreamCleaner do
  @moduledoc """
  Removes tool-call/instruction blocks from an LLM stream chunk-by-chunk so the
  backend never leaks things like `<PANTRY>...</PANTRY>`, `<USAGE>...</USAGE>` or
  `<RECIPE>...</RECIPE>` to the client.

  The LLM answers the visible text and appends one or more `<TAG>json</TAG>`
  blocks as side instructions. Tags may be split across stream chunks, so the
  cleaner keeps a `pending` buffer and only releases text it can prove is safe.

  Usage:
      {visible, pending} = StreamCleaner.stream(pending, chunk)
      # send `visible` to the client, keep `pending` for the next chunk
      safe_text = StreamCleaner.finalize(pending)
      # call once after the stream ends
  """

  @open_tags ["<PANTRY>", "<USAGE>", "<RECIPE>"]
  @open_tag_regex ~r/<(PANTRY|USAGE|RECIPE)>/

  @doc """
  Feeds `chunk` into the cleaner. Returns `{visible, pending}` where `visible`
  (a binary) is safe to stream immediately and `pending` must be passed back on
  the next call.
  """
  def stream(pending, chunk) do
    {visible, pending} = consume(pending <> chunk, [])
    {IO.iodata_to_binary(visible), pending}
  end

  @doc """
  Emits the remaining safe text (a binary) once the stream has finished,
  trimming any dangling/incomplete tool block left at the end.
  """
  def finalize(pending) do
    {visible, held} = consume(pending, [])
    IO.iodata_to_binary(trim_held(visible, held))
  end

  @doc "True when `text` contains no tool block sequence at all (for tests/QA)."
  def clean?(text), do: not String.contains?(text, @open_tags)

  defp consume("", acc), do: {Enum.reverse(acc), ""}

  defp consume(pending, acc) do
    case Regex.run(@open_tag_regex, pending, return: :index) do
      [{start, _} | _] ->
        before = binary_part(pending, 0, start)
        rest = binary_part(pending, start, byte_size(pending) - start)
        tag = Regex.run(@open_tag_regex, rest) |> List.last()
        close = "</" <> tag <> ">"

        case :binary.match(rest, close) do
          {pos, len} ->
            tail = binary_part(rest, pos + len, byte_size(rest) - pos - len)
            consume(tail, [before | acc])

          :nomatch ->
            {Enum.reverse([before | acc]), rest}
        end

      nil ->
        partial = trailing_partial(pending)

        if partial == "" do
          {Enum.reverse([pending | acc]), ""}
        else
          keep = byte_size(partial)
          visible = binary_part(pending, 0, byte_size(pending) - keep)
          {Enum.reverse([visible | acc]), partial}
        end
    end
  end

  defp trim_held(visible, held) do
    case Regex.run(@open_tag_regex, held, return: :index) do
      [{start, _} | _] ->
        Enum.reverse([binary_part(held, 0, start) | visible])

      nil ->
        partial = trailing_partial(held)

        if partial == "" do
          Enum.reverse([held | visible])
        else
          keep = byte_size(partial)
          Enum.reverse([binary_part(held, 0, byte_size(held) - keep) | visible])
        end
    end
  end

  defp trailing_partial(text) do
    n = byte_size(text)
    longest_tag = @open_tags |> Enum.map(&byte_size/1) |> Enum.max()

    Enum.find(
      for(len <- (min(n, longest_tag - 1))..1//-1, do: binary_part(text, n - len, len)),
      "",
      fn suffix ->
        Enum.any?(@open_tags, &(byte_size(&1) > byte_size(suffix) and String.starts_with?(&1, suffix)))
      end
    )
  end
end