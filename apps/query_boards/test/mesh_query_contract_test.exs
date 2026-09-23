defmodule QueryBoards.MeshQueryContractTest do
  # The query/reply wire contract this app owns, as literal strings. IDs ride
  # in the payload, never in the topic: each query has ONE fixed reply topic,
  # and the asker picks its own replies out by request_id.
  use ExUnit.Case, async: true

  alias QueryBoards.AnswerBoardListQueries
  alias QueryBoards.AnswerBoardSnapshotQueries
  alias QueryBoards.ManyShotMeshReply
  alias QueryBoards.OneShotMeshReply

  @prefix "io.macula/mcl-whiteboard/whiteboard/query/"

  test "board list query and its reply" do
    assert AnswerBoardListQueries.topic() == @prefix <> "board_list_query_v1"
    assert AnswerBoardListQueries.reply_topic() == @prefix <> "board_list_reply_v1"
  end

  test "board snapshot query and its reply" do
    assert AnswerBoardSnapshotQueries.topic() == @prefix <> "board_snapshot_query_v1"
    assert AnswerBoardSnapshotQueries.reply_topic() == @prefix <> "board_snapshot_reply_v1"
  end

  test "every topic passes macula's own validator" do
    topics = [
      AnswerBoardListQueries.topic(),
      AnswerBoardListQueries.reply_topic(),
      AnswerBoardSnapshotQueries.topic(),
      AnswerBoardSnapshotQueries.reply_topic()
    ]

    assert Enum.all?(topics, &(:macula_topic.validate(&1) == :ok)), inspect(topics)
  end

  describe "a one-shot reply" do
    test "is forwarded to its asker, which it then leaves" do
      {:ok, state} = OneShotMeshReply.init({self(), "req-1"})
      reply = %{"request_id" => {:text, "req-1"}, "board_id" => "b"}

      assert {:stop, :normal, _} = OneShotMeshReply.handle_event("t", reply, %{}, state)
      assert_received {:one_shot_mesh_reply, ^reply}
    end

    test "for someone else's request is ignored, and it keeps waiting" do
      {:ok, state} = OneShotMeshReply.init({self(), "req-1"})

      assert {:noreply, ^state} =
               OneShotMeshReply.handle_event("t", %{request_id: "req-2"}, %{}, state)

      refute_received {:one_shot_mesh_reply, _}
    end
  end

  describe "a many-shot reply" do
    test "forwards every reply to its own request and none to another" do
      {:ok, state} = ManyShotMeshReply.init({self(), "req-1"})

      assert {:noreply, ^state} =
               ManyShotMeshReply.handle_event("t", %{request_id: "req-1", host: "a"}, %{}, state)

      assert {:noreply, ^state} =
               ManyShotMeshReply.handle_event("t", %{request_id: "req-2", host: "b"}, %{}, state)

      assert_received {:mesh_reply, %{host: "a"}}
      refute_received {:mesh_reply, %{host: "b"}}
    end
  end
end
