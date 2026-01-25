defmodule Muadzin.PrayerTimes do
  @moduledoc """
  Context module for prayer times functionality.
  Provides functions to query the Scheduler state and subscribe to updates.
  """

  alias Muadzin.Scheduler

  @doc """
  Get the current state from the Scheduler.
  Returns the Scheduler state containing prayer times, next prayer, etc.
  """
  def get_current_state do
    Scheduler.get_state()
  end

  @doc """
  Format time remaining in minutes to a human-readable string.
  Examples:
    - 45 minutes -> "45m"
    - 90 minutes -> "1h 30m"
    - 120 minutes -> "2h"
  """
  def format_time_remaining(minutes) when minutes < 60 do
    "#{minutes}m"
  end

  def format_time_remaining(minutes) do
    hours = div(minutes, 60)
    remaining_minutes = rem(minutes, 60)

    if remaining_minutes == 0 do
      "#{hours}h"
    else
      "#{hours}h #{remaining_minutes}m"
    end
  end

  @doc """
  Subscribe to prayer times updates via PubSub.
  Call this from LiveView mount to receive {:prayer_times_updated, state} messages.
  """
  def subscribe do
    Phoenix.PubSub.subscribe(Muadzin.PubSub, "prayer_times")
  end
end
