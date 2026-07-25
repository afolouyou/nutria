defmodule Nutria.LLM.Provider do
  @moduledoc """
  Behaviour for LLM providers.
  """

  @type messages :: [map()]
  @type opts :: keyword()

  @callback chat(messages, opts) ::
              {:ok, String.t()} | {:error, atom(), String.t()}

  @callback chat_stream(messages, pid(), opts) ::
              :ok | {:error, atom(), String.t()}
end
