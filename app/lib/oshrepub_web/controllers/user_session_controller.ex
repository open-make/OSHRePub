# SPDX-FileCopyrightText: © 2025 Contributors to the OSHRePub project
# SPDX-License-Identifier: AGPL-3.0-only

defmodule OSHRePubWeb.UserSessionController do
  use OSHRePubWeb, :controller

  require Logger

  alias OSHRePub.Accounts
  alias OSHRePubWeb.UserAuth
  alias OSHRePub.Repo
  alias OSHRePub.Accounts.Account
  alias OSHRePub.Accounts.OAuthLink

  plug Ueberauth

  def create(conn, %{"_action" => "registered"} = params) do
    create(conn, params, "Account created successfully!")
  end

  def create(conn, %{"_action" => "password_updated"} = params) do
    conn
    |> put_session(:user_return_to, ~p"/settings")
    |> create(params, "Password updated successfully!")
  end

  def create(conn, params) do
    create(conn, params, "Welcome back!")
  end

  defp create(conn, %{"account" => account_params}, info) do
    %{"username" => username, "password" => password} = account_params

    if account = Accounts.get_account_by_username_and_password(username, password) do
      conn
      |> put_flash(:info, info)
      |> UserAuth.log_in_to_account(account, account_params)
    else
      # In order to prevent account enumeration attacks, don't disclose whether the username is registered.
      conn
      |> put_flash(:error, "Invalid username or password")
      |> put_flash(:username, String.slice(username, 0, 160))
      |> redirect(to: ~p"/log_in")
    end
  end

  defp create(%{assigns: %{ueberauth_auth: auth}, path_params: %{"oauth_provider" => "github"}} = conn, _params, info) do
    case findOrCreateLinkedAccount(%{type: "github", remote_uid: "#{auth.uid}", token: auth.credentials.token, username: auth.info.nickname, email: auth.info.email}) do
      {:ok, account} ->
        conn
        |> put_flash(:info, info)
        |> UserAuth.log_in_to_account(account, %{})

      {:error, msg} ->
        Logger.error(msg)
        conn
        |> put_flash(:error, "Something went wrong")
        |> redirect(to: ~p"/log_in")
    end
  end

  defp findOrCreateLinkedAccount(link_data) do
    case Repo.get_by(OAuthLink, type: link_data.type, remote_uid: link_data.remote_uid) do
      nil ->
        Logger.info("Creating new OAuth account for remote_uid #{link_data.remote_uid}")
        {:ok, account} = Repo.insert(Account.oauth_registration_changeset(%Account{}, link_data))
        Repo.insert(OAuthLink.create_changeset(%OAuthLink{}, Map.merge(link_data, %{account_id: account.id, allows_login: true})))
        {:ok, account}
      %OAuthLink{allows_login: true} = oauth_link ->
        account = Repo.get(Account, oauth_link.account_id)
        Repo.update(OAuthLink.update_changeset(oauth_link, link_data))
        {:ok, account}
      _ ->
        {:error, "Account may not login via this OAuth link"}
    end
  end

  def delete(conn, _params) do
    conn
    |> put_flash(:info, "Logged out successfully.")
    |> UserAuth.log_out_of_account()
  end
end
