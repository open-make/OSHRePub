# SPDX-FileCopyrightText: © 2025 Contributors to the OSHRePub project
# SPDX-License-Identifier: AGPL-3.0-only

defmodule OSHRePub.Accounts.UserNotifier do
  import Swoosh.Email

  alias OSHRePub.Mailer

  # Delivers the email using the application mailer.
  defp deliver(recipient, subject, body) do
    email =
      new()
      |> to(recipient)
      |> from({"OSHRePub", "contact@example.com"})
      |> subject(subject)
      |> text_body(body)

    # if Application.compile_env(:oshrepub, :dev_logging) do
      IO.inspect(email)
    # end

    with {:ok, _metadata} <- Mailer.deliver(email) do
      {:ok, email}
    end
  end

  @doc """
  Deliver instructions to confirm account.
  """
  def send_confirmation_instructions(account, url) do
    deliver(account.email, "Confirmation instructions", """

    ==============================

    Hi #{account.email},

    You can confirm your account by visiting the URL below:

    #{url}

    If you didn't create an account with us, please ignore this.

    ==============================
    """)
  end

  @doc """
  Deliver instructions to reset an account password.
  """
  def send_reset_password_instructions(account, url) do
    deliver(account.email, "Reset password instructions", """

    ==============================

    Hi #{account.email},

    You can reset your password by visiting the URL below:

    #{url}

    If you didn't request this change, please ignore this.

    ==============================
    """)
  end

  @doc """
  Deliver instructions to update an account email.
  """
  def send_update_email_instructions(account, url) do
    deliver(account.email, "Update email instructions", """

    ==============================

    Hi #{account.email},

    You can change your email by visiting the URL below:

    #{url}

    If you didn't request this change, please ignore this.

    ==============================
    """)
  end
end
