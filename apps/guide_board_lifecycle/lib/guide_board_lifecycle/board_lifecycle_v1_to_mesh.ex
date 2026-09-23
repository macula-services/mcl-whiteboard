defmodule GuideBoardLifecycle.BoardLifecycleV1ToMesh do
  # Republishes every LOCALLY-originated board_initiated_v1/
  # board_hosted_v1/board_archived_v1/board_unarchived_v1/board_renamed_v1
  # as a mesh fact, so
  # the board picker (MclWhiteboardWeb.BoardsLive, "on other nodes")
  # updates live instead of only ever reflecting whatever a one-shot
  # mesh query saw at page load.
  #
  # One topic PER event type, named after the event -- matches
  # StrokeDrawnV1ToMesh's own precedent, not ShapeMutatedV1ToMesh's
  # shared-topic one. Those five shape events are genuine variations of
  # one concern ("what's drawn on this board changed"); these four are
  # not -- "created", "became permanently read-only", and "renamed" are
  # distinct kinds of news a future consumer may well want to subscribe
  # to selectively, not a family worth forcing through one filter.
  #
  # Deliberately does NOT change how board creation itself works --
  # MclWhiteboardWeb.BoardsLive's create_board/1 still dispatches
  # initiate_board and host_board back-to-back, synchronously, same as
  # before. The two facts this produces just happen to land on the mesh
  # a few milliseconds apart -- true, honest eventual consistency, not
  # a new deferred-hosting mechanic. A remote peer that happens to catch
  # a board between the two (initiated, not yet hosted) sees exactly
  # that: see BoardsLive's own comment on why an initiated-not-hosted
  # remote board renders as a badge, not a link.
  @behaviour :evoq_event_handler

  alias GuideBoardLifecycle.WhiteboardTopic

  @event_types ~w(board_initiated_v1 board_hosted_v1 board_archived_v1 board_unarchived_v1 board_renamed_v1)

  def topic(event_type) when event_type in @event_types,
    do: WhiteboardTopic.build("board", String.replace_suffix(event_type, "_v1", ""))

  def topics, do: Enum.map(@event_types, &topic/1)

  @impl true
  def interested_in, do: @event_types

  # A replayed lifecycle event is news peers already had; republishing the
  # store's whole history on every restart would be noise at best.
  @impl true
  def replay_policy, do: :skip

  @impl true
  def init(_config), do: {:ok, %{}}

  @impl true
  def handle_event(event_type, event, _metadata, state) do
    data = field(:data, event)

    fact = %{
      board_id: field(:board_id, data),
      # Only board_initiated_v1 carries owner, only board_initiated_v1/
      # board_renamed_v1 carry title -- nil on every other event type,
      # which the receiving side treats as "no update" rather than
      # "clear this field". See MclWhiteboardWeb.BoardsLive's own
      # accumulation logic.
      title: field(:title, data),
      owner: field(:owner, data),
      host: host_label()
    }

    publish(event_type, fact)
    {:ok, state}
  end

  # A refused publish is logged by mcl_om (async_log); a dark mesh drops the
  # fact, and peers catch up through ListBoardsOverMesh on their next page
  # load.
  defp publish(event_type, fact) do
    _ = :mcl_om_pubsub.publish(topic(event_type), fact, %{mode: :async_log})
    :ok
  end

  # Same host-name derivation as MclWhiteboardWeb.BoardLive/
  # QueryBoards.AnswerBoardListQueries's own host_label -- duplicated
  # rather than shared, matching this workspace's existing convention
  # for this exact helper.
  defp host_label do
    case Node.self() do
      :nonode@nohost -> "local"
      node -> node |> Atom.to_string() |> String.split("@") |> List.last()
    end
  end

  defp field(key, map) when is_atom(key) do
    Map.get(map, key, Map.get(map, Atom.to_string(key)))
  end
end
