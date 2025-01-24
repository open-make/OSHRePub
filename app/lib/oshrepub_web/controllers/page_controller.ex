# SPDX-FileCopyrightText: © 2025 Contributors to the OSHRePub project
# SPDX-License-Identifier: AGPL-3.0-only

defmodule OSHRePubWeb.PageController do
  use OSHRePubWeb, :controller

  import OSHRePubWeb.UserAuth, only: [fetch_current_user: 2]

  plug :fetch_current_user

  def redirect_authenticated(conn, _) do
    if conn.assigns[:current_account] do
      OSHRePubWeb.UserAuth.redirect_if_user_is_authenticated(conn, [])
    else
      redirect(conn, to: ~p"/log_in")
    end
  end
end
