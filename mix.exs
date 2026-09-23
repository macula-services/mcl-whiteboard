defmodule MclWhiteboardUmbrella.MixProject do
  use Mix.Project

  def project do
    [
      apps_path: "apps",
      version: "0.1.0",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      releases: releases(),
      dialyzer: dialyzer()
    ]
  end

  defp releases do
    [
      mcl_whiteboard: [
        # Every app in the umbrella must be listed explicitly here --
        # `mix release` does NOT auto-include the rest just because
        # they're present under apps/. Adding a new umbrella app and
        # forgetting to add it here compiles fine and boots fine (`mix
        # phx.server`/`mix run` don't have this restriction), then
        # silently excludes it from the actual release with no error --
        # found the hard way when mcl_whiteboard_web's Endpoint never
        # started inside the built container, despite working locally.
        # Listed in boot order: the departments, then the service (whose
        # mcl_om:boot/1 opens the store), then the web app.
        applications: [
          guide_board_lifecycle: :permanent,
          project_boards: :permanent,
          query_boards: :permanent,
          track_presence: :permanent,
          mcl_whiteboard: :permanent,
          mcl_whiteboard_web: :permanent
        ]
      ]
    ]
  end

  # Declared once at the umbrella root: every apps/*/mix.exs points
  # deps_path/build_path at ../../, so `mix credo` and `mix dialyzer` from
  # the root cover every app (same layout as macula-realm).
  defp deps do
    [
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}
    ]
  end

  defp dialyzer do
    [
      plt_add_apps: [:mix, :ex_unit],
      # macula and reckon_db ship beams without debug_info (NIF-heavy
      # rebar3 packages), so the PLT cannot scan them; calls into them are
      # untyped from dialyzer's side.
      plt_ignore_apps: [:macula, :reckon_db],
      plt_core_path: "priv/plts/core",
      plt_local_path: "priv/plts/local",
      ignore_warnings: ".dialyzer_ignore.exs",
      flags: [:unmatched_returns, :error_handling]
    ]
  end
end
