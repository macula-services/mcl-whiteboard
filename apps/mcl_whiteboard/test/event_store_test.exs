defmodule MclWhiteboard.EventStoreTest do
  # The store is the whole of this service's persistence, and mcl_om stopped
  # opening one at 0.35 (mcl-om#10). These tests prove the port did not leave
  # the shape that compiles clean and boots with no store: the old callbacks
  # are gone, the app opens the store ITSELF before it boots the service, and
  # the store the app opens is the one evoq dispatches to.
  use ExUnit.Case, async: false

  alias MclWhiteboard.{EventStore, Service}

  @store_id :board_store

  setup do
    :meck.unload()
    on_exit(fn -> :meck.unload() end)
    :ok
  end

  test "the app opens the store before it calls mcl_om:boot/1" do
    # A store id of this test's own, so "listed" cannot be inherited from the
    # store the booted application already opened in this VM: it is listed at
    # the moment boot runs only if open/1 ran first.
    id = :"board_order_test_#{System.unique_integer([:positive])}"
    dir = Path.join(System.tmp_dir!(), Atom.to_string(id))
    config = %{Service.event_store() | id: id, dir: String.to_charlist(dir)}
    parent = self()

    :ok = :meck.new(Service, [:passthrough])
    :ok = :meck.expect(Service, :event_store, fn -> config end)

    :ok = :meck.new(:mcl_om, [:passthrough])

    :ok =
      :meck.expect(:mcl_om, :boot, fn _service ->
        send(parent, {:boot_ran, :reckon_db_sup.which_stores()})
        :ok
      end)

    assert :ok = MclWhiteboard.Application.start(:normal, [])

    assert_receive {:boot_ran, listed}
    assert id in listed, "the store was not open when mcl_om:boot/1 ran"
    assert :reckon_db_store.is_ready(id) == true

    on_exit(fn -> :reckon_db_sup.stop_store(id) end)
  end

  test "opening the store starts its evoq subscription" do
    id = :"board_sub_test_#{System.unique_integer([:positive])}"
    dir = Path.join(System.tmp_dir!(), Atom.to_string(id))
    config = %{Service.event_store() | id: id, dir: String.to_charlist(dir)}

    assert :ok = EventStore.open(config)
    on_exit(fn -> :reckon_db_sup.stop_store(id) end)

    # evoq_store_subscription registers itself as evoq_store_sub_<store id>.
    subs = Process.whereis(:"evoq_store_sub_#{id}")
    assert is_pid(subs), "no evoq subscription for #{id}"
    assert Process.alive?(subs)
  end

  test "the store the booted application opened is listed and ready" do
    assert @store_id in :reckon_db_sup.which_stores()
    assert :reckon_db_store.is_ready(@store_id) == true
  end

  test "the store the service opens is the one evoq dispatches to" do
    store = Service.event_store()

    assert %{id: id, dir: dir, mode: :single, indexes: [], integrity: :disabled} = store
    assert id == Application.fetch_env!(:evoq, :store_id)
    assert is_list(dir)
  end

  test "the service describes its store, and not through the callbacks mcl_om dropped" do
    refute function_exported?(Service, :store_id, 0)
    refute function_exported?(Service, :data_dir, 0)
    assert :mcl_om.leftover_store_callbacks(Service) == []
  end

  test "the config carries the evoq adapter block the subscription reads" do
    assert Application.fetch_env!(:evoq, :event_store_adapter) == :reckon_evoq_adapter
    assert Application.fetch_env!(:evoq, :subscription_adapter) == :reckon_evoq_adapter
  end
end
