import Config

config :logger, level: :warning

config :ex_unit,
  capture_log: true,
  assert_receive_timeout: 500
