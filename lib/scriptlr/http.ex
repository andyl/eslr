defmodule Scriptlr.Http do
  @moduledoc """
  HTTP client wrapper using Erlang's built-in `:httpc`.
  """

  def get(url) do
    url_charlist = String.to_charlist(url)

    ssl_opts = [
      ssl: [
        verify: :verify_peer,
        cacerts: :public_key.cacerts_get(),
        depth: 3,
        customize_hostname_check: [
          match_fun: :public_key.pkix_verify_hostname_match_fun(:https)
        ]
      ]
    ]

    case :httpc.request(:get, {url_charlist, []}, ssl_opts, body_format: :binary) do
      {:ok, {{_, status, _}, _headers, body}} when status in 200..299 ->
        {:ok, body}

      {:ok, {{_, status, reason}, _headers, _body}} ->
        {:error, "HTTP #{status}: #{reason}"}

      {:error, reason} ->
        {:error, "HTTP request failed: #{inspect(reason)}"}
    end
  end
end
