defmodule MclWhiteboard.Application do
  # mcl_om:boot/1 wires the mesh, the realm identity and health, then
  # starts this service. MclWhiteboard.Service exports store_id/0 +
  # data_dir/0, so mcl_om:boot/1 also starts reckon-db and this store's
  # evoq subscription BEFORE MclWhiteboard.Service.start/1 fires -- see
  # that module's own docs.
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args), do: :mcl_om.boot(MclWhiteboard.Service)
end
