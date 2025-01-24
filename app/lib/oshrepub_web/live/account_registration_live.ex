# SPDX-FileCopyrightText: © 2025 Contributors to the OSHRePub project
# SPDX-License-Identifier: AGPL-3.0-only

defmodule OSHRePubWeb.AccountRegistrationLive do
  use OSHRePubWeb, :live_view

  alias OSHRePub.Accounts
  alias OSHRePub.Accounts.Account

  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-sm">
      <.header class="text-center">
        Register for an account
        <:subtitle>
          Already registered?
          <.link navigate={~p"/log_in"} class="font-semibold text-wisteria-600 hover:underline">
            Log in
          </.link>
          to your account now.
        </:subtitle>
      </.header>

      <div class="bg-white dark:bg-black shadow rounded-lg p-4 mt-4">
        <.simple_form
          for={@form}
          id="registration_form"
          phx-submit="save"
          phx-change="validate"
          phx-trigger-action={@trigger_submit}
          action={~p"/log_in?_action=registered"}
          method="post"
        >
          <.error :if={@check_errors}>
            Oops, something went wrong! Please check the errors below.
          </.error>

          <.input field={@form[:email]} type="email" label="Email" required />
          <.input field={@form[:password]} type="password" label="Password" required />
          <.input field={@form[:username]} type="text" label="Username" required />

          <:actions>
            <.button phx-disable-with="Creating account..." class="w-full">Create an account</.button>
          </:actions>
        </.simple_form>
      </div>

    </div>
    """
  end

  def mount(_params, _session, socket) do
    changeset = Accounts.change_account_registration(%Account{})

    socket =
      socket
      |> assign(trigger_submit: false, check_errors: false)
      |> assign_form(changeset)

    {:ok, socket, temporary_assigns: [form: nil]}
  end

  def handle_event("save", %{"account" => account_params}, socket) do
    case Accounts.register_account(account_params) do
      {:ok, account} ->
        {:ok, _} =
          Accounts.send_account_confirmation_instructions(
            account,
            &url(~p"/confirm_account/#{&1}")
          )

        changeset = Accounts.change_account_registration(account)
        {:noreply, socket |> assign(trigger_submit: true) |> assign_form(changeset)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, socket |> assign(check_errors: true) |> assign_form(changeset)}
    end
  end

  def handle_event("validate", %{"account" => account_params}, socket) do
    changeset = Accounts.change_account_registration(%Account{}, account_params)
    {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    form = to_form(changeset, as: "account")

    if changeset.valid? do
      assign(socket, form: form, check_errors: false)
    else
      assign(socket, form: form)
    end
  end
end
