defmodule MclWhiteboard.InfoCapabilityTest do
  @moduledoc """
  `mcl-whiteboard/info`: mcl_om (0.28 and later) advertises it on every
  service. This asks the booted service's own handler and carries the answer
  through macula's frame codec (encode, decode, verify), the path a caller's
  reply takes, then reads it as that caller would.
  """
  use ExUnit.Case, async: false

  test "mcl-whiteboard/info answers who this service is and what it runs on" do
    answer = :mcl_om_info.answer(%{})
    reply = through_the_codec(answer)

    assert text(reply, :name) == "mcl-whiteboard"
    assert text(reply, :org) == "mcl-whiteboard"
    {:ok, vsn} = :application.get_key(:mcl_whiteboard, :vsn)
    assert text(reply, :version) == to_string(vsn)
    # 0.31.1 carries the store floors every service inherits; reckon_evoq
    # 2.7.2 reads snapshots back whole (2.7.0 rebuilt a reloaded aggregate
    # from nothing).
    assert Version.match?(text(reply, :mcl_om_version), "~> 0.31 and >= 0.31.1")
    _ = :application.load(:reckon_evoq)
    {:ok, reckon_evoq} = :application.get_key(:reckon_evoq, :vsn)
    assert Version.match?(to_string(reckon_evoq), ">= 2.7.2")
    assert Version.match?(text(reply, :macula_version), "~> 12.2")
    assert "mcl-whiteboard/info" in Enum.map(field(reply, :capabilities), &unwrap/1)
  end

  test "the service does not declare an info capability of its own" do
    refute Enum.any?(MclWhiteboard.Service.capabilities(), &(&1.name == "info"))
  end

  defp through_the_codec(payload) do
    {:ok, key} = :macula_node_keys.generate(:identity, profile(), %{puzzle_difficulty: 0})

    spec = %{
      request_id: :crypto.strong_rand_bytes(16),
      realm: :crypto.hash(:sha256, "io.macula"),
      procedure: "mcl-whiteboard/info",
      target: :macula_node_keys.key_id(key),
      deadline: System.system_time(:millisecond) + 60_000,
      payload: payload
    }

    {:ok, decoded, ""} = :macula_frame.decode(:macula_frame.encode(:macula_frame.call(spec, key)))
    {:ok, %{payload: delivered}} = :macula_frame.verify_request(decoded, profile())
    delivered
  end

  # A key arrives as an atom when this VM knows it, else as {:text, bin}.
  defp field(map, key) do
    Enum.find_value(map, fn {k, v} -> if unwrap(k) in [key, Atom.to_string(key)], do: v end)
  end

  defp text(map, key), do: unwrap(field(map, key))
  defp unwrap({:text, b}) when is_binary(b), do: b
  defp unwrap(b), do: b

  defp profile do
    {:ok, p} = :macula_crypto_profile.configured()
    p
  end
end
