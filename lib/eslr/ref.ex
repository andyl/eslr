defmodule Eslr.Ref do
  @moduledoc """
  Parses reference strings into structured types for scripts.
  """

  defstruct [:type, :name, :version, :url, :path, :git_ref, :script_path]

  @type t :: %__MODULE__{
          type: :github | :git | :remote_script | :local,
          name: String.t() | nil,
          version: String.t() | nil,
          url: String.t() | nil,
          path: String.t() | nil,
          git_ref: String.t() | nil,
          script_path: String.t() | nil
        }

  @doc """
  Parses a reference string into `{:ok, %Eslr.Ref{}}` or `{:error, reason}`.

  Parse order:
  1. Starts with `https://` and ends with `.exs` → remote script
  2. Starts with `https://` or `http://` → error
  3. Starts with `github:` → GitHub shorthand (with optional path and ref)
  4. Starts with `git+` → git URL
  5. Starts with `./` or `/` or ends with `.exs` → local file
  6. Everything else → error (Hex packages not supported)
  """
  @spec parse(String.t()) :: {:ok, t()} | {:error, String.t()}
  def parse(ref) when is_binary(ref) do
    cond do
      String.starts_with?(ref, "https://") and String.ends_with?(ref, ".exs") ->
        {:ok, %__MODULE__{type: :remote_script, url: ref, name: url_basename(ref)}}

      String.starts_with?(ref, "https://") or String.starts_with?(ref, "http://") ->
        {:error, "non-.exs URLs are not supported: #{ref}"}

      String.starts_with?(ref, "github:") ->
        parse_github(ref)

      String.starts_with?(ref, "git+") ->
        parse_git(ref)

      local_file?(ref) ->
        {:ok, %__MODULE__{type: :local, path: ref, name: Path.basename(ref, Path.extname(ref))}}

      true ->
        {:error,
         "Hex package references are not supported. Use a GitHub repo or URL instead: #{ref}"}
    end
  end

  def parse(_), do: {:error, "reference must be a string"}

  defp local_file?(ref) do
    String.starts_with?(ref, "./") or
      String.starts_with?(ref, "/") or
      String.ends_with?(ref, ".exs")
  end

  defp url_basename(url) do
    url |> URI.parse() |> Map.get(:path) |> Path.basename(".exs")
  end

  defp parse_github("github:" <> rest) do
    # Split on # first to separate git ref
    {main, git_ref} =
      case String.split(rest, "#", parts: 2) do
        [main] -> {main, nil}
        [main, ref] -> {main, ref}
      end

    # Split on : to separate repo from script path
    case String.split(main, ":", parts: 2) do
      [repo] -> build_github(repo, nil, git_ref)
      [repo, script_path] -> build_github(repo, script_path, git_ref)
    end
  end

  defp build_github(repo, script_path, git_ref) do
    case String.split(repo, "/", parts: 2) do
      [_user, name] when name != "" ->
        {:ok,
         %__MODULE__{
           type: :github,
           name: name,
           url: repo,
           git_ref: git_ref,
           script_path: script_path
         }}

      _ ->
        {:error, "invalid GitHub reference: github:#{repo}. Expected format: github:user/repo"}
    end
  end

  defp parse_git("git+" <> rest) do
    case String.split(rest, "#", parts: 2) do
      [url] -> build_git(url, nil)
      [url, git_ref] -> build_git(url, git_ref)
    end
  end

  defp build_git(url, git_ref) do
    name =
      url
      |> String.split("/")
      |> List.last()
      |> String.replace_suffix(".git", "")

    {:ok,
     %__MODULE__{
       type: :git,
       name: name,
       url: url,
       git_ref: git_ref
     }}
  end
end
