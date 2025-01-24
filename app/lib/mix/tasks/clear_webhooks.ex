# SPDX-FileCopyrightText: © 2025 Contributors to the OSHRePub project
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Mix.Tasks.ClearWebhooks do
  use Mix.Task

  alias OSHRePub.Repo
  alias OSHRePub.Projects.Project
  alias OSHRePub.Accounts.OAuthLink

  def run(_) do
    #Mix.Task.run("phx.server")
    Application.ensure_all_started(:oshrepub)
    for project <- Repo.all(Project) do
      oauth_link = Repo.get_by(OAuthLink, account_id: project.owner_id, type: project.source_repository_type) |> Repo.preload([:account])
      Project.clear_webhooks(oauth_link.token, project)
    end
    Application.stop(:oshrepub)
  end
end
