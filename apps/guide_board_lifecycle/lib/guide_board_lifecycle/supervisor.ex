defmodule GuideBoardLifecycle.Supervisor do
  # Supervises this CMD department's own processes: the mesh-facing PMs
  # that react to this app's own domain events by publishing to the mesh
  # (mirrors mcl-tube's guide_tube_lifecycle_sup). The write-relays' inbound
  # subscribers (Answer*Requests) are not children here: mcl_om supervises
  # every mesh subscription this service declares, see
  # MclWhiteboard.Service.subscriptions/0. No aggregate children here: evoq's own aggregate
  # registry starts BoardAggregate processes on demand, keyed by stream
  # id, the first time a command dispatches against them.
  @moduledoc false

  use Supervisor

  alias GuideBoardLifecycle.BoardLifecycleV1ToMesh
  alias GuideBoardLifecycle.LeaveBoard.PeerDepartedV1ToMesh
  alias GuideBoardLifecycle.ShapeLifecycle.ShapeLifecycleV1ToMesh

  def start_link, do: Supervisor.start_link(__MODULE__, [], name: __MODULE__)

  @impl true
  def init([]) do
    children = [
      handler(ShapeLifecycleV1ToMesh),
      handler(PeerDepartedV1ToMesh),
      handler(BoardLifecycleV1ToMesh)
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  defp handler(module) do
    %{
      id: module,
      start: {:evoq_event_handler, :start_link, [module, %{}, %{}]},
      restart: :permanent,
      shutdown: 5_000,
      type: :worker,
      modules: [module]
    }
  end
end
