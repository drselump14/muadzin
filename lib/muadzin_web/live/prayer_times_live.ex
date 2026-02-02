defmodule MuadzinWeb.PrayerTimesLive do
  use MuadzinWeb, :live_view

  alias Muadzin.PrayerTimes

  @impl true
  def mount(_params, _session, socket) do
    # Subscribe to prayer times updates
    if connected?(socket) do
      PrayerTimes.subscribe()
    end

    # Get initial state
    state = PrayerTimes.get_current_state()

    socket =
      socket
      |> assign_state(state)
      |> assign(azan_playing: Muadzin.AudioPlayer.playing?(), current_azan_prayer: nil, debug_logs: [], show_debug: false)

    {:ok, socket}
  end

  @impl true
  def handle_info({:prayer_times_updated, state}, socket) do
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
  def handle_info({:debug_log, message}, socket) do
    # Add to debug logs, keep last 50
    debug_logs = [%{timestamp: DateTime.utc_now(), message: message} | socket.assigns.debug_logs]
    |> Enum.take(50)

    {:noreply, assign(socket, debug_logs: debug_logs)}
  end

  @impl true
  def handle_event("stop_azan", _params, socket) do
    Muadzin.Scheduler.stop_azan()
    {:noreply, socket}
  end

  @impl true
  def handle_event("trigger_azan", _params, socket) do
    Muadzin.Scheduler.trigger_azan()
    {:noreply, socket}
  end

  @impl true
  def handle_event("clear_logs", _params, socket) do
    {:noreply, assign(socket, debug_logs: [])}
  end

  @impl true
  def handle_event("toggle_debug", _params, socket) do
    {:noreply, assign(socket, show_debug: !socket.assigns.show_debug)}
  end

  defp assign_state(socket, state) do
    # Get next prayer time for client-side countdown
    next_prayer_time = Azan.PrayerTime.time_for_prayer(state.today_prayer_time, state.next_prayer_name)
    # Convert to ISO8601 string for JavaScript
    next_prayer_time_iso = DateTime.to_iso8601(next_prayer_time)

    # Calculate server-side as fallback
    time_to_azan = DateTime.diff(next_prayer_time, DateTime.utc_now(), :minute)
    time_to_azan_formatted = PrayerTimes.format_time_remaining(time_to_azan)

    assign(socket,
      today_prayer_time: state.today_prayer_time,
      next_prayer_name: state.next_prayer_name,
      current_prayer_name: state.current_prayer_name,
      next_prayer_time_iso: next_prayer_time_iso,
      time_to_azan_formatted: time_to_azan_formatted
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
