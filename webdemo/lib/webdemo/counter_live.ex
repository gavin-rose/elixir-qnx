defmodule Webdemo.CounterLive do
  use Phoenix.LiveView

  # Whitelisted native QNX tools, called from Elixir via System.cmd. pidin is
  # QNX's microkernel thread inspector (priorities, scheduling, states).
  @cmds %{
    "sysinfo" => {"pidin", ["info"]},
    "procs" => {"pidin", ["-F", "%b %50N %p %J"]},
    "uname" => {"uname", ["-a"]}
  }

  @prios [15, 30, 63]

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: :timer.send_interval(1000, self(), :tick)

    socket =
      assign(socket,
        count: 0,
        arch: List.to_string(:erlang.system_info(:system_architecture)),
        os: inspect(:os.type()),
        otp: List.to_string(:erlang.system_info(:otp_release)),
        elixir: System.version(),
        prios: @prios,
        diag_cmd: "sysinfo",
        diag: run_cmd("sysinfo")
      )

    {:ok, socket}
  end

  @impl true
  def handle_info(:tick, socket) do
    socket = update(socket, :count, &(&1 + 1))
    # When viewing the thread table, refresh it each second: a live monitor.
    socket =
      if socket.assigns.diag_cmd == "procs",
        do: assign(socket, diag: run_cmd("procs")),
        else: socket

    {:noreply, socket}
  end

  @impl true
  def handle_event("inc", _params, socket), do: {:noreply, update(socket, :count, &(&1 + 1))}

  def handle_event("diag", %{"cmd" => cmd}, socket) do
    {:noreply, assign(socket, diag_cmd: cmd, diag: run_cmd(cmd))}
  end

  # Launch a task at a chosen QNX real-time priority, detached so System.cmd does
  # not block, then switch to the live thread table to watch it appear.
  def handle_event("spawn", %{"prio" => p}, socket) do
    case Integer.parse(p) do
      {prio, ""} when prio in @prios ->
        System.cmd("sh", ["-c", "on -p #{prio} sleep 60 </dev/null >/dev/null 2>&1 &"])

      _ ->
        :noop
    end

    {:noreply, assign(socket, diag_cmd: "procs", diag: run_cmd("procs"))}
  end

  defp run_cmd(key) do
    case Map.fetch(@cmds, key) do
      {:ok, {exe, args}} ->
        try do
          {out, _status} = System.cmd(exe, args, stderr_to_stdout: true)
          out
        rescue
          e -> "error running #{key}: #{Exception.message(e)}"
        end

      :error ->
        "unknown command"
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <h1>Elixir <span class="arrow">→</span> QNX</h1>
    <p class="sub">Phoenix LiveView on the BEAM, running on the QNX 8.0 real-time OS</p>

    <div class="panel">
      <h2>Live over the websocket</h2>
      <div class="count"><%= @count %></div>
      <p class="count-label">seconds since this view mounted, server-pushed, no reloads</p>
      <button class="primary" phx-click="inc">+1 from a click</button>
      <table class="kv">
        <tr><td>system_architecture</td><td><%= @arch %></td></tr>
        <tr><td>os:type</td><td><%= @os %></td></tr>
        <tr><td>otp_release</td><td><%= @otp %></td></tr>
        <tr><td>elixir</td><td><%= @elixir %></td></tr>
      </table>
    </div>

    <div class="panel">
      <h2>QNX real-time scheduler, driven from Elixir</h2>
      <div class="row">
        <span class="lab">inspect</span>
        <button phx-click="diag" phx-value-cmd="sysinfo">pidin info</button>
        <button phx-click="diag" phx-value-cmd="procs">live threads</button>
        <button phx-click="diag" phx-value-cmd="uname">uname</button>
      </div>
      <div class="row">
        <span class="lab">spawn a real-time task</span>
        <button :for={p <- @prios} phx-click="spawn" phx-value-prio={p}>priority <%= p %></button>
      </div>
      <p :if={@diag_cmd == "procs"} class="live"><span class="dot"></span>live, refreshing each second</p>
      <pre><%= @diag %></pre>
    </div>
    """
  end
end
