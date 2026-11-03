defmodule Webdemo.FaultLab do
  @moduledoc """
  Deterministically inject/clear faults and push calibration to the native
  analyzer by writing the control files it reads each tick. The analyzer is the
  real-time task; this just signals it.
  """

  @commands ~w(ok overheat stuck crash)

  @spec inject(String.t()) :: :ok
  def inject(cmd) when cmd in @commands do
    write(cmd_path(), cmd)
  end

  @spec reset() :: :ok
  def reset, do: write(cmd_path(), "ok")

  @spec calibrate(number()) :: :ok
  def calibrate(mult), do: write(cal_path(), to_string(mult))

  defp write(path, contents) do
    File.mkdir_p(Path.dirname(path))
    _ = File.write(path, contents)
    # The control files are the analyzer's operator control plane; make them
    # writable so the console (and an operator) can drive the fault lab.
    _ = File.chmod(path, 0o666)
    :ok
  end

  defp dir, do: System.get_env("ANALYZER_CTRL", "/data/var")
  defp cmd_path, do: Path.join(dir(), "analyzer.cmd")
  defp cal_path, do: Path.join(dir(), "analyzer.cal")
end
