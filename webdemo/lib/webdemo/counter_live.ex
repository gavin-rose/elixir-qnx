defmodule Webdemo.CounterLive do
  use Phoenix.LiveView

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: :timer.send_interval(1000, self(), :tick)

    socket =
      assign(socket,
        count: 0,
        arch: List.to_string(:erlang.system_info(:system_architecture)),
        os: inspect(:os.type()),
        otp: List.to_string(:erlang.system_info(:otp_release)),
        elixir: System.version()
      )

    {:ok, socket}
  end

  @impl true
  def handle_info(:tick, socket), do: {:noreply, update(socket, :count, &(&1 + 1))}

  @impl true
  def handle_event("inc", _params, socket), do: {:noreply, update(socket, :count, &(&1 + 1))}

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
    </div>
    """
  end
end
