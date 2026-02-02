defmodule Muadzin.Scheduler do
  @moduledoc """
  Documentation for Muadzin Prayer.
  """

  alias Azan.{CalculationMethod, Coordinate, PrayerTime}
  alias Muadzin.{AudioPlayer, Settings}

  use GenServer
  use TypedStruct

  require Logger

  typedstruct do
    field(:today_prayer_time, PrayerTime.t(), enforce: true)
    field(:next_prayer_name, :atom, enforce: true)
    field(:current_prayer_name, :atom, enforce: true)
    field(:time_to_azan, :integer, enforce: true)
    field(:scheduled_at, DateTime.t(), enforce: true)
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
  def handle_info(:play_azan, %__MODULE__{next_prayer_name: current_prayer_name} = _state) do
    debug_log("Playing azan for #{current_prayer_name}")

    # Play azan audio using AudioPlayer (will automatically play dua after)
    play_azan_audio(current_prayer_name)

    broadcast_azan_status(:started, current_prayer_name)

    # Immediately reschedule to next prayer
    updated_state = reschedule_next_azan()
    {:noreply, updated_state}
  end

  # Handle test azan trigger (manual trigger from API/UI)
  @impl true
  def handle_info(:play_test_azan, %__MODULE__{next_prayer_name: current_prayer_name} = state) do
    prayer_name_formatted = current_prayer_name |> Atom.to_string() |> String.capitalize()
    debug_log("Test azan: #{prayer_name_formatted}")

    # Play azan audio using AudioPlayer (as a test, doesn't affect schedule)
    play_azan_audio(current_prayer_name)

    # Don't set azan_playing for test azan - this keeps it independent from schedule
    {:noreply, state}
  end

  # Handle audio player status updates - just broadcast for UI
  @impl true
  def handle_info({:audio_status, :started, _filename}, state) do
    broadcast_azan_status(:started, state.next_prayer_name)
    {:noreply, state}
  end

  @impl true
  def handle_info({:audio_status, :finished, _filename}, state) do
    broadcast_azan_status(:stopped, nil)
    {:noreply, state}
  end

  @impl true
  def handle_info({:audio_status, :stopped, _filename}, state) do
    broadcast_azan_status(:stopped, nil)
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
    AudioPlayer.stop()

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
  defp reschedule_next_azan do
    new_state =
      %__MODULE__{next_prayer_name: next_prayer_name, time_to_azan: time_to_azan} =
      generate_state()

    schedule_azan(next_prayer_name, time_to_azan)

    broadcast_state_update(new_state)
    new_state
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
    AudioPlayer.play("azan-fajr.wav")
  end

  defp play_azan_audio(prayer_name) when prayer_name in [:sunrise, :sunset] do
    Logger.info("Skipping azan for #{prayer_name}")
  end

  defp play_azan_audio(_prayer_name) do
    AudioPlayer.play("azan.wav")
  end

  def generate_coordinate() do
    %Coordinate{latitude: Settings.get_latitude(), longitude: Settings.get_longitude()}
  end

  def generate_params() do
    CalculationMethod.muslim_world_league()
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
      scheduled_at: DateTime.utc_now()
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
