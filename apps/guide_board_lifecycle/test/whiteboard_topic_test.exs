defmodule GuideBoardLifecycle.WhiteboardTopicTest do
  use ExUnit.Case, async: false

  alias GuideBoardLifecycle.WhiteboardTopic

  setup do
    previous_realm = Application.get_env(:mcl_whiteboard, :realm_name)
    previous_org = Application.get_env(:mcl_om, :org)
    Application.put_env(:mcl_whiteboard, :realm_name, "io.macula")
    Application.put_env(:mcl_om, :org, "mcl-whiteboard")

    on_exit(fn ->
      restore(:mcl_whiteboard, :realm_name, previous_realm)
      restore(:mcl_om, :org, previous_org)
    end)
  end

  test "builds the canonical five-segment app-tier topic" do
    assert WhiteboardTopic.build("board", "board_initiated") ==
             "io.macula/mcl-whiteboard/whiteboard/board/board_initiated_v1"
  end

  test "every topic it builds passes macula's own validator" do
    assert :ok == :macula_topic.validate(WhiteboardTopic.build("presence", "cursor_settled"))
  end

  test "the realm and org segments follow the configuration" do
    Application.put_env(:mcl_whiteboard, :realm_name, "org.example")
    Application.put_env(:mcl_om, :org, "acme-board")

    assert WhiteboardTopic.build("shape", "shape_removed") ==
             "org.example/acme-board/whiteboard/shape/shape_removed_v1"
  end

  test "an unconfigured realm name refuses loudly instead of publishing somewhere nobody listens" do
    Application.delete_env(:mcl_whiteboard, :realm_name)

    assert_raise ArgumentError, ~r/realm_name/, fn ->
      WhiteboardTopic.build("board", "board_hosted")
    end
  end

  defp restore(app, key, nil), do: Application.delete_env(app, key)
  defp restore(app, key, value), do: Application.put_env(app, key, value)
end
