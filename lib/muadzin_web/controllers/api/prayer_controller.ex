defmodule MuadzinWeb.Api.PrayerController do
  use MuadzinWeb, :controller

  alias Muadzin.PrayerTimes

  def next_prayer(conn, _params) do
    state = PrayerTimes.get_current_state()

    next_prayer_time =
      state.today_prayer_time
      |> Azan.PrayerTime.time_for_prayer(state.next_prayer_name)

    # Convert to Tokyo timezone for display
    {:ok, tokyo_time} = DateTime.shift_zone(next_prayer_time, "Asia/Tokyo")

    json(conn, %{
      next_prayer_name: state.next_prayer_name,
      next_prayer_time: tokyo_time,
      time_to_azan_minutes: state.time_to_azan,
      time_to_azan_formatted: PrayerTimes.format_time_remaining(state.time_to_azan),
      current_prayer_name: state.current_prayer_name,
      azan_playing: state.azan_playing
    })
  end

  def all_prayers(conn, _params) do
    state = PrayerTimes.get_current_state()

    prayers = [:fajr, :sunrise, :dhuhr, :asr, :maghrib, :isha]
    |> Enum.map(fn prayer_name ->
      utc_time = Azan.PrayerTime.time_for_prayer(state.today_prayer_time, prayer_name)
      {:ok, tokyo_time} = DateTime.shift_zone(utc_time, "Asia/Tokyo")

      %{
        name: prayer_name,
        time: tokyo_time,
        is_current: prayer_name == state.current_prayer_name,
        is_next: prayer_name == state.next_prayer_name
      }
    end)

    json(conn, %{
      prayers: prayers,
      next_prayer_name: state.next_prayer_name,
      current_prayer_name: state.current_prayer_name,
      time_to_next_azan_minutes: state.time_to_azan,
      azan_playing: state.azan_playing
    })
  end

  def stop_azan(conn, _params) do
    Muadzin.Scheduler.stop_azan()

    json(conn, %{
      success: true,
      message: "Azan stopped"
    })
  end

  def trigger_azan(conn, _params) do
    Muadzin.Scheduler.trigger_azan()

    json(conn, %{
      success: true,
      message: "Azan triggered"
    })
  end
end
