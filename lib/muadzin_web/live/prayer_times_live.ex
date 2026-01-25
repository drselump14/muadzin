defmodule MuadzinWeb.PrayerTimesLive do
  use MuadzinWeb, :live_view

  alias Muadzin.PrayerTimes

  @impl true
  def mount(_params, _session, socket) do
    # Subscribe to prayer times updates
    if connected?(socket) do
      PrayerTimes.subscribe()
      # Send a tick message every 60 seconds to update the countdown
      Process.send_after(self(), :tick, 60_000)
    end

    # Get initial state
    state = PrayerTimes.get_current_state()

    socket =
      socket
      |> assign_state(state)
      |> assign(azan_playing: state.azan_playing, current_azan_prayer: nil)

    {:ok, socket}
  end

  @impl true
  def handle_info({:prayer_times_updated, state}, socket) do
    {:noreply, assign_state(socket, state)}
  end

  @impl true
  def handle_info(:tick, socket) do
    # Refresh state every minute
    state = PrayerTimes.get_current_state()
    # Schedule next tick
    Process.send_after(self(), :tick, 60_000)
    {:noreply, assign_state(socket, state)}
  end

  @impl true
  def handle_info({:azan_status, :started, prayer_name}, socket) do
    {:noreply, assign(socket, azan_playing: true, current_azan_prayer: prayer_name)}
  end

  @impl true
  def handle_info({:azan_status, :stopped, _prayer_name}, socket) do
    {:noreply, assign(socket, azan_playing: false, current_azan_prayer: nil)}
  end

  @impl true
  def handle_event("stop_azan", _params, socket) do
    Muadzin.Scheduler.stop_azan()
    {:noreply, socket}
  end

  defp assign_state(socket, state) do
    assign(socket,
      today_prayer_time: state.today_prayer_time,
      next_prayer_name: state.next_prayer_name,
      current_prayer_name: state.current_prayer_name,
      time_to_azan: state.time_to_azan,
      time_to_azan_formatted: PrayerTimes.format_time_remaining(state.time_to_azan)
    )
  end

  defp format_prayer_name(prayer_name) do
    prayer_name
    |> Atom.to_string()
    |> String.capitalize()
  end

  defp format_time(datetime) do
    # Convert from UTC to Tokyo timezone before formatting
    {:ok, tokyo_time} = DateTime.shift_zone(datetime, "Asia/Tokyo")
    Calendar.strftime(tokyo_time, "%I:%M %p")
  end

  # Template is defined in prayer_times_live.html.heex
end
