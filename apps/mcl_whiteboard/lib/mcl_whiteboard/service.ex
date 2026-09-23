defmodule MclWhiteboard.Service do
  # The mcl_om service contract: what this service is and may do.
  #
  # SIX CALLBACKS REQUIRED. mcl_om resolves them by name at startup, on a
  # live node, so a service that forgets one dies with `undef` where nobody
  # is watching. `@behaviour :mcl_om_service` turns that into a compile
  # error instead.
  #
  # IT ANNOUNCES NO CAPABILITY. Everything a peer does with a board goes
  # over pubsub (facts, write relays, and the board list/snapshot queries,
  # which every host must hear, not just one provider), so there is no RPC
  # procedure to advertise.
  @behaviour :mcl_om_service

  alias GuideBoardLifecycle.BoardLifecycleV1ToMesh
  alias GuideBoardLifecycle.DrawStroke.AnswerDrawStrokeRequests
  alias GuideBoardLifecycle.LeaveBoard.AnswerLeaveBoardRequests
  alias GuideBoardLifecycle.LeaveBoard.PeerDepartedV1ToMesh
  alias GuideBoardLifecycle.ShapeLifecycle.ShapeLifecycleV1ToMesh
  alias GuideBoardLifecycle.ShapeMutation.AnswerShapeMutationRequests
  alias ProjectBoards.BoardLifecycleMeshSubscriber
  alias ProjectBoards.ShapeLifecycleMeshSubscriber
  alias QueryBoards.AnswerBoardListQueries
  alias QueryBoards.AnswerBoardSnapshotQueries
  alias TrackPresence.CursorMeshSubscriber
  alias TrackPresence.PeerDepartedMeshSubscriber

  @impl true
  def info do
    %{
      name: "mcl-whiteboard",
      version: version(),
      description:
        "Real-time multi-user whiteboard over mesh -- host a board on your own node, no central server"
    }
  end

  @impl true
  def start(_opts), do: MclWhiteboard.Supervisor.start_link()

  @impl true
  def stop(_state), do: :ok

  # Green once the supervision tree is up. A dark mesh is not a health
  # failure: a host keeps serving its own boards to local viewers.
  @impl true
  def health, do: :ok

  @impl true
  def capabilities, do: []

  # The namespace every topic of this service hangs under (org
  # mcl-whiteboard); nothing more is asked for.
  @impl true
  def identity_spec do
    %{scope: "mcl-whiteboard", actions: [], resources: [], ttl_days: 30}
  end

  # EVERY standing mesh subscription of this service, in one list:
  # mcl_om:boot/1 hands it to mcl_om_pubsub:ensure_subscriptions/1, which
  # takes the whole desired set, starts each subscriber once the mesh is
  # attached and re-reconciles every 30 s (covering a full pool
  # replacement). The departments are runtime deps of this app, so every
  # handler named here is running before boot declares it. One
  # {topic, handler, args} per topic; each topic comes from the module that
  # owns it.
  @impl true
  def subscriptions do
    for(t <- BoardLifecycleV1ToMesh.topics(), do: {t, BoardLifecycleMeshSubscriber, []}) ++
      for(t <- ShapeLifecycleV1ToMesh.topics(), do: {t, ShapeLifecycleMeshSubscriber, []}) ++
      [
        {AnswerDrawStrokeRequests.topic(), AnswerDrawStrokeRequests, []},
        {AnswerShapeMutationRequests.topic(), AnswerShapeMutationRequests, []},
        {AnswerLeaveBoardRequests.topic(), AnswerLeaveBoardRequests, []},
        {AnswerBoardListQueries.topic(), AnswerBoardListQueries, []},
        {AnswerBoardSnapshotQueries.topic(), AnswerBoardSnapshotQueries, []},
        {CursorMeshSubscriber.topic(), CursorMeshSubscriber, []},
        {PeerDepartedV1ToMesh.topic(), PeerDepartedMeshSubscriber, []}
      ]
  end

  # CMD/PRJ wiring: exporting both callbacks makes mcl_om:boot/1 start
  # reckon-db + the evoq subscription before start/1 runs. Requires the
  # evoq adapter block in config/runtime.exs, or evoq dispatch crashes on
  # {not_configured, event_store_adapter}.
  @impl true
  def store_id, do: :board_store

  # Same env var and same default as config/runtime.exs -- two independent
  # reads of MCL_DATA_DIR, so they must agree.
  #
  # MUST be a charlist, not an Elixir binary. The behaviour's -callback
  # spec says string() -- Erlang's string() means [char()], not binary().
  # An Elixir binary here survives filename:join/2 but then crashes deep
  # inside ra's directory setup with dets:open_file/2 {badarg, ...} on the
  # `file` option, since dets rejects a binary path outright.
  @impl true
  def data_dir,
    do: String.to_charlist(System.get_env("MCL_DATA_DIR", "/tmp/mcl-whiteboard-dev"))

  defp version do
    {:ok, vsn} = :application.get_key(:mcl_whiteboard, :vsn)
    to_string(vsn)
  end
end
