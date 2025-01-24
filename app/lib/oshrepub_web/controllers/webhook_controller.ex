# SPDX-FileCopyrightText: © 2025 Contributors to the OSHRePub project
# SPDX-License-Identifier: AGPL-3.0-only

defmodule OSHRePubWeb.WebhookController do
  use OSHRePubWeb, :controller

  require Logger

  alias Phoenix.PubSub

  def handle(conn, params) do
    PubSub.broadcast(OSHRePub.PubSub, "webhook", params)
    conn
    |> Plug.Conn.send_resp(200, [])
    |> Plug.Conn.halt()
  end
end
