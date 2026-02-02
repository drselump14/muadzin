defmodule Muadzin.AudioPlayer do
  @moduledoc """
  GenServer responsible for playing audio files.
  Completely independent from the prayer schedule.
  """

  use GenServer
  use TypedStruct

  require Logger

  typedstruct do
    field(:audio_port, port())
    field(:playing, boolean(), default: false)
    field(:current_file, String.t())
    field(:os_pid, integer())
  end

  ## Public API

  def start_link(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, %{}, name: name)
  end

  @doc """
  Play an audio file. Automatically plays dua after azan finishes.
  Options:
  - `interruptible: true` - Allow stopping mid-playback
  - `callback_pid: pid` - Send completion message to this process
  """
  def play(filename, opts \\ []) do
    GenServer.cast(__MODULE__, {:play, filename, opts})
  end

  @doc """
  Stop currently playing audio
  """
  def stop do
    GenServer.cast(__MODULE__, :stop)
  end

  @doc """
  Check if audio is currently playing
  """
  def playing? do
    GenServer.call(__MODULE__, :playing?)
  end

  ## GenServer Callbacks

  @impl true
  def init(_opts) do
    setup_audio()
    {:ok, %__MODULE__{playing: false}}
  end

  @impl true
  def handle_cast({:play, filename, _opts}, %{playing: true} = state) do
    Logger.warning("Audio already playing, ignoring new play request for #{filename}")
    {:noreply, state}
  end

  @impl true
  def handle_cast({:play, filename, _opts}, state) do
    # Get the appropriate filename (test or original based on config)
    filename = get_audio_filename(filename)

    path = Path.join(:code.priv_dir(:muadzin), filename)
    audio_player_cmd = Application.get_env(:muadzin, :audio_player_cmd)
    audio_player_args = Application.get_env(:muadzin, :audio_player_args)

    Logger.info("Playing audio: #{filename}")
    debug_log("Playing: #{format_audio_name(filename)}")
    broadcast_status(:started, filename)

    case System.find_executable(audio_player_cmd) do
      nil ->
        Logger.error("Audio player executable not found: #{audio_player_cmd}")
        {:noreply, state}

      executable_path ->
        # Spawn audio process
        port =
          Port.open({:spawn_executable, executable_path}, [
            :binary,
            :exit_status,
            args: audio_player_args ++ [path]
          ])

        port_info = Port.info(port)
        os_pid = Keyword.get(port_info, :os_pid)

        Logger.debug("Audio port opened: #{inspect(port)}, OS PID: #{inspect(os_pid)}")

        # Schedule timeout
        Process.send_after(self(), {:audio_timeout, filename}, 600_000)

        {:noreply,
         %{
           state
           | playing: true,
             audio_port: port,
             current_file: filename,
             os_pid: os_pid
         }}
    end
  end

  @impl true
  def handle_cast(:stop, %{playing: false} = state) do
    {:noreply, state}
  end

  @impl true
  def handle_cast(:stop, %{audio_port: port, os_pid: os_pid, current_file: filename} = state) do
    Logger.info("Stopping audio: #{filename}")
    debug_log("Stopped: #{format_audio_name(filename)}")

    # Kill the OS process directly
    if os_pid do
      Logger.debug("Killing OS process #{os_pid}")
      System.cmd("kill", ["-9", "#{os_pid}"])
    end

    # Close the port
    if port do
      Port.close(port)

      # Drain any remaining port messages
      receive do
        {^port, _} -> :ok
      after
        0 -> :ok
      end
    end

    # Fallback: Kill all audio processes
    Task.start(fn ->
      Process.sleep(200)

      audio_cmd = Application.get_env(:muadzin, :audio_player_cmd)

      if audio_cmd do
        basename = Path.basename(audio_cmd)

        case System.cmd("pkill", ["-9", basename]) do
          {_, 0} -> Logger.debug("Fallback pkill succeeded")
          _ -> :ok
        end
      end
    end)

    broadcast_status(:stopped, filename)

    {:noreply, %{state | playing: false, audio_port: nil, current_file: nil, os_pid: nil}}
  end

  @impl true
  def handle_call(:playing?, _from, state) do
    {:reply, state.playing, state}
  end

  # Audio finished naturally
  @impl true
  def handle_info(
        {port, {:exit_status, status}},
        %{audio_port: port, current_file: filename} = state
      ) do
    Logger.info("Audio #{filename} finished with status: #{status}")

    # Check if this was an azan file - if so, play dua next
    if is_azan_file?(filename) do
      Logger.info("Azan finished, playing dua next")
      debug_log("Finished: #{format_audio_name(filename)}")
      debug_log("Playing: Dua (after azan)")

      # Reset state and play dua
      new_state = %{state | playing: false, audio_port: nil, current_file: nil, os_pid: nil}
      GenServer.cast(self(), {:play, "dua-after-the-azan.wav", []})

      # Close port after triggering dua playback
      close_port_safely(port)

      {:noreply, new_state}
    else
      # Not an azan file (could be dua or other), broadcast finished
      debug_log("Finished: #{format_audio_name(filename)}")
      broadcast_status(:finished, filename)

      # Close port
      close_port_safely(port)

      {:noreply, %{state | playing: false, audio_port: nil, current_file: nil, os_pid: nil}}
    end
  end

  # Audio timeout
  @impl true
  def handle_info({:audio_timeout, filename}, %{playing: true, current_file: current_file} = state) do
    if filename == current_file do
      Logger.warning("Audio playback timeout for #{filename}")
      GenServer.cast(self(), :stop)
    end

    {:noreply, state}
  end

  @impl true
  def handle_info({:audio_timeout, _filename}, state) do
    # Timeout for old playback or not playing, ignore
    {:noreply, state}
  end

  ## Private Functions

  defp setup_audio do
    # Only run audio setup on target (not on host)
    if Application.get_env(:muadzin, :target) != :host do
      System.cmd("amixer", ["cset", "numid=3", "1"])
      System.cmd("amixer", ["cset", "numid=1", "90%"])
    end
  end

  defp broadcast_status(status, filename) do
    Phoenix.PubSub.broadcast(
      Muadzin.PubSub,
      "audio_player",
      {:audio_status, status, filename}
    )
  end

  defp is_azan_file?(filename) do
    filename in ["azan.wav", "azan-fajr.wav"]
  end

  defp debug_log(message) do
    Phoenix.PubSub.broadcast(
      Muadzin.PubSub,
      "prayer_times",
      {:debug_log, message}
    )
  end

  defp format_audio_name("azan.wav"), do: "Azan"
  defp format_audio_name("azan-test.wav"), do: "Azan"
  defp format_audio_name("azan-fajr.wav"), do: "Azan (Fajr)"
  defp format_audio_name("azan-fajr-test.wav"), do: "Azan (Fajr)"
  defp format_audio_name("dua-after-the-azan.wav"), do: "Dua"
  defp format_audio_name("dua-after-the-azan-test.wav"), do: "Dua"
  defp format_audio_name(filename), do: filename

  defp get_audio_filename(filename) do
    if Application.get_env(:muadzin, :use_test_audio, false) do
      # Add -test suffix before .wav extension
      String.replace(filename, ".wav", "-test.wav")
    else
      filename
    end
  end

  defp close_port_safely(port) do
    # Check if port is still open before closing
    if Port.info(port) do
      try do
        Port.close(port)
      rescue
        ArgumentError -> :ok
      end
    end
  end
end
