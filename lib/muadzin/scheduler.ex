defmodule Muadzin.Scheduler do
  @moduledoc """
  Documentation for Muadzin Prayer.
  """

  alias Azan.PrayerTime
  alias Muadzin.Settings

  use GenServer
  use TypedStruct

  require Logger

  typedstruct do
    field(:today_prayer_time, PrayerTime.t(), enforce: true)
    field(:next_prayer_name, :atom, enforce: true)
    field(:current_prayer_name, :atom, enforce: true)
    field(:time_to_azan, :integer, enforce: true)
    field(:scheduled_at, DateTime.t(), enforce: true)
    field(:azan_performed_at, DateTime.t())
    field(:azan_playing, boolean(), default: false)
  end

  def start_link(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, %{}, name: name)
  end

  @impl true
  def init(_state) do
    # Subscribe to settings updates
    Phoenix.PubSub.subscribe(Muadzin.PubSub, "settings")

    # Subscribe to audio player status
    Phoenix.PubSub.subscribe(Muadzin.PubSub, "audio_player")

    state =
      %__MODULE__{next_prayer_name: next_prayer_name, time_to_azan: time_to_azan} =
      generate_state()

    schedule_azan(next_prayer_name, time_to_azan)
    broadcast_state_update(state)
    {:ok, state}
  end

  @impl true
  def handle_info(:play_azan, %__MODULE__{next_prayer_name: current_prayer_name} = state) do
    debug_log("Playing azan for #{current_prayer_name}")

    # Play azan audio using AudioPlayer
    play_azan_audio(current_prayer_name)

    broadcast_azan_status(:started, current_prayer_name)

    {:noreply, %{state | azan_playing: true}}
  end

  # Handle test azan trigger (manual trigger from API/UI)
  @impl true
  def handle_info(:play_test_azan, %__MODULE__{next_prayer_name: current_prayer_name} = state) do
    debug_log("Playing TEST azan for #{current_prayer_name}")

    # Play azan audio using AudioPlayer (as a test, doesn't affect schedule)
    play_azan_audio(current_prayer_name)

    # Don't set azan_playing for test azan - this keeps it independent from schedule
    {:noreply, state}
  end

  # Handle audio player status updates
  @impl true
  def handle_info({:audio_status, :started, _filename}, state) do
    # Audio started playing (could be from test trigger or scheduled azan)
    broadcast_azan_status(:started, state.next_prayer_name)
    {:noreply, state}
  end

  @impl true
  def handle_info({:audio_status, :finished, _filename}, %{azan_playing: true} = _state) do
    # Scheduled azan finished - reschedule to next prayer
    debug_log("Scheduled azan finished - rescheduling to next prayer")

    broadcast_azan_status(:stopped, nil)

    updated_state =
      reschedule_next_azan(%{
        azan_performed_at: DateTime.utc_now(),
        azan_playing: false
      })

    broadcast_state_update(updated_state)
    {:noreply, updated_state}
  end

  @impl true
  def handle_info({:audio_status, :finished, _filename}, %{azan_playing: false} = state) do
    # Test azan finished - no rescheduling needed
    debug_log("Test azan finished - schedule unaffected")
    {:noreply, state}
  end

  @impl true
  def handle_info({:audio_status, :stopped, _filename}, %{azan_playing: true} = _state) do
    # Scheduled azan was stopped manually - recalculate schedule
    debug_log("Scheduled azan stopped - recalculating schedule")

    broadcast_azan_status(:stopped, nil)

    updated_state = reschedule_next_azan(%{azan_playing: false})
    broadcast_state_update(updated_state)
    {:noreply, updated_state}
  end

  @impl true
  def handle_info({:audio_status, :stopped, _filename}, %{azan_playing: false} = state) do
    # Test azan was stopped - no action needed
    {:noreply, state}
  end

  @impl true
  def handle_info({:settings_updated, _settings}, _state) do
    Logger.info("Settings updated, recalculating prayer times")

    # Regenerate state with new location settings
    new_state = reschedule_next_azan()
    {:noreply, new_state}
  end

  @impl true
  def handle_cast(:stop_azan, state) do
    debug_log("Stop azan called")

    # Simply tell AudioPlayer to stop - it will broadcast status which we'll handle
    Muadzin.AudioPlayer.stop()

    {:noreply, state}
  end

  @impl true
  def handle_call(:fetch_state, _, state) do
    {:reply, state, state}
  end

  @doc """
  Get the current state of the scheduler
  """
  def get_state(server \\ __MODULE__) do
    GenServer.call(server, :fetch_state)
  end

  defp broadcast_state_update(state) do
    Phoenix.PubSub.broadcast(
      Muadzin.PubSub,
      "prayer_times",
      {:prayer_times_updated, state}
    )
  end

  # Regenerate state, schedule next azan, and broadcast update.
  # Optionally merge additional fields into the new state.
  defp reschedule_next_azan(additional_fields \\ %{}) do
    new_state =
      %__MODULE__{next_prayer_name: next_prayer_name, time_to_azan: time_to_azan} =
      generate_state()

    schedule_azan(next_prayer_name, time_to_azan)

    updated_state = Map.merge(new_state, additional_fields)
    broadcast_state_update(updated_state)
    updated_state
  end

  defp broadcast_azan_status(status, prayer_name) do
    Phoenix.PubSub.broadcast(
      Muadzin.PubSub,
      "prayer_times",
      {:azan_status, status, prayer_name}
    )
  end

  defp debug_log(message) do
    Logger.info(message)
    # Also broadcast to web UI for debugging
    Phoenix.PubSub.broadcast(
      Muadzin.PubSub,
      "prayer_times",
      {:debug_log, message}
    )
  end

  def trigger_azan(server \\ __MODULE__) do
    debug_log("Trigger TEST azan called (will not affect schedule)")
    Process.send(server, :play_test_azan, [])
    :ok
  end

  @doc """
  Stop the currently playing azan
  """
  def stop_azan(server \\ __MODULE__) do
    GenServer.cast(server, :stop_azan)
  end

  # Play azan audio using the AudioPlayer GenServer
  defp play_azan_audio(:fajr) do
    Muadzin.AudioPlayer.play("azan-fajr.wav")
  end

  defp play_azan_audio(prayer_name) when prayer_name in [:sunrise, :sunset] do
    Logger.info("Skipping azan for #{prayer_name}")
  end

  defp play_azan_audio(_prayer_name) do
    Muadzin.AudioPlayer.play("azan.wav")
  end

  def generate_coordinate() do
    %Azan.Coordinate{latitude: Settings.get_latitude(), longitude: Settings.get_longitude()}
  end

  def generate_params() do
    Azan.CalculationMethod.muslim_world_league()
  end

  # @spec fetch_prayer_time(:today | :tomorrow) :: PrayerTime.t()
  def fetch_prayer_time(:today) do
    timezone = Settings.get_timezone()
    date = DateTime.utc_now() |> Timex.Timezone.convert(timezone) |> DateTime.to_date()
    generate_coordinate() |> PrayerTime.find(date, generate_params())
  end

  def fetch_prayer_time(:tomorrow) do
    timezone = Settings.get_timezone()

    date =
      DateTime.utc_now() |> Timex.Timezone.convert(timezone) |> DateTime.to_date() |> Date.add(1)

    generate_coordinate() |> PrayerTime.find(date, generate_params())
  end

  @doc """
  Schedule azan for the next prayer
  The :none prayer is used to indicate that the next prayer is tomorrow
  """
  def calc_time_to_azan(:none, _prayer_time) do
    next_prayer_name = :fajr
    prayer_time = fetch_prayer_time(:tomorrow)

    Logger.info("Next prayer: #{next_prayer_name}")
    Logger.info(prayer_time |> inspect())

    time_to_azan =
      prayer_time
      |> PrayerTime.time_for_prayer(next_prayer_name)
      |> Timex.diff(DateTime.utc_now(), :minutes)

    {next_prayer_name, time_to_azan, prayer_time}
  end

  def calc_time_to_azan(next_prayer_name, prayer_time) do
    Logger.info("Next prayer: #{next_prayer_name}")
    Logger.info(prayer_time |> inspect())

    time_to_azan =
      prayer_time
      |> PrayerTime.time_for_prayer(next_prayer_name)
      |> Timex.diff(DateTime.utc_now(), :minutes)

    {next_prayer_name, time_to_azan, prayer_time}
  end

  @spec generate_state() :: %__MODULE__{}
  def generate_state do
    today_prayer_time = fetch_prayer_time(:today)
    next_prayer_name = today_prayer_time |> PrayerTime.next_prayer(DateTime.utc_now())
    current_prayer_name = today_prayer_time |> PrayerTime.current_prayer(DateTime.utc_now())

    # Recalculate the prayer time
    {next_prayer_name, time_to_azan, prayer_time} =
      calc_time_to_azan(next_prayer_name, today_prayer_time)

    %__MODULE__{
      today_prayer_time: prayer_time,
      next_prayer_name: next_prayer_name,
      current_prayer_name: current_prayer_name,
      time_to_azan: time_to_azan,
      scheduled_at: DateTime.utc_now(),
      azan_playing: false
    }
  end

  @spec schedule_azan(atom(), integer()) :: any()
  defp schedule_azan(
         next_prayer_name,
         time_to_azan
       ) do
    Logger.info("Next prayer: #{next_prayer_name}, time to azan: #{time_to_azan} minutes")

    Process.send_after(
      self(),
      :play_azan,
      time_to_azan * 1000 * 60
    )
  end
end
