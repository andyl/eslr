defmodule Scriptlr.Output do
  @moduledoc """
  User-facing output with color and verbosity support.
  """

  def info(message) do
    IO.puts(colorize(:cyan, message))
  end

  def error(message) do
    IO.puts(:stderr, colorize(:red, "error: #{message}"))
  end

  def verbose(message) do
    if Process.get(:elr_verbose) do
      IO.puts(:stderr, colorize(:yellow, message))
    end
  end

  def set_verbose(enabled) do
    Process.put(:elr_verbose, enabled)
  end

  defp colorize(color, message) do
    if no_color?() do
      message
    else
      apply(IO.ANSI, color, []) <> message <> IO.ANSI.reset()
    end
  end

  defp no_color? do
    System.get_env("ELR_NO_COLOR") != nil or System.get_env("NO_COLOR") != nil
  end
end
