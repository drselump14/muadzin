load_dot_iex := "iex --dot-iex iex_dev.exs -S mix"

default:
  just -l

ds:
  {{load_dot_iex}} phx.server

c:
  {{load_dot_iex}}
