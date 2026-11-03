defmodule Webdemo.CounterLive do
  use Phoenix.LiveView

  # Whitelisted native QNX tools, called from Elixir via System.cmd. pidin is
  # QNX's microkernel thread inspector (priorities, scheduling, states).
  @cmds %{
    "sysinfo" => {"pidin", ["info"]},
    "procs" => {"pidin", ["-F", "%b %50N %p %J"]},
    "uname" => {"uname", ["-a"]}
  }

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
        diag_cmd: "sysinfo",
        diag: run_cmd("sysinfo")
      )

    {:ok, socket}
  end

  @impl true
  def handle_info(:tick, socket), do: {:noreply, update(socket, :count, &(&1 + 1))}

  @impl true
  def handle_event("inc", _params, socket), do: {:noreply, update(socket, :count, &(&1 + 1))}

  def handle_event("diag", %{"cmd" => cmd}, socket) do
    {:noreply, assign(socket, diag_cmd: cmd, diag: run_cmd(cmd))}
  end

  # Shell out to a native QNX tool and return its output, failing soft so a
  # missing tool (e.g. when running on the dev host) does not crash the view.
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
    <h1>Phoenix LiveView on QNX</h1>
    <div class="card">
      <p>
        Served by <b>Bandit</b> + <b>Phoenix LiveView</b> on the <b>BEAM</b>,
        running on <b>QNX 8.0</b>, pushed live over a websocket to your browser.
      </p>
      <p class="big"><%= @count %></p>
      <p>seconds since this LiveView mounted (server push, no reloads)</p>
      <button phx-click="inc">+1 from a click</button>
      <table>
        <tr><td class="k">system_architecture</td><td class="v"><%= @arch %></td></tr>
        <tr><td class="k">os:type</td><td class="v"><%= @os %></td></tr>
        <tr><td class="k">otp_release</td><td class="v"><%= @otp %></td></tr>
        <tr><td class="k">elixir</td><td class="v"><%= @elixir %></td></tr>
      </table>

      <h2 style="font-size:15px;margin-top:24px">Native QNX diagnostics, called from Elixir via System.cmd</h2>
      <p>
        <button phx-click="diag" phx-value-cmd="sysinfo">pidin info</button>
        <button phx-click="diag" phx-value-cmd="procs">threads &amp; priorities</button>
        <button phx-click="diag" phx-value-cmd="uname">uname -a</button>
      </p>
      <pre style="background:#0b0d12;border:1px solid #262b33;border-radius:8px;padding:12px;overflow:auto;max-height:360px;color:#cfe3c0"><%= @diag %></pre>
    </div>
    """
  end
end
