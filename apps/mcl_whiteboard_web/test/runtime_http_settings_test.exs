defmodule MclWhiteboardWeb.RuntimeHttpSettingsTest do
  # mcl-whiteboard#15, R2/R3: these cases run the REAL config/runtime.exs, as a
  # release boot would (env :prod), and never a copy of its parse. A setting
  # that would make the UI do something the box did not mean refuses the boot
  # by name; the accepted ones are read back from what the file configures.
  use ExUnit.Case, async: false

  @runtime Path.expand("../../../config/runtime.exs", __DIR__)
  @vars ["MCL_HTTP_IP", "MCL_HTTP_ORIGINS", "MCL_HTTP_PORT", "SECRET_KEY_BASE"]

  setup do
    saved = for var <- @vars, into: %{}, do: {var, System.get_env(var)}

    on_exit(fn ->
      for {var, value} <- saved,
          do: if(value, do: System.put_env(var, value), else: System.delete_env(var))
    end)

    for var <- @vars, do: System.delete_env(var)
    System.put_env("SECRET_KEY_BASE", String.duplicate("k", 64))
    System.put_env("MCL_HTTP_PORT", "4555")
    :ok
  end

  defp boot_with(env) do
    for {var, value} <- env, do: System.put_env(var, value)
    Config.Reader.read!(@runtime, env: :prod, target: :host)
  end

  defp endpoint(config), do: config[:mcl_whiteboard_web][MclWhiteboardWeb.Endpoint]

  test "an address that does not parse refuses the boot, naming it" do
    assert_raise ArgumentError, ~s(MCL_HTTP_IP="not-an-address" is not an IP address), fn ->
      boot_with(%{"MCL_HTTP_IP" => "not-an-address"})
    end
  end

  test "an address beyond loopback with no origins refuses the boot" do
    assert_raise ArgumentError,
                 ~r/^MCL_HTTP_IP="0\.0\.0\.0" serves beyond loopback, but MCL_HTTP_ORIGINS is empty/,
                 fn ->
                   boot_with(%{"MCL_HTTP_IP" => "0.0.0.0"})
                 end
  end

  test "a wildcard origin refuses the boot, naming the entry" do
    assert_raise ArgumentError,
                 ~r/^MCL_HTTP_ORIGINS entry "\/\/\*\.example\.com:4555" is not \/\/host:port/,
                 fn ->
                   boot_with(%{
                     "MCL_HTTP_IP" => "0.0.0.0",
                     "MCL_HTTP_ORIGINS" => "//box.example:4555,//*.example.com:4555"
                   })
                 end
  end

  test "an origin with a scheme or with no port refuses the boot" do
    for entry <- ["http://box.example:4555", "//box.example"] do
      assert_raise ArgumentError,
                   ~r/^MCL_HTTP_ORIGINS entry "#{Regex.escape(entry)}" is not/,
                   fn ->
                     boot_with(%{"MCL_HTTP_IP" => "0.0.0.0", "MCL_HTTP_ORIGINS" => entry})
                   end
    end
  end

  test "an origin whose port is outside 1..65535 refuses the boot" do
    for entry <- ["//box.example:70000", "//box.example:0"] do
      assert_raise ArgumentError,
                   ~r/^MCL_HTTP_ORIGINS entry "#{Regex.escape(entry)}" is not/,
                   fn ->
                     boot_with(%{"MCL_HTTP_IP" => "0.0.0.0", "MCL_HTTP_ORIGINS" => entry})
                   end
    end
  end

  test "an origin written in capitals is kept in lowercase, as a browser sends it" do
    web =
      endpoint(
        boot_with(%{"MCL_HTTP_IP" => "0.0.0.0", "MCL_HTTP_ORIGINS" => "//Box.Example:4555"})
      )

    assert List.last(web[:check_origin]) == "//box.example:4555"
    assert List.last(web[:allowed_hosts]) == "box.example"
  end

  test "with nothing set, the UI listens on loopback and answers local origins and hosts only" do
    web = endpoint(boot_with(%{}))
    assert web[:http][:ip] == {127, 0, 0, 1}
    assert web[:check_origin] == ["//localhost:4555", "//127.0.0.1:4555", "//[::1]:4555"]
    assert web[:allowed_hosts] == ["localhost", "127.0.0.1", "::1"]
  end

  test "a box serving its LAN names its origins, and those hosts are allowed too" do
    web =
      endpoint(
        boot_with(%{
          "MCL_HTTP_IP" => "0.0.0.0",
          "MCL_HTTP_ORIGINS" => " //box.example:4555 , //192.0.2.13:4555,//[2001:db8::7]:4555"
        })
      )

    assert web[:http][:ip] == {0, 0, 0, 0}

    assert web[:check_origin] == [
             "//localhost:4555",
             "//127.0.0.1:4555",
             "//[::1]:4555",
             "//box.example:4555",
             "//192.0.2.13:4555",
             "//[2001:db8::7]:4555"
           ]

    assert web[:allowed_hosts] == [
             "localhost",
             "127.0.0.1",
             "::1",
             "box.example",
             "192.0.2.13",
             "2001:db8::7"
           ]
  end

  test "loopback with no origins boots: the default, reached through a tunnel" do
    assert endpoint(boot_with(%{"MCL_HTTP_IP" => "::1"}))[:http][:ip] == {0, 0, 0, 0, 0, 0, 0, 1}
  end
end
