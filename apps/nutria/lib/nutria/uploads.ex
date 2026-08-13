defmodule Nutria.Uploads do
  @moduledoc """
  Avatar upload helpers — stores files under priv/static/uploads/avatars
  and fetches remote avatars (e.g. Google profile pictures).
  """

  @max_size 5_000_000
  @allowed_types ~w(image/jpeg image/png image/webp image/gif)
  @extensions %{
    "image/jpeg" => "jpg",
    "image/png" => "png",
    "image/webp" => "webp",
    "image/gif" => "gif"
  }

  def dir do
    Application.app_dir(:nutria_web, "priv/static/uploads/avatars")
  end

  def store(source_path, user_id) do
    with {:ok, %{size: size}} <- File.stat(source_path),
         true <- size <= @max_size do
      content_type = content_type(source_path)

      if valid_type?(content_type) do
        filename = "#{user_id}_#{System.system_time(:millisecond)}.#{@extensions[content_type]}"
        File.mkdir_p!(dir())

        case File.cp(source_path, Path.join(dir(), filename)) do
          :ok -> {:ok, filename}
          {:error, reason} -> {:error, :internal_error, "Não foi possível salvar a foto: #{inspect(reason)}"}
        end
      else
        {:error, :bad_request, "Formato não suportado. Use JPG, PNG, WebP ou GIF."}
      end
    else
      {:ok, %{size: _}} -> {:error, :bad_request, "Foto muito grande. Máximo de 5 MB."}
      _ -> {:error, :bad_request, "Arquivo inválido."}
    end
  end

  def delete(filename) when is_binary(filename) and filename != "" do
    File.rm(Path.join(dir(), filename))
    :ok
  end

  def delete(_), do: :ok

  def fetch_remote(url, user_id) when is_binary(url) and url != "" do
    case Req.get(url, receive_timeout: 15_000) do
      {:ok, %Req.Response{status: 200, body: body, headers: headers}}
      when is_binary(body) and byte_size(body) <= @max_size ->
        content_type = content_type_from_headers(headers)

        if valid_type?(content_type) do
          filename = "#{user_id}_google.#{@extensions[content_type]}"
          File.mkdir_p!(dir())

          case File.write(Path.join(dir(), filename), body) do
            :ok -> {:ok, filename}
            _ -> {:error, :bad_request, "Não foi possível salvar a foto do Google"}
          end
        else
          {:error, :bad_request, "Formato da foto do Google não suportado"}
        end

      _ ->
        {:error, :bad_gateway, "Não foi possível buscar a foto do Google"}
    end
  rescue
    _ -> {:error, :bad_gateway, "Não foi possível buscar a foto do Google"}
  end

  def fetch_remote(_, _), do: {:error, :bad_request, "Foto do Google indisponível"}

  defp content_type(path) do
    case File.read(path) do
      {:ok, <<0xFF, 0xD8, 0xFF, _::binary>>} -> "image/jpeg"
      {:ok, <<0x89, 0x50, 0x4E, 0x47, _::binary>>} -> "image/png"
      {:ok, <<0x52, 0x49, 0x46, 0x46, _::binary-size(4), 0x57, 0x45, 0x42, 0x50, _::binary>>} ->
        "image/webp"
      {:ok, <<"GIF87a", _::binary>>} -> "image/gif"
      {:ok, <<"GIF89a", _::binary>>} -> "image/gif"
      _ -> "unknown"
    end
  end

  defp content_type_from_headers(headers) do
    headers
    |> Enum.find_value(fn {k, v} ->
      if String.downcase(k) == "content-type", do: v |> to_string() |> String.split(";") |> List.first()
    end)
    |> case do
      nil -> "unknown"
      ct -> String.downcase(ct)
    end
  end

  defp valid_type?(type), do: type in @allowed_types
end
