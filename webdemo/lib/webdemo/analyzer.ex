defmodule Webdemo.Analyzer do
  @moduledoc """
  Supervises and reads the native QNX analyzer process. The real-time sampling
  loop is the C program, scheduled by QNX (via `on -p` at a real-time priority);
  this GenServer opens a port to it, parses its telemetry, and republishes it on
  PubSub. When the native process dies, this GenServer stops and its supervisor
  restarts it, so the console sees the device drop and recover.
  """
  use GenServer
  require Logger

  alias Webdemo.FaultLab

  @topic "analyzer"
  def topic, do: @topic

  def start_link(_opts), do: GenServer.start_link(__MODULE__, :ok, name: __MODULE__)

  @doc "Current sample, recent history, and native OS pid, for a fresh page load."
  def latest do
    GenServer.call(__MODULE__, :latest)
  catch
    :exit, _ -> {nil, [], nil}
  end

  @doc "The analyzer's pid and scheduling priority as QNX's pidin reports them, or nil off QNX."
  def sched_info do
    with pidin when is_binary(pidin) <- System.find_executable("pidin") || boot_tool("pidin"),
         {out, 0} <- System.cmd(pidin, ["-F", "%a %60N %p"], stderr_to_stdout: true) do
      out
      |> String.split("\n")
      |> Enum.find_value(fn line ->
        case String.split(line) do
          [pid, name, prio] -> if String.ends_with?(name, "analyzer"), do: %{pid: pid, prio: prio}
          _ -> nil
        end
      end)
    else
      _ -> nil
    end
  end

  defp boot_tool(name) do
    path = "/proc/boot/" <> name
    if File.exists?(path), do: path
  end

  @impl true
  def init(:ok) do
    # Clear any lingering fault so a restart does not immediately re-crash.
    FaultLab.reset()
    port = open_port()
    os_pid = os_pid(port)
    broadcast({:status, {:up, os_pid}})
    {:ok, %{port: port, os_pid: os_pid, last: nil, history: []}}
  end

  @impl true
  def handle_info({port, {:data, {:eol, line}}}, %{port: port} = state) do
    case parse(line) do
      {:ok, sample} ->
        history = Enum.take([sample | state.history], 90)
        broadcast({:telemetry, sample})
        {:noreply, %{state | last: sample, history: history}}

      :error ->
        {:noreply, state}
    end
  end

  def handle_info({port, {:exit_status, code}}, %{port: port} = state) do
    Logger.warning("analyzer exited (#{code})")
    broadcast({:status, {:down, code, state.os_pid}})
    {:stop, {:analyzer_exit, code}, state}
  end

  def handle_info(_other, state), do: {:noreply, state}

  @impl true
  def handle_call(:latest, _from, state),
    do: {:reply, {state.last, state.history, state.os_pid}, state}

  defp os_pid(port) do
    case Port.info(port, :os_pid) do
      {:os_pid, pid} -> pid
      _ -> nil
    end
  end

  defp open_port do
    bin = System.get_env("ANALYZER_BIN", "/data/opt/webdemo/analyzer")
    prio = System.get_env("ANALYZER_PRIO", "20")

    # On QNX, launch through `on -p` so the microkernel schedules it at a
    # real-time priority. Elsewhere (dev host) spawn the stub directly.
    {exe, args} =
      if File.exists?("/proc/boot/on"),
        do: {"/proc/boot/on", ["-p", prio, bin]},
        else: {bin, []}

    Port.open({:spawn_executable, exe}, [:binary, :exit_status, {:line, 512}, args: args])
  end

  defp parse("TELEM " <> rest) do
    case String.split(rest, " ", trim: true) do
      [seq, reading, temp, pressure, status] ->
        {:ok,
         %{
           seq: String.to_integer(seq),
           reading: to_f(reading),
           temp: to_f(temp),
           pressure: to_f(pressure),
           status: status,
           at: System.system_time(:millisecond)
         }}

      _ ->
        :error
    end
  end

  defp parse(_), do: :error

  defp to_f(s) do
    case Float.parse(s) do
      {f, _} -> f
      :error -> 0.0
    end
  end

  defp broadcast(msg), do: Phoenix.PubSub.broadcast(Webdemo.PubSub, @topic, msg)
end
