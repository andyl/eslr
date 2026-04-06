defmodule Elr.Resolver do
  @moduledoc """
  Converts parsed refs into actionable targets: clone URLs, download URLs, or local paths.
  """

  alias Elr.Ref

  @spec resolve(Ref.t()) ::
          {:clone, String.t(), String.t() | nil}
          | {:script, String.t()}
          | {:local, String.t()}

  def resolve(%Ref{type: :github, url: repo, git_ref: git_ref}) do
    {:clone, "https://github.com/#{repo}.git", git_ref}
  end

  def resolve(%Ref{type: :git, url: url, git_ref: git_ref}) do
    {:clone, url, git_ref}
  end

  def resolve(%Ref{type: :remote_script, url: url}) do
    {:script, url}
  end

  def resolve(%Ref{type: :local, path: path}) do
    {:local, path}
  end
end
