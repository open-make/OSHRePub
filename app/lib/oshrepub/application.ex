# SPDX-FileCopyrightText: © 2025 Contributors to the OSHRePub project
# SPDX-License-Identifier: AGPL-3.0-only

defmodule OSHRePub.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      OSHRePubWeb.Telemetry,
      OSHRePub.Repo,
      {DNSCluster, query: Application.get_env(:oshrepub, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: OSHRePub.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: OSHRePub.Finch},
      # Start a worker by calling: OSHRePub.Worker.start_link(arg)
      # {OSHRePub.Worker, arg},
      # Start to serve requests, typically the last entry
      OSHRePubWeb.Endpoint,

      OSHRePub.Projects.SourceManager,

      {Task.Supervisor, name: OSHRePub.TaskSupervisor}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: OSHRePub.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    OSHRePubWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
