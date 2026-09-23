defmodule MclWhiteboard.ServiceTest do
  use ExUnit.Case, async: true

  alias MclWhiteboard.Service

  @departments [:guide_board_lifecycle, :project_boards, :query_boards, :track_presence]

  describe "the mesh subscriptions this service declares" do
    test "name every topic a peer publishes to, each once, with its handler" do
      assert Enum.sort(for {topic, mod, []} <- Service.subscriptions(), do: {topic, mod}) ==
               Enum.sort(
                 for(
                   t <- GuideBoardLifecycle.BoardLifecycleV1ToMesh.topics(),
                   do: {t, ProjectBoards.BoardLifecycleMeshSubscriber}
                 ) ++
                   for(
                     t <- GuideBoardLifecycle.ShapeLifecycle.ShapeLifecycleV1ToMesh.topics(),
                     do: {t, ProjectBoards.ShapeLifecycleMeshSubscriber}
                   ) ++
                   [
                     {GuideBoardLifecycle.DrawStroke.AnswerDrawStrokeRequests.topic(),
                      GuideBoardLifecycle.DrawStroke.AnswerDrawStrokeRequests},
                     {GuideBoardLifecycle.ShapeMutation.AnswerShapeMutationRequests.topic(),
                      GuideBoardLifecycle.ShapeMutation.AnswerShapeMutationRequests},
                     {GuideBoardLifecycle.LeaveBoard.AnswerLeaveBoardRequests.topic(),
                      GuideBoardLifecycle.LeaveBoard.AnswerLeaveBoardRequests},
                     {QueryBoards.AnswerBoardListQueries.topic(),
                      QueryBoards.AnswerBoardListQueries},
                     {QueryBoards.AnswerBoardSnapshotQueries.topic(),
                      QueryBoards.AnswerBoardSnapshotQueries},
                     {TrackPresence.Roster.topic(), TrackPresence.CursorMeshSubscriber},
                     {GuideBoardLifecycle.LeaveBoard.PeerDepartedV1ToMesh.topic(),
                      TrackPresence.PeerDepartedMeshSubscriber}
                   ]
               )
    end

    # mcl_om keys one supervised subscriber per topic; a duplicate would
    # silently drop one of the two handlers.
    test "never name a topic twice" do
      topics = for {topic, _mod, _args} <- Service.subscriptions(), do: topic
      assert topics == Enum.uniq(topics)
    end

    test "only hand events to modules that can take them" do
      for {_topic, mod, _args} <- Service.subscriptions() do
        assert Code.ensure_loaded?(mod) and function_exported?(mod, :handle_event, 4),
               inspect(mod)
      end
    end
  end

  # evoq 1.24 hands every handler the store's whole history again on boot.
  # A handler that does not say what to do with it republishes or re-sends
  # everything it ever did, on every restart.
  test "every evoq event handler in the service declares a replay policy" do
    handlers =
      for app <- @departments,
          {:ok, mods} = :application.get_key(app, :modules),
          mod <- mods,
          Code.ensure_loaded?(mod),
          :evoq_event_handler in behaviours(mod),
          do: mod

    assert handlers != []

    for mod <- handlers do
      assert function_exported?(mod, :replay_policy, 0),
             "#{inspect(mod)} declares no replay_policy/0"

      assert mod.replay_policy() in [:skip, :deliver]
    end
  end

  test "the pool's realm is the realm the topics name" do
    name = Application.fetch_env!(:mcl_whiteboard, :realm_name)
    tag = :crypto.hash(:sha256, name) |> Base.encode16(case: :lower)
    assert Application.fetch_env!(:mcl_om, :realm) == tag
  end

  test "it reports its own application version and the names it answers to" do
    {:ok, vsn} = :application.get_key(:mcl_whiteboard, :vsn)
    info = Service.info()

    assert info.version == to_string(vsn)
    assert info.name == "mcl-whiteboard"
    assert Application.fetch_env!(:mcl_om, :org) == info.name
  end

  test "it asks for authority in its own namespace and nothing more" do
    assert %{scope: "mcl-whiteboard"} = Service.identity_spec()
  end

  defp behaviours(mod) do
    mod.module_info(:attributes) |> Keyword.get_values(:behaviour) |> List.flatten()
  end
end
