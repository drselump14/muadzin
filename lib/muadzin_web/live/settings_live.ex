defmodule MuadzinWeb.SettingsLive do
  use MuadzinWeb, :live_view

  alias Muadzin.Settings

  @impl true
  def mount(_params, _session, socket) do
    settings = Settings.get_all()

    socket =
      socket
      |> assign(:latitude, Float.to_string(settings.latitude))
      |> assign(:longitude, Float.to_string(settings.longitude))
      |> assign(:timezone, settings.timezone)
      |> assign(:error, nil)
      |> assign(:success, nil)

    {:ok, socket}
  end

  @impl true
  def handle_event("update_settings", %{"latitude" => lat, "longitude" => lon, "timezone" => tz}, socket) do
    case Settings.update_location(lat, lon, tz) do
      {:ok, updated} ->
        socket =
          socket
          |> assign(:latitude, Float.to_string(updated.latitude))
          |> assign(:longitude, Float.to_string(updated.longitude))
          |> assign(:timezone, updated.timezone)
          |> assign(:error, nil)
          |> assign(:success, "Settings updated successfully! Prayer times will be recalculated.")
          |> push_event("clear-success", %{})

        {:noreply, socket}

      {:error, reason} ->
        {:noreply, assign(socket, error: reason, success: nil)}
    end
  end

  @impl true
  def handle_event("clear_messages", _params, socket) do
    {:noreply, assign(socket, error: nil, success: nil)}
  end

  # Template is in settings_live.html.heex
end
