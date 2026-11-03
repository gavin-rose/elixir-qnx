defmodule Webdemo.ConsoleLive do
  use Phoenix.LiveView

  alias Webdemo.{Analyzer, FaultLab}

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Phoenix.PubSub.subscribe(Webdemo.PubSub, Analyzer.topic())

    {last, history} = Analyzer.latest()

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
        cal: 1.0,
        log: [{now(), "console connected"}]
      )

    {:ok, socket}
  end

  @impl true
  def handle_info({:telemetry, sample}, socket) do
    status = if sample.status == "ok", do: :ok, else: {:alarm, sample.status}

    {:noreply,
     socket
     |> assign(last: sample, status: status)
     |> update(:history, &Enum.take([sample | &1], 90))}
  end

  def handle_info({:status, :up}, socket) do
    {:noreply, socket |> assign(status: :ok) |> log("analyzer up (native QNX process, RT priority)")}
  end

  def handle_info({:status, {:down, code}}, socket) do
    {:noreply, socket |> assign(status: :down) |> log("analyzer DOWN (exit #{code}); OTP supervisor restarting")}
  end

  def handle_info(_msg, socket), do: {:noreply, socket}

  @impl true
  def handle_event("fault", %{"cmd" => cmd}, socket) do
    FaultLab.inject(cmd)
    {:noreply, log(socket, "fault injected: #{cmd}")}
  end

  def handle_event("calibrate", %{"mult" => mult}, socket) do
    {m, _} = Float.parse(mult)
    FaultLab.calibrate(m)
    {:noreply, socket |> assign(cal: m) |> log("calibration deployed: x#{mult} (live, no restart)")}
  end

  defp log(socket, msg), do: update(socket, :log, &Enum.take([{now(), msg} | &1], 8))
  defp now, do: Calendar.strftime(DateTime.utc_now(), "%H:%M:%S")

  # Build an SVG polyline of the recent readings (history is newest-first).
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
  defp status_class(:down), do: "down"
  defp status_class({:alarm, _}), do: "alarm"
  defp status_class(_), do: "down"

  defp log_text(log), do: Enum.map_join(log, "\n", fn {t, m} -> "#{t}  #{m}" end)

  @impl true
  def render(assigns) do
    ~H"""
    <h1>QNX Lab <span class="arrow">·</span> Operations Console</h1>
    <p class="sub">A simulated analyzer running on QNX 8.0, supervised by Erlang/OTP, operated over Phoenix LiveView</p>

    <div class="panel">
      <h2>Analyzer</h2>
      <div class="statusrow">
        <span class={"light " <> status_class(@status)}></span>
        <span class="statustext"><%= status_text(@status) %></span>
      </div>
      <div class="readings">
        <div class="reading">
          <div class="rv"><%= if @last, do: :erlang.float_to_binary(@last.reading, decimals: 1), else: "--" %></div>
          <div class="rl">reading</div>
        </div>
        <div class="reading">
          <div class="rv"><%= if @last, do: :erlang.float_to_binary(@last.temp, decimals: 1), else: "--" %><span class="u">°C</span></div>
          <div class="rl">temperature</div>
        </div>
        <div class="reading">
          <div class="rv"><%= if @last, do: :erlang.float_to_binary(@last.pressure, decimals: 1), else: "--" %><span class="u">kPa</span></div>
          <div class="rl">pressure</div>
        </div>
      </div>
      <svg class="spark" viewBox="0 0 600 120" preserveAspectRatio="none">
        <polyline points={spark_points(@history)} fill="none" stroke="#e5342b" stroke-width="2" />
      </svg>
    </div>

    <div class="panel">
      <h2>Fault lab</h2>
      <div class="row">
        <span class="lab">inject</span>
        <button phx-click="fault" phx-value-cmd="overheat">overheat</button>
        <button phx-click="fault" phx-value-cmd="stuck">stuck sensor</button>
        <button class="primary" phx-click="fault" phx-value-cmd="crash">crash (watch OTP recover)</button>
        <button phx-click="fault" phx-value-cmd="ok">clear</button>
      </div>
      <div class="row">
        <span class="lab">calibration update</span>
        <button phx-click="calibrate" phx-value-mult="1.0">x1.0</button>
        <button phx-click="calibrate" phx-value-mult="1.15">x1.15</button>
        <button phx-click="calibrate" phx-value-mult="0.85">x0.85</button>
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
