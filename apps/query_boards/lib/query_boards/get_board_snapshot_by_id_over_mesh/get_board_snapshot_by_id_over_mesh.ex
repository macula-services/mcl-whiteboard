defmodule QueryBoards.GetBoardSnapshotByIdOverMesh.GetBoardSnapshotByIdOverMesh do
  # Client half of join_board's mesh-level discovery: this node doesn't
  # host board_id locally (GetBoardSnapshotById returned :not_found), so
  # ask the mesh who does. Subscribes to the fixed snapshot reply topic
  # FIRST (so a fast responder can't answer before we're listening), then
  # publishes a query carrying a fresh request_id, then waits for the reply
  # that echoes it. Whichever host actually
  # hosts board_id answers on AnswerBoardSnapshotQueries's own subscriber
  # (see that module) with the snapshot itself -- one round trip, no
  # separate "who hosts this" step followed by a second RPC, since the
  # answer already carries everything a join needs.
  #
  # The reply subscription is per call (QueryBoards.OneShotMeshReply on a
  # :macula_subscriber), so it is started here on the service's own pool
  # rather than declared with the service's standing subscriptions; the
  # query goes out through mcl_om_pubsub like every other publish here.
  #
  # A successful reply is materialized into project_boards' own ETS
  # tables before returning, through the SAME Store.new_shape?/1 dedup
  # gate the local projection and the mesh subscribers use -- so BoardLive
  # can call this exactly like GetBoardSnapshotById and get the identical
  # shape back, and a page reload after a join reads locally with no
  # repeat mesh round trip.
  alias GuideBoardLifecycle.BoardStatus
  alias ProjectBoards.Store
  alias QueryBoards.AnswerBoardSnapshotQueries
  alias QueryBoards.GetBoardSnapshotById.GetBoardSnapshotById
  alias QueryBoards.MeshReplyId

  @default_timeout_ms 3_000

  def call(board_id, timeout_ms \\ @default_timeout_ms) do
    case :mcl_om.mesh_handles() do
      {:ok, pool, realm} -> query(pool, realm, board_id, timeout_ms)
      other -> {:error, {:mesh_unavailable, other}}
    end
  end

  defp query(pool, realm, board_id, timeout_ms) do
    request_id = MeshReplyId.mint()

    case :macula_subscriber.start_link(
           QueryBoards.OneShotMeshReply,
           pool,
           realm,
           AnswerBoardSnapshotQueries.reply_topic(),
           {self(), request_id}
         ) do
      {:ok, subscriber} ->
        publish_query(board_id, request_id)
        await_reply(subscriber, timeout_ms)

      {:error, reason} ->
        {:error, {:reply_subscribe_failed, reason}}
    end
  end

  defp publish_query(board_id, request_id) do
    fact = %{board_id: board_id, request_id: request_id}
    _ = :mcl_om_pubsub.publish(AnswerBoardSnapshotQueries.topic(), fact, %{mode: :async_log})
    :ok
  end

  defp await_reply(subscriber, timeout_ms) do
    receive do
      {:one_shot_mesh_reply, payload} -> materialize(normalize(payload))
    after
      timeout_ms ->
        if Process.alive?(subscriber), do: GenServer.stop(subscriber)
        {:error, :no_host_found}
    end
  end

  defp materialize(fact) do
    board_id = field(:board_id, fact)

    board = %{
      board_id: board_id,
      owner: field(:owner, fact),
      title: field(:title, fact),
      # Deliberately NOT the host's own status bits -- this node is not
      # the aggregate authority for board_id, so `hosted` must read false
      # here regardless of what the real host's status says.
      # BoardLive's existing can_draw? = hosted? and not archived? then
      # makes a joined board correctly read-only with no template change.
      status: BoardStatus.initiated()
    }

    :ets.insert(Store.boards_table(), {board_id, board})

    (field(:shapes, fact) || [])
    |> Enum.map(&normalize_shape/1)
    |> Enum.filter(&Store.new_shape?(&1.shape_id))
    |> Enum.each(&:ets.insert(Store.board_shapes_table(), {board_id, &1}))

    Store.note_shape_version(board_id, field(:as_of_version, fact) || 0)

    # Read back through the same desk the local-host mount path uses, so
    # both of BoardLive's mount branches return an identical shape.
    GetBoardSnapshotById.call(board_id)
  end

  # A snapshot's `shapes` list is every kind (stroke/sticky/text/
  # rectangle/ellipse/triangle) mixed together -- this used to be
  # normalize_stroke/1, extracting only stroke_id/points/color/width, from
  # back when join_board predated any non-stroke shape. Left unfixed,
  # every non-stroke shape came out with kind, shape_id, and text silently
  # dropped (replaced by a stroke_id that never existed for it, always
  # nil), AND all but the FIRST such shape in the list vanished outright:
  # new_shape?(nil) is only true once, so every non-stroke shape after the
  # first collided on the same nil key and got filtered out as an
  # apparent "redelivery". Found live: msi00's join snapshot of a board
  # with a rectangle and four stickies came back with the rectangle
  # missing entirely and only one corrupted, textless sticky surviving.
  #
  # No `stroke_id` fallback anymore -- shape_initiated_v1 never produces
  # one (confirmed by grep: nothing downstream ever read it as distinct
  # from shape_id), so a bare `field(:shape_id, shape)` is now sufficient.
  #
  # Exported for testing only -- pure, no store or mesh needed.
  def normalize_shape(shape) do
    %{
      kind: field(:kind, shape),
      shape_id: field(:shape_id, shape),
      points: field(:points, shape),
      color: field(:color, shape),
      width: field(:width, shape),
      text: field(:text, shape),
      from_shape_id: field(:from_shape_id, shape),
      to_shape_id: field(:to_shape_id, shape)
    }
  end

  # Same atom/{text,_} tolerance as every other mesh-facing module here --
  # see ShapeLifecycleMeshSubscriber's header comment for the full explanation.
  defp field(key, map) when is_atom(key) do
    Map.get(map, key, Map.get(map, Atom.to_string(key)))
  end

  defp normalize({:text, b}) when is_binary(b), do: b
  defp normalize(:undefined), do: nil
  defp normalize(m) when is_map(m), do: Map.new(m, fn {k, v} -> {normalize(k), normalize(v)} end)
  defp normalize(l) when is_list(l), do: Enum.map(l, &normalize/1)
  defp normalize(v), do: v
end
