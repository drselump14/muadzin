defmodule Muadzin.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    # Configure logger backends based on target
    setup_logger_backends(target())

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Muadzin.Supervisor]

    children =
      [
        # Children for all targets
        # Starts a worker by calling: Muadzin.Worker.start_link(arg)
        # {Muadzin.Worker, arg},
        {Phoenix.PubSub, name: Muadzin.PubSub}
      ] ++ children(target())

    Supervisor.start_link(children, opts)
  end

  defp setup_logger_backends(:host) do
    # On host, keep console logger and optionally add papertrail
    if System.get_env("PAPERTRAIL_URL") do
      LoggerBackends.add(LoggerPapertrailBackend.Logger)
    end
  end

  defp setup_logger_backends(_target) do
    # On target devices, use RingLogger for in-memory log buffer
    LoggerBackends.add(RingLogger)

    # Also add papertrail if configured
    if System.get_env("PAPERTRAIL_URL") do
      LoggerBackends.add(LoggerPapertrailBackend.Logger)
    end
  end

  # List all child processes to be supervised
  def children(:host) do
    [
      # Children that only run on the host
      # Starts a worker by calling: Muadzin.Worker.start_link(arg)
      # {Muadzin.Worker, arg},
      {Muadzin.AudioPlayer, name: Muadzin.AudioPlayer},
      {Muadzin.Scheduler, name: Muadzin.Scheduler},
      MuadzinWeb.Endpoint
    ]
  end

  def children(_target) do
    [
      # Children for all targets except host
      # Starts a worker by calling: Muadzin.Worker.start_link(arg)
      # {Muadzin.Worker, arg},
      {Muadzin.AudioPlayer, name: Muadzin.AudioPlayer},
      {Muadzin.Scheduler, name: Muadzin.Scheduler},
      MuadzinWeb.Endpoint
    ]
  end

  def target() do
    Application.get_env(:muadzin, :target)
  end
end
