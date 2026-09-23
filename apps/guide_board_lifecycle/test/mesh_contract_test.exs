defmodule GuideBoardLifecycle.MeshContractTest do
  # The wire contract this app owns: every topic it publishes or answers on,
  # as the literal string a peer on another node must use. Asserted as
  # literals on purpose; a test that rebuilt them with WhiteboardTopic would
  # pass whatever the builder did. Realm and org are config/runtime.exs's own
  # defaults (io.macula, mcl-whiteboard).
  use ExUnit.Case, async: true

  alias GuideBoardLifecycle.BoardLifecycleV1ToMesh
  alias GuideBoardLifecycle.DrawStroke.AnswerDrawStrokeRequests
  alias GuideBoardLifecycle.LeaveBoard.AnswerLeaveBoardRequests
  alias GuideBoardLifecycle.LeaveBoard.PeerDepartedV1ToMesh
  alias GuideBoardLifecycle.ShapeLifecycle.ShapeLifecycleV1ToMesh
  alias GuideBoardLifecycle.ShapeMutation.AnswerShapeMutationRequests

  @prefix "io.macula/mcl-whiteboard/whiteboard/"

  test "board lifecycle facts, one topic per event type" do
    assert BoardLifecycleV1ToMesh.topics() ==
             [
               @prefix <> "board/board_initiated_v1",
               @prefix <> "board/board_hosted_v1",
               @prefix <> "board/board_archived_v1",
               @prefix <> "board/board_unarchived_v1",
               @prefix <> "board/board_renamed_v1"
             ]

    assert BoardLifecycleV1ToMesh.topic("board_renamed_v1") ==
             @prefix <> "board/board_renamed_v1"
  end

  test "shape lifecycle facts" do
    assert ShapeLifecycleV1ToMesh.topics() ==
             [
               @prefix <> "shape/shape_initiated_v1",
               @prefix <> "shape/shape_amended_v1",
               @prefix <> "shape/shape_removed_v1"
             ]
  end

  test "presence facts and requests" do
    assert PeerDepartedV1ToMesh.topic() == @prefix <> "presence/peer_departed_v1"
    assert AnswerLeaveBoardRequests.topic() == @prefix <> "presence/leave_board_request_v1"
  end

  test "write relays from joining peers" do
    assert AnswerDrawStrokeRequests.topic() == @prefix <> "shape/draw_stroke_request_v1"

    assert AnswerShapeMutationRequests.topic() ==
             @prefix <> "shape/shape_mutation_request_v1"
  end

  test "every topic passes macula's own validator" do
    topics =
      BoardLifecycleV1ToMesh.topics() ++
        ShapeLifecycleV1ToMesh.topics() ++
        [
          PeerDepartedV1ToMesh.topic(),
          AnswerLeaveBoardRequests.topic(),
          AnswerDrawStrokeRequests.topic(),
          AnswerShapeMutationRequests.topic()
        ]

    assert Enum.all?(topics, &(:macula_topic.validate(&1) == :ok)), inspect(topics)
  end

  # A mesh emitter that took replay would republish the store's whole history
  # to every peer on every restart.
  test "the mesh emitters skip replay" do
    for emitter <- [BoardLifecycleV1ToMesh, ShapeLifecycleV1ToMesh, PeerDepartedV1ToMesh] do
      assert emitter.replay_policy() == :skip, inspect(emitter)
    end
  end

  test "an answerer ignores an event on any other topic" do
    for answerer <- [
          AnswerDrawStrokeRequests,
          AnswerShapeMutationRequests,
          AnswerLeaveBoardRequests
        ] do
      assert answerer.handle_event(@prefix <> "board/board_hosted_v1", %{}, %{}, :st) ==
               {:noreply, :st}
    end
  end
end
