# SPDX-FileCopyrightText: © 2025 Contributors to the OSHRePub project
# SPDX-License-Identifier: AGPL-3.0-only

defmodule OSHRePubWeb.Nav do
  import Phoenix.LiveView
  use Phoenix.Component

  def on_mount(:default, _params, _session, socket) do
    {:cont,
     socket
     |> attach_hook(:active_tab, :handle_params, &handle_active_tab_params/3)}
  end

  defp handle_active_tab_params(_params, _url, socket) do
    active_tab =
      case {socket.view, socket.assigns.live_action} do

        {OSHRePubWeb.ProjectsLive, _} ->
          :projects

        {OSHRePubWeb.AccountSettingsLive, _} ->
          :settings

        {_, _} ->
          nil
      end

    {:cont, assign(socket, active_tab: active_tab)}
  end

end
