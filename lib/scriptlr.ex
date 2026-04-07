defmodule Scriptlr do
  @moduledoc """
  Elixir Script Load & Run — the Elixir equivalent of `npx`.

  Loads and runs Elixir scripts (.exs files with `Mix.install`) from
  git repos or URLs with automatic dependency fetching.
  """

  @version Mix.Project.config()[:version]

  def version, do: @version
end
