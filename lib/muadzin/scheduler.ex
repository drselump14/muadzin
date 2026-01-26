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
    field(:audio_port, port())
    field(:azan_playing, boolean(), default: false)
    field(:azan_process_pid, pid())
    field(:azan_timer_ref, reference())
  end

  def start_link(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, %{}, name: name)
  end

  @impl true
  def init(_state) do
    setup_audio()

    # Subscribe to settings updates
    Phoenix.PubSub.subscribe(Muadzin.PubSub, "settings")

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

    broadcast_azan_status(:started, current_prayer_name)

    azan_pid = spawn(fn -> run_azan_sequence(current_prayer_name, self()) end)
    timer_ref = Process.send_after(self(), :azan_finished, 5 * 60 * 1000)

    {:noreply, %{state | azan_playing: true, azan_process_pid: azan_pid, azan_timer_ref: timer_ref}}
  end

  # Azan still playing - tell spawned process to continue with dua
  @impl true
  def handle_info({:check_continue_azan, pid}, %{azan_playing: true} = state) do
    send(pid, :continue)
    {:noreply, state}
  end

  # Azan was stopped manually - tell spawned process to stop
  @impl true
  def handle_info({:check_continue_azan, pid}, %{azan_playing: false} = state) do
    send(pid, :stop)
    {:noreply, state}
  end

  # Handle azan finished when it's actually playing (normal completion)
  @impl true
  def handle_info(:azan_finished, %{azan_playing: true, azan_timer_ref: timer_ref} = _state) do
    # Cancel the fallback timer if it exists
    if timer_ref, do: Process.cancel_timer(timer_ref)

    broadcast_azan_status(:stopped, nil)

    new_state =
      %__MODULE__{next_prayer_name: next_prayer_name, time_to_azan: time_to_azan} =
      generate_state()

    schedule_azan(next_prayer_name, time_to_azan)

    updated_state = %{
      new_state
      | azan_performed_at: DateTime.utc_now(),
        azan_playing: false,
        azan_process_pid: nil,
        azan_timer_ref: nil
    }

    broadcast_state_update(updated_state)
    {:noreply, updated_state}
  end

  # Handle azan finished when already stopped (ignore duplicate messages)
  @impl true
  def handle_info(:azan_finished, %{azan_playing: false} = state) do
    {:noreply, state}
  end

  @impl true
  def handle_info({:settings_updated, _settings}, _state) do
    Logger.info("Settings updated, recalculating prayer times")

    # Regenerate state with new location settings
    new_state =
      %__MODULE__{next_prayer_name: next_prayer_name, time_to_azan: time_to_azan} =
      generate_state()

    schedule_azan(next_prayer_name, time_to_azan)
    broadcast_state_update(new_state)
    {:noreply, new_state}
  end

  @impl true
  def handle_cast(:stop_azan, %{azan_process_pid: pid, azan_timer_ref: timer_ref} = state) do
    debug_log("Stop azan called")

    # Send stop message to the spawned azan process
    if pid && Process.alive?(pid) do
      send(pid, :stop_audio)
      debug_log("Sent :stop_audio to process #{inspect(pid)}")
    end

    # Fallback: Kill all audio processes (aplay, afplay, etc) in case message doesn't work
    Task.start(fn ->
      Process.sleep(200) # Give Port.close() a chance to work first

      audio_cmd = Application.get_env(:muadzin, :audio_player_cmd)
      if audio_cmd do
        basename = Path.basename(audio_cmd)
        case System.cmd("pkill", ["-9", basename]) do
          {_, 0} -> debug_log("Fallback pkill succeeded")
          _ -> :ok
        end
      end
    end)

    # Cancel the fallback timer
    if timer_ref, do: Process.cancel_timer(timer_ref)

    broadcast_azan_status(:stopped, nil)
    {:noreply, %{state | azan_playing: false, azan_process_pid: nil, azan_timer_ref: nil}}
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
    debug_log("Trigger azan called")
    Process.send(server, :play_azan, [])
    :ok
  end

  @doc """
  Stop the currently playing azan
  """
  def stop_azan(server \\ __MODULE__) do
    GenServer.cast(server, :stop_azan)
  end

  def setup_audio() do
    # Only run audio setup on target (not on host)
    if Application.get_env(:muadzin, :target) != :host do
      System.cmd("amixer", ["cset", "numid=3", "1"])
      System.cmd("amixer", ["cset", "numid=1", "90%"])
    end
  end

  defp run_azan_sequence(prayer_name, scheduler_pid) do
    case play_azan_interruptible(prayer_name, scheduler_pid) do
      :ok -> play_dua_if_allowed(scheduler_pid)
      :stopped -> debug_log("Azan stopped before completion")
      result -> Logger.warning("Unexpected azan result: #{inspect(result)}")
    end
  end

  defp play_dua_if_allowed(scheduler_pid) do
    send(scheduler_pid, {:check_continue_azan, self()})

    receive do
      :continue ->
        play_dua_interruptible(scheduler_pid)
        send(scheduler_pid, :azan_finished)

      :stop ->
        debug_log("Skipping dua (stopped)")

      :stop_audio ->
        debug_log("Skipping dua (stopped)")
    after
      1000 ->
        play_dua_interruptible(scheduler_pid)
        send(scheduler_pid, :azan_finished)
    end
  end

  defp play_azan_interruptible(:fajr, scheduler_pid) do
    play_audio_interruptible("azan-fajr.wav", scheduler_pid)
  end

  defp play_azan_interruptible(prayer_name, _scheduler_pid) when prayer_name in [:sunrise, :sunset] do
    Logger.info("Skipping azan for #{prayer_name}")
    :ok
  end

  defp play_azan_interruptible(_prayer_name, scheduler_pid) do
    play_audio_interruptible("azan.wav", scheduler_pid)
  end

  defp play_dua_interruptible(scheduler_pid) do
    play_audio_interruptible("dua-after-the-azan.wav", scheduler_pid)
  end

  def play_azan(:fajr) do
    Logger.info("playing fajr azan")
    play_audio("azan-fajr.wav")
  end

  def play_azan(prayer_name) when prayer_name in [:sunrise, :sunset] do
    Logger.info("Skip playing azan for sunset and sunrise")
  end

  def play_azan(_) do
    Logger.info("playing azan")
    play_audio("azan.wav")
  end

  def play_dua, do: play_audio("dua-after-the-azan.wav")

  defp play_audio_interruptible(filename, _scheduler_pid) do
    # Only play audio on target, not on host
    if Application.get_env(:muadzin, :target) != :host do
      path = Path.join(:code.priv_dir(:muadzin), filename)
      audio_player_cmd = Application.get_env(:muadzin, :audio_player_cmd)
      audio_player_args = Application.get_env(:muadzin, :audio_player_args)

      debug_log("Playing audio: #{filename}")

      # Resolve executable path
      case System.find_executable(audio_player_cmd) do
        nil ->
          Logger.error("Audio player executable not found: #{audio_player_cmd}")
          :error

        executable_path ->
          # Use Port.open to spawn process that can be killed
          port = Port.open({:spawn_executable, executable_path}, [
            :binary,
            :exit_status,
            args: audio_player_args ++ [path]
          ])

          # Get the OS process ID for killing if needed
          port_info = Port.info(port)
          os_pid = Keyword.get(port_info, :os_pid)
          debug_log("Port opened: #{inspect(port)}, OS PID: #{inspect(os_pid)}")

          # Wait for audio to finish or receive stop message
          result = receive do
            {^port, {:exit_status, status}} ->
              debug_log("Audio #{filename} finished with status: #{status}")
              Port.close(port)
              :ok

            :stop_audio ->
              debug_log("Stopping audio: #{filename}")

              # Kill the OS process directly with SIGKILL
              if os_pid do
                debug_log("Killing OS process #{os_pid}")
                System.cmd("kill", ["-9", "#{os_pid}"])
              end

              # Close the port
              Port.close(port)

              # Drain any remaining port messages
              receive do
                {^port, _} -> :ok
              after
                0 -> :ok
              end

              debug_log("Audio stopped successfully")
              :stopped
          after
            600_000 -> # 10 minute timeout
              Logger.warning("Audio playback timeout for #{filename}")
              Port.close(port)
              :timeout
          end

          result
      end
    else
      Logger.info("Skipping audio playback on host: #{filename}")
      :ok
    end
  end

  def play_audio(filename) do
    # Only play audio on target, not on host
    if Application.get_env(:muadzin, :target) != :host do
      path = Path.join(:code.priv_dir(:muadzin), filename)
      audio_player_cmd = Application.get_env(:muadzin, :audio_player_cmd)
      audio_player_args = Application.get_env(:muadzin, :audio_player_args)

      Logger.debug("Playing audio: #{filename}")

      # Resolve executable path (Port.open requires absolute path)
      case System.find_executable(audio_player_cmd) do
        nil ->
          Logger.error("Audio player executable not found: #{audio_player_cmd}")
          :error

        executable_path ->
          # Use Port.open to spawn process that can be killed
          port = Port.open({:spawn_executable, executable_path}, [
            :binary,
            :exit_status,
            args: audio_player_args ++ [path]
          ])

          # Wait for the audio to finish or process to be killed
          receive do
            {^port, {:exit_status, status}} ->
              Port.close(port)
              Logger.debug("Audio finished with status: #{status}")
              :ok
          after
            600_000 -> # 10 minute timeout
              Port.close(port)
              Logger.warning("Audio playback timeout for #{filename}")
              :timeout
          end
      end
    else
      Logger.info("Skipping audio playback on host: #{filename}")
      :ok
    end
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
