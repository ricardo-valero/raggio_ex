import Config

config :logger, :console,
  level: :info,
  format: "$date $time [$level] $metadata$message\n"

if config_env() == :test do
  import_config "test.exs"
end
