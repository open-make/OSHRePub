# SPDX-FileCopyrightText: © 2025 Contributors to the OSHRePub project
# SPDX-License-Identifier: AGPL-3.0-only

defmodule OSHRePubWeb.ReviewLive do

    use OSHRePubWeb, :live_view

    require Logger

    import OSHRePub.Accounts

    alias OSHRePub.Repo
    alias OSHRePub.Projects.Project
    alias OSHRePub.Reviews.Review

    defp find_project(owner_username, projectname) when is_nil(owner_username) or is_nil(projectname), do: nil
    defp find_project(owner_username, projectname) do
      project_owner = get_account_by_username(owner_username)
      if project_owner do
        Repo.get_by(Project, owner_id: project_owner.id, name: projectname)
      end
    end

    def mount(%{"username" => username,
                "projectname" => projectname,
                "review_id" => review_id} = _params, _session, socket) do

      project = find_project(username, projectname)
      review = Repo.get_by(Review, id: review_id)
      if project do
        if project.owner_id == socket.assigns.current_account.id do
          # if connected?(socket) do
          #   PubSub.subscribe(OSHRePub.PubSub, "source_manager")
          # end

          {:ok, socket |> assign(%{
            project: project,
            review: review,
          })}
        else
          raise OSHRePubWeb.ReviewLive.UnauthorizedError
        end
      else
        raise OSHRePubWeb.ReviewLive.InvalidReviewError
      end
    end

    def render(assigns) do
      ~H"""
      <.header class="text-left px-4 py-4 border-b">
        {@project.name} Review {@review.id}
      </.header>

      <div class="mx-auto divide-y mt-10 ml-10 grid grid-flow-col grid-rows-1 grid-cols-4 gap-4">

        <div class="row-span-1 col-span-1 flex flex-col text-center border-none">
          <h2 class="text-lg border-none font-semibold leading-8 text-zinc-800 dark:text-zinc-50">Parts</h2>

          <table class="table-auto border-collapse border mt-4">
            <thead>
              <tr>
                <th class="border bg-zinc-100 dark:bg-zinc-700">Position</th>
                <th class="border bg-zinc-100 dark:bg-zinc-700">Name</th>
                <th class="border bg-zinc-100 dark:bg-zinc-700">Quantity</th>
              </tr>
            </thead>
            <tbody>
              <%= for part <- @review.parts do %>
                <tr>
                  <td class="border">{part.position}</td>
                  <td class="border">{part.name}</td>
                  <td class="border">{part.quantity}</td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>

        <div class="row-span-1 col-span-3 flex flex-col text-center border-none">
          <h2 class="text-lg border-none font-semibold leading-8 text-zinc-800 dark:text-zinc-50">Comments</h2>
        </div>

      </div>
      """
    end
  end

  defmodule OSHRePubWeb.ReviewLive.InvalidReviewError do
    defexception message: "Invalid review", plug_status: 404
  end

  defmodule OSHRePubWeb.ReviewLive.UnauthorizedError do
    defexception message: "Review not owned", plug_status: 403
  end
