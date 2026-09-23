defmodule QueryBoards.AnswerBoardListQueries do
  # Host half of the mesh-aware board picker: every node on the mesh is
  # permanently subscribed to this fixed query topic. Unlike
  # AnswerBoardSnapshotQueries (join_board's responder, gated on "do I
  # actually host this ONE board_id"), there is no authority question
  # here -- "what do I host" is always a safe, truthful answer, so every
  # node with at least one hosted board replies. A query for a specific
  # board expects exactly one authoritative answer; a query for "what
  # exists" expects an answer from everyone who has something to say, so
  # the client (ListBoardsOverMesh) collects for a fixed window instead
  # of stopping at the first reply.
  @behaviour :macula_subscriber

  alias QueryBoards.ListHostedBoards.ListHostedBoards

  alias GuideBoardLifecycle.WhiteboardTopic

  def topic, do: WhiteboardTopic.build("query", "board_list_query")
  def reply_topic, do: WhiteboardTopic.build("query", "board_list_reply")

  @impl true
  def init(_args), do: {:ok, nil}

  @impl true
  def handle_event(topic, payload, _meta, state) do
    if topic == topic() do
      fact = normalize(payload)
      reply(field(:request_id, fact))
    end

    {:noreply, state}
  end

  # Every reply goes to the one fixed reply topic, carrying the asker's
  # request_id so the asker can pick its own out. A node hosting nothing
  # stays silent.
  defp reply(request_id) when is_binary(request_id) do
    case ListHostedBoards.call() do
      [] ->
        :ok

      boards ->
        fact = %{
          request_id: request_id,
          host: host_label(),
          boards: Enum.map(boards, &board_fact/1)
        }

        _ = :mcl_om_pubsub.publish(reply_topic(), fact, %{mode: :async_log})
        :ok
    end
  end

  defp reply(_request_id), do: :ok

  defp board_fact(board) do
    %{
      board_id: board.board_id,
      title: board.title,
      owner: board.owner,
      stroke_count: board.stroke_count
    }
  end

  # Same host-name derivation as MclWhiteboardWeb.BoardLive/
  # GuideBoardLifecycle.BoardAggregate's own host_label -- duplicated
  # rather than shared, matching this module's own convention elsewhere
  # in the app.
  defp host_label do
    case Node.self() do
      :nonode@nohost -> "local"
      node -> node |> Atom.to_string() |> String.split("@") |> List.last()
    end
  end

  defp field(key, map) when is_atom(key) do
    Map.get(map, key, Map.get(map, Atom.to_string(key)))
  end

  defp normalize({:text, b}) when is_binary(b), do: b
  defp normalize(:undefined), do: nil
  defp normalize(m) when is_map(m), do: Map.new(m, fn {k, v} -> {normalize(k), normalize(v)} end)
  defp normalize(l) when is_list(l), do: Enum.map(l, &normalize/1)
  defp normalize(v), do: v
end
