# SPDX-FileCopyrightText: © 2025 Contributors to the OSHRePub project
# SPDX-License-Identifier: AGPL-3.0-only

defmodule OSHRePubWeb.Router do
  use OSHRePubWeb, :router

  import OSHRePubWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {OSHRePubWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_user
  end

  pipeline :browser_nocsrf do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {OSHRePubWeb.Layouts, :root}
    plug :put_secure_browser_headers
    plug :fetch_current_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  # Other scopes may use custom stacks.
  # scope "/api", OSHRePubWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:oshrepub, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: OSHRePubWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  scope "/", OSHRePubWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    get "/", PageController, :redirect_authenticated

    live_session :redirect_if_user_is_authenticated,
      on_mount: [{OSHRePubWeb.UserAuth, :redirect_if_user_is_authenticated}, OSHRePubWeb.Nav] do
      live "/register", AccountRegistrationLive, :new
      live "/log_in", AccountLoginLive, :new
      live "/reset_password", AccountForgotPasswordLive, :new
      live "/reset_password/:token", AccountResetPasswordLive, :edit
    end

    post "/log_in", UserSessionController, :create
  end

  scope "/auth", OSHRePubWeb do
    pipe_through :browser

    get "/:oauth_provider", UserSessionController, :request
    get "/:oauth_provider/callback", UserSessionController, :create
  end

  scope "/", OSHRePubWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [{OSHRePubWeb.UserAuth, :ensure_authenticated}, OSHRePubWeb.Nav] do
      live "/dashboard", DashboardLive
      live "/settings", AccountSettingsLive, :edit
      live "/settings/confirm_email/:token", AccountSettingsLive, :confirm_email

      live "/projects", ProjectsLive
      live "/:username/:projectname", ProjectLive

      live "/:username/:projectname/reviews/:review_id", ReviewLive
    end

    get "/:username/:projectname/pipelines/:pipeline_id", PipelineController, :handle
  end

  scope "/", OSHRePubWeb do
    pipe_through [:browser_nocsrf, :require_authenticated_user]

    get "/:username/:projectname/pipelines/:pipeline_id/:jobname", PipelineController, :view_job
    get "/:username/:projectname/pipelines/:pipeline_id/:jobname/*jobpath", PipelineController, :view_job
  end

  scope "/", OSHRePubWeb do
    pipe_through [:browser]

    delete "/log_out", UserSessionController, :delete

    live_session :current_account,
      on_mount: [{OSHRePubWeb.UserAuth, :mount_current_account}, OSHRePubWeb.Nav] do

      live "/confirm_account/:token", AccountConfirmationLive, :edit
      live "/confirm_account", AccountConfirmationInstructionsLive, :new
    end
  end
end
