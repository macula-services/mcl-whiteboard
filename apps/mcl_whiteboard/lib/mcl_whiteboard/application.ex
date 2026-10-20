defmodule MclWhiteboard.Application do
  # OTP application entry. THIS SERVICE OPENS ITS OWN STORE FIRST
  # (MclWhiteboard.EventStore, from MclWhiteboard.Service.event_store/0), then
  # lets mcl_om:boot/1 wire the mesh, the realm identity, health and the
  # service's standing subscriptions and start the service. mcl_om opens no
  # store since 0.35.0 (mcl-om#10): the old store_id/0 + data_dir/0 contract
  # boots with no store at all, and every board is lost at its first touch.
  #
  # The departments are runtime deps of this app, so their projections and
  # event handlers are registered before the store subscription delivers.
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    :ok = MclWhiteboard.EventStore.open(MclWhiteboard.Service.event_store())
    :mcl_om.boot(MclWhiteboard.Service)
  end
end
