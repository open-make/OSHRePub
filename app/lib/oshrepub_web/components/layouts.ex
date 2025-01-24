# SPDX-FileCopyrightText: © 2025 Contributors to the OSHRePub project
# SPDX-License-Identifier: AGPL-3.0-only

defmodule OSHRePubWeb.Layouts do
  @moduledoc """
  This module holds different layouts used by your application.

  See the `layouts` directory for all templates available.
  The "root" layout is a skeleton rendered as part of the
  application router. The "app" layout is set as the default
  layout on both `use OSHRePubWeb, :controller` and
  `use OSHRePubWeb, :live_view`.
  """
  use OSHRePubWeb, :html

  embed_templates "layouts/*"

  attr :id, :string
  attr :current_account, :any
  attr :active_tab, :atom
  def sidebar_nav_links(assigns) do
    ~H"""
    <div class="space-y-1">
      <%= if @current_account do %>

        <.link
          navigate={~p"/projects"}
          class={
            "text-zinc-700 hover:text-zinc-900 dark:text-zinc-300 dark:hover:text-zinc-100 group flex items-center p-2 text-sm font-medium rounded-md #{if @active_tab == :projects, do: "bg-zinc-200 dark:bg-zinc-700", else: "hover:bg-zinc-50 dark:hover:bg-zinc-600"}"
          }
          aria-current={if @active_tab == :projects, do: "true", else: "false"}
        >
          <.icon
            name="hero-folder"
            class="text-zinc-400 group-hover:text-zinc-500 dark:text-zinc-500 dark:group-hover:text-zinc-400 mr-3 flex-shrink-0 h-6 w-6"
          /> Projects
        </.link>

        <.link
          navigate={~p"/settings"}
          class={
            "text-zinc-700 hover:text-zinc-900 dark:text-zinc-300 dark:hover:text-zinc-100 group flex items-center p-2 text-sm font-medium rounded-md #{if @active_tab == :settings, do: "bg-zinc-200 dark:bg-zinc-700", else: "hover:bg-zinc-50 dark:hover:bg-zinc-600"}"
          }
          aria-current={if @active_tab == :settings, do: "true", else: "false"}
        >
          <.icon
            name="hero-cog-6-tooth"
            class="text-zinc-400 group-hover:text-zinc-500 dark:group-hover:text-zinc-400 mr-3 flex-shrink-0 h-6 w-6"
          /> Settings
        </.link>

        <.link
          href={~p"/log_out"} method="delete"
          class={
            "text-zinc-700 hover:text-zinc-900 dark:text-zinc-300 dark:hover:text-zinc-100 group flex items-center p-2 text-sm font-medium rounded-md hover:bg-zinc-50 dark:hover:bg-zinc-600"
          }
        >
          <.icon
          name="hero-arrow-right-start-on-rectangle"
          class="text-zinc-400 group-hover:text-zinc-500 dark:group-hover:text-zinc-400 mr-3 flex-shrink-0 h-6 w-6"
          /> Log out
        </.link>


      <% else %>
        <.link
          navigate={~p"/log_in"}
          class="text-zinc-700 hover:text-zinc-900 hover:bg-zinc-50 group flex items-center px-2 py-2 text-sm font-medium rounded-md"
        >
          <svg
            class="text-zinc-400 group-hover:text-zinc-500 mr-3 flex-shrink-0 h-6 w-6"
            xmlns="http://www.w3.org/2000/svg"
            fill="none"
            viewBox="0 0 24 24"
            stroke="currentColor"
            aria-hidden="true"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"
            >
            </path>
          </svg>
          Sign in
        </.link>
      <% end %>
    </div>
    """
  end
end
