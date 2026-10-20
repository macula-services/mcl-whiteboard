defmodule GuideBoardLifecycle.Application do
  # OTP application entry for the CMD department. Boots as an ordinary
  # sibling OTP app in the release -- the per-store evoq subscription
  # (started by MclWhiteboard.Application before mcl_om:boot/1) is what
  # actually delivers events to whatever this app registers to receive
  # them, not a direct dependency between the two apps.
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args), do: GuideBoardLifecycle.Supervisor.start_link()
end
