# SPDX-FileCopyrightText: © 2025 Contributors to the OSHRePub project
# SPDX-License-Identifier: AGPL-3.0-only

defmodule OSHRePub.Accounts.OAuthLink do
  use Ecto.Schema
  import Ecto.Changeset

  schema "oauth_links" do
    field :type, :string
    field :remote_uid, :string
    field :token, :string

    field :allows_login, :boolean

    belongs_to :account, OSHRePub.Accounts.Account, type: :binary_id

    timestamps(updated_at: false)
  end

  def create_changeset(oauth_link, attrs, _opts \\ []) do
    oauth_link
    |> cast(attrs, [:account_id, :type, :remote_uid, :token, :allows_login])
  end

  def update_changeset(oauth_link, attrs, _opts \\ []) do
    oauth_link
    |> cast(attrs, [:token, :allows_login])
  end


  def fetch_remote_username(oauth_link) when oauth_link.type == "github" do
    url = "https://api.github.com/user"
    headers = ["X-GitHub-Api-Version": "2022-11-28", "Accept": "application/vnd.github+json", "Authorization": "Bearer #{oauth_link.token}"]

    {:ok, response} = HTTPoison.get(url, headers)

    {remote_uid, ""} = oauth_link.remote_uid |> Integer.parse

    body = Jason.decode!(response.body)
    case body do
      %{"id" => ^remote_uid, "login" => username} ->
        {:ok, username}
      _ ->
        {:error, "Invalid remote uid: #{body.remote_ud} != #{remote_uid}"}
    end
  end
end
