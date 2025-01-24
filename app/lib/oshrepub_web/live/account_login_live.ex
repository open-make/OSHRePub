# SPDX-FileCopyrightText: © 2025 Contributors to the OSHRePub project
# SPDX-License-Identifier: AGPL-3.0-only

defmodule OSHRePubWeb.AccountLoginLive do
  use OSHRePubWeb, :live_view

  def render(assigns) do
    ~H"""
    <div class="min-h-screen flex flex-col justify-center py-12 sm:px-6 lg:px-8">
      <.header class="text-center">
        Log in to account
        <:subtitle>
          Don't have an account?
          <.link navigate={~p"/register"} class="font-semibold text-wisteria-600 hover:underline">
            Register
          </.link>
          for an account or log in with an external identity below.
        </:subtitle>
      </.header>

      <div class="mt-8 sm:mx-auto sm:w-full sm:max-w-md">
        <div class="bg-white dark:bg-black p-4 shadow rounded-lg">
          <.simple_form for={@form} id="login_form" action={~p"/log_in"} phx-update="ignore">
            <.input field={@form[:username]} type="text" label="Username" required />
            <.input field={@form[:password]} type="password" label="Password" required />

            <:actions>
              <.input field={@form[:remember_me]} type="checkbox" label="Keep me logged in"/>
              <.link href={~p"/reset_password"} class="text-sm font-semibold text-wisteria-600">
                Forgot your password?
              </.link>
            </:actions>
            <:actions>
              <.button phx-disable-with="Logging in..." class="w-full">
                Log in with username and password <span aria-hidden="true">→</span>
              </.button>
            </:actions>
          </.simple_form>
        </div>
      </div>

      <div class="mt-8 sm:mx-auto sm:w-full sm:max-w-md">
        <div class="bg-white dark:bg-black p-4 shadow rounded-lg">
          <div class="space-y-6">
            <.link href={~p"/auth/github?scope=read:user,user:email,admin:repo_hook,read:org,repo"} class="w-full flex justify-center rounded-lg bg-wisteria-600 hover:bg-wisteria-400 py-2 px-3 text-sm font-semibold leading-6 text-white active:text-white/80 w-full">Log in with GitHub <span aria-hidden="true">→</span></.link>
          </div>
        </div>
      </div>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    username = Phoenix.Flash.get(socket.assigns.flash, :username)
    form = to_form(%{"username" => username}, as: "account")
    {:ok, assign(socket, form: form), temporary_assigns: [form: form]}
  end
end
