defmodule Webdemo.ConsoleLiveTest do
  use ExUnit.Case, async: false

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  @endpoint Webdemo.Endpoint

  test "the selected calibration is marked active" do
    {:ok, view, html} = live(build_conn(), "/")

    assert html =~ ~s(<span class="active"><button phx-click="calibrate" phx-value-mult="1.0">)

    html =
      view
      |> element(~s(button[phx-value-mult="1.15"]))
      |> render_click()

    assert html =~ ~s(<span class="active"><button phx-click="calibrate" phx-value-mult="1.15">)
    refute html =~ ~s(<span class="active"><button phx-click="calibrate" phx-value-mult="1.0">)
  end
end
