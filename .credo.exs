# Credo, default checks, with one deliberate exception.
%{
  configs: [
    %{
      name: "default",
      files: %{included: ["apps/*/lib/", "apps/*/test/", "config/"], excluded: [~r"/_build/", ~r"/deps/"]},
      checks: %{
        disabled: [
          # Every module here opens with a header comment explaining why it
          # exists; none is published as library documentation, so a
          # @moduledoc would restate that comment or be `false`.
          {Credo.Check.Readability.ModuleDoc, []}
        ]
      }
    }
  ]
}
