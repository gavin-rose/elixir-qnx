defmodule Webdemo.ConsoleLive do
  use Phoenix.LiveView

  alias Webdemo.{Analyzer, FaultLab}

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Phoenix.PubSub.subscribe(Webdemo.PubSub, Analyzer.topic())

    {last, history, pid} = Analyzer.latest()

    status =
      cond do
        last == nil -> :connecting
        last.status == "ok" -> :ok
        true -> {:alarm, last.status}
      end

    socket =
      assign(socket,
        status: status,
        last: last,
        history: history,
        pid: pid,
        cal: "1.0",
        log: [{now(), "console connected"}]
      )

    {:ok, socket}
  end

  @impl true
  def handle_info({:telemetry, sample}, socket) do
    prev = socket.assigns.status
    status = if sample.status == "ok", do: :ok, else: {:alarm, sample.status}

    socket =
      socket
      |> assign(last: sample, status: status)
      |> update(:history, &Enum.take([sample | &1], 90))

    socket =
      cond do
        match?({:alarm, _}, status) and not match?({:alarm, _}, prev) ->
          log(socket, "⚠ alarm raised: #{sample.status} (reading #{fmt(sample.reading)}, #{fmt(sample.temp)} C)")

        status == :ok and match?({:alarm, _}, prev) ->
          log(socket, "✓ alarm cleared, readings nominal")

        true ->
          socket
      end

    {:noreply, socket}
  end

  def handle_info({:status, {:up, pid}}, socket) do
    {:noreply,
     socket
     |> assign(status: :ok, pid: pid)
     |> log("● analyzer online: native QNX pid #{pid} @ RT priority 20")}
  end

  def handle_info({:status, {:down, code, pid}}, socket) do
    {:noreply,
     socket
     |> assign(status: :down, pid: nil)
     |> log("✖ analyzer pid #{pid} terminated (#{exit_desc(code)})")
     |> log("↻ OTP supervisor detected the exit, restarting the analyzer…")}
  end

  def handle_info(_msg, socket), do: {:noreply, socket}

  @impl true
  def handle_event("fault", %{"cmd" => "ok"}, socket) do
    FaultLab.inject("ok")
    {:noreply, log(socket, "→ operator reset faults: ok")}
  end

  def handle_event("fault", %{"cmd" => cmd}, socket) do
    FaultLab.inject(cmd)
    {:noreply, log(socket, "→ operator injected fault: #{cmd}")}
  end

  def handle_event("calibrate", %{"mult" => mult}, socket) do
    {m, _} = Float.parse(mult)
    FaultLab.calibrate(m)
    {:noreply, socket |> assign(cal: mult) |> log("→ calibration deployed live: x#{mult} (no restart)")}
  end

  defp log(socket, msg), do: update(socket, :log, &Enum.take([{now(), msg} | &1], 12))
  defp now, do: Calendar.strftime(DateTime.utc_now(), "%H:%M:%S")
  defp fmt(n), do: :erlang.float_to_binary(n, decimals: 1)

  defp exit_desc(134), do: "SIGABRT, aborted"
  defp exit_desc(139), do: "SIGSEGV, segfault"
  defp exit_desc(code) when code > 128, do: "signal #{code - 128}"
  defp exit_desc(code), do: "exit #{code}"

  defp spark_points(history) do
    pts = Enum.reverse(history)
    n = length(pts)

    if n < 2 do
      ""
    else
      vals = Enum.map(pts, & &1.reading)
      lo = Enum.min(vals)
      span = max(Enum.max(vals) - lo, 0.1)
      w = 600.0
      h = 120.0

      pts
      |> Enum.with_index()
      |> Enum.map_join(" ", fn {s, i} ->
        x = i / (n - 1) * w
        y = h - (s.reading - lo) / span * h
        "#{Float.round(x, 1)},#{Float.round(y, 1)}"
      end)
    end
  end

  defp status_text(:connecting), do: "connecting"
  defp status_text(:ok), do: "nominal"
  defp status_text(:down), do: "offline"
  defp status_text({:alarm, s}), do: "alarm: #{s}"

  defp status_class(:ok), do: "ok"
  defp status_class({:alarm, _}), do: "alarm"
  defp status_class(_), do: "down"

  defp log_text(log), do: Enum.map_join(log, "\n", fn {t, m} -> "#{t}  #{m}" end)

  defp cal_class(cal, value), do: if(cal == value, do: "active", else: "")

  @impl true
  def render(assigns) do
    ~H"""
    <h1>QNX Lab <span class="arrow">·</span> Operations Console</h1>
    <p class="sub">A simulated analyzer running on QNX 8.0, supervised by Erlang/OTP, operated over Phoenix LiveView</p>

    <div class="panel">
      <div class="statusrow">
        <span class={"light " <> status_class(@status)}></span>
        <span class="statustext"><%= status_text(@status) %></span>
        <span class="pidtag"><%= if @pid, do: "native QNX pid #{@pid} · RT prio 20", else: "no process" %></span>
      </div>
      <div class="readings">
        <div class="reading">
          <div class="rv"><%= if @last, do: fmt(@last.reading), else: "--" %></div>
          <div class="rl">reading</div>
        </div>
        <div class="reading">
          <div class="rv"><%= if @last, do: fmt(@last.temp), else: "--" %><span class="u">°C</span></div>
          <div class="rl">temperature</div>
        </div>
        <div class="reading">
          <div class="rv"><%= if @last, do: fmt(@last.pressure), else: "--" %><span class="u">kPa</span></div>
          <div class="rl">pressure</div>
        </div>
      </div>
      <svg class="spark" viewBox="0 0 600 120" preserveAspectRatio="none">
        <polyline points={spark_points(@history)} fill="none" stroke="#e5342b" stroke-width="2" />
      </svg>
    </div>

    <div class="panel">
      <h2>Fault lab</h2>
      <div class="ctrl">
        <span class="clabel">inject fault</span>
        <span class="btns">
          <button phx-click="fault" phx-value-cmd="overheat">overheat</button>
          <button phx-click="fault" phx-value-cmd="stuck">stuck sensor</button>
          <button class="danger" phx-click="fault" phx-value-cmd="crash">crash</button>
        </span>
      </div>
      <div class="ctrl">
        <span class="clabel">recover</span>
        <span class="btns">
          <button phx-click="fault" phx-value-cmd="ok">clear fault</button>
        </span>
      </div>
      <div class="ctrl">
        <span class="clabel">calibration factor</span>
        <span class="btns">
          <span class={cal_class(@cal, "0.85")}><button phx-click="calibrate" phx-value-mult="0.85">x0.85</button></span>
          <span class={cal_class(@cal, "1.0")}><button phx-click="calibrate" phx-value-mult="1.0">x1.0</button></span>
          <span class={cal_class(@cal, "1.15")}><button phx-click="calibrate" phx-value-mult="1.15">x1.15</button></span>
        </span>
      </div>
    </div>

    <div class="panel">
      <h2>Event log</h2>
      <pre><%= log_text(@log) %></pre>
    </div>

    <p class="sub">The sampling loop is a native C process scheduled by QNX at a real-time priority. OTP supervises it; the BEAM does not run the real-time loop itself.</p>
    """
  end
end
