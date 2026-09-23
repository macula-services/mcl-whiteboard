defmodule MclWhiteboard.Supervisor do
  # This service's own supervision tree, started by MclWhiteboard.Service
  # after mcl_om has wired mesh/identity/health and (since store_id/0 +
  # data_dir/0 are exported) reckon-db + the evoq subscription.
  #
  # No children: the departments are sibling OTP apps with their own trees,
  # evoq's aggregate registry starts board aggregates on demand, and mcl_om
  # supervises the mesh subscriptions this service declares.
  @moduledoc false

  use Supervisor

  def start_link, do: Supervisor.start_link(__MODULE__, [], name: __MODULE__)

  @impl true
  def init([]), do: Supervisor.init([], strategy: :one_for_one)
end
