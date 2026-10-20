# Dialyzer ignore file (term format, see deps/dialyxir/README.md).
#
# Every entry is a known finding that is not a defect in this repository.
[
  # macula ships its beams without debug_info (a NIF-heavy rebar3 package),
  # so it is excluded from the PLT (`plt_ignore_apps` in mix.exs). Dialyzer
  # then cannot see macula's functions or the callbacks of its behaviours.
  # Calls into macula are untyped from here; nothing else is hidden.
  ~r/Function :macula_(subscriber|topic)\.[a-z_]+\/\d+ does not exist/,
  ~r/Callback info about the :macula_subscriber behaviour is not available/,
  # reckon_db is excluded from the PLT for the same reason, so the store
  # wiring's calls into reckon_db_sup and its probe into reckon_db_store are
  # untyped from here.
  ~r/Function :reckon_db_(sup|store)\.[a-z_]+\/\d+ does not exist/
]
