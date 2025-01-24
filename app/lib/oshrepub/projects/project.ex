# SPDX-FileCopyrightText: © 2025 Contributors to the OSHRePub project
# SPDX-License-Identifier: AGPL-3.0-only

defmodule OSHRePub.Projects.Project do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, UUIDv7, autogenerate: true}

  schema "projects" do
    field :name, :string

    field :source_repository_type, :string
    field :source_repository_uid, :string
    field :source_repository_html_url, :string
    field :source_repository_git_url, :string

    belongs_to :owner, OSHRePub.Accounts.Account, type: :binary_id

    timestamps(type: :utc_datetime, updated_at: false)
  end

  def webhook_host(), do: Application.fetch_env!(:oshrepub, OSHRePub)[:webhook_host]

  def create_changeset(project, attrs, _opts \\ []) do
    project
    |> cast(attrs, [:owner_id, :name, :source_repository_type, :source_repository_uid, :source_repository_html_url, :source_repository_git_url])
  end

  def create_webhook(oauth_token, project) do
    url = "https://api.github.com/repositories/#{project.source_repository_uid}/hooks"
    headers = ["X-GitHub-Api-Version": "2022-11-28", "Accept": "application/vnd.github+json", "Authorization": "Bearer #{oauth_token}"]

    body = Jason.encode!(%{
      name: :web,
      active: true,
      events: [:push],
      config: %{url: "#{webhook_host()}/api/webhook/github?project_id=#{project.id}&event=push", content_type: :json, insecure_ssl: 0, secret: System.get_env("GITHUB_WEBHOOK_SECRET")}
    })

    {:ok, _response} = HTTPoison.post(url, body, headers)
  end

  def delete_webhook(oauth_token, project, hook_id) do
    url = "https://api.github.com/repositories/#{project.source_repository_uid}/hooks/#{hook_id}"
    headers = ["X-GitHub-Api-Version": "2022-11-28", "Accept": "application/vnd.github+json", "Authorization": "Bearer #{oauth_token}"]

    {:ok, _response} = HTTPoison.delete(url, headers)
  end

  def clear_webhooks(oauth_token, project) do
    url = "https://api.github.com/repositories/#{project.source_repository_uid}/hooks"
    headers = ["X-GitHub-Api-Version": "2022-11-28", "Accept": "application/vnd.github+json", "Authorization": "Bearer #{oauth_token}"]

    {:ok, response} = HTTPoison.get(url, headers)

    body = Jason.decode!(response.body)
    project_id = project.id
    url_pattern = "#{webhook_host()}/api/webhook/github?project_id=#{project_id}&"
    # FIXME: Don't hardcode url
    for %{"config" => %{"url" => ^url_pattern <> _suffix }, "id" => hook_id} <- body do
      delete_webhook(oauth_token, project, hook_id)
    end
  end

  def fetch_tags(oauth_token, project) do
    url = "https://api.github.com/repositories/#{project.source_repository_uid}/tags"
    headers = ["X-GitHub-Api-Version": "2022-11-28", "Accept": "application/vnd.github+json", "Authorization": "Bearer #{oauth_token}"]

    {:ok, response} = HTTPoison.get(url, headers)

    body = Jason.decode!(response.body)

    body
  end
end
