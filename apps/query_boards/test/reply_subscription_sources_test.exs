defmodule QueryBoards.ReplySubscriptionSourcesTest do
  # mcl-whiteboard#15, T8: the two mesh queries each open a reply subscription
  # of their own, outside the service's declared list, and macula 18 refuses
  # one that names no source. Each must take only the nodes the realm delegated
  # this service's org, like every other subscription here.
  #
  # The seam is macula_subscriber's own `subscribe` option: the test's function
  # receives the options exactly as the subscriber would hand them to
  # macula:subscribe/5, so a change at either call site is seen here.
  use ExUnit.Case, async: false

  alias QueryBoards.GetBoardSnapshotByIdOverMesh.GetBoardSnapshotByIdOverMesh
  alias QueryBoards.ListBoardsOverMesh.ListBoardsOverMesh

  @realm "realm-for-a-test"
  @no_wait_ms 10

  defp recording_subscribe(test) do
    fn _pool, _realm, topic, _subscriber, opts ->
      send(test, {:subscribed, topic, opts})
      {:ok, make_ref()}
    end
  end

  defp org_nodes, do: {:org, Application.fetch_env!(:mcl_om, :org)}

  test "the board-list query's reply subscription takes only the org's nodes" do
    ListBoardsOverMesh.query(self(), @realm, @no_wait_ms, %{
      subscribe: recording_subscribe(self())
    })

    assert_received {:subscribed, _topic, opts}
    assert Map.fetch(opts, :sources) == {:ok, org_nodes()}
  end

  test "the board-snapshot query's reply subscription takes only the org's nodes" do
    GetBoardSnapshotByIdOverMesh.query(self(), @realm, "a-board", @no_wait_ms, %{
      subscribe: recording_subscribe(self())
    })

    assert_received {:subscribed, _topic, opts}
    assert Map.fetch(opts, :sources) == {:ok, org_nodes()}
  end

  test "nothing a caller passes can replace the source" do
    ListBoardsOverMesh.query(self(), @realm, @no_wait_ms, %{
      subscribe: recording_subscribe(self()),
      sources: :members
    })

    assert_received {:subscribed, _topic, opts}
    assert Map.fetch(opts, :sources) == {:ok, org_nodes()}
  end
end
