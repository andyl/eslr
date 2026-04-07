defmodule Scriptlr.Runner do
  @moduledoc """
  Executes scripts as subprocesses via the elixir interpreter.
  """

  alias Scriptlr.Output

  @spec run({:script, String.t()}, Scriptlr.Ref.t(), [String.t()]) :: :ok | {:error, String.t()}

  def run({:script, path}, _ref, argv) do
    Output.verbose("Running script: #{path}")

    port =
      Port.open({:spawn_executable, System.find_executable("elixir")}, [
        :binary,
        :exit_status,
        :stderr_to_stdout,
        args: [path | argv]
      ])

    stream_port(port)
  end

  defp stream_port(port) do
    receive do
      {^port, {:data, data}} ->
        IO.write(data)
        stream_port(port)

      {^port, {:exit_status, 0}} ->
        :ok

      {^port, {:exit_status, code}} ->
        {:error, "process exited with status #{code}"}
    end
  end
end
