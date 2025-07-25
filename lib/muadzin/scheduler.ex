defmodule Muadzin.Scheduler do
  @moduledoc """
  Documentation for Muadzin Prayer.
  """

  @latitude 35.67220046284479
  @longitude 139.90246423845966
  @timezone "Asia/Tokyo"

  alias Azan.PrayerTime

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
  end

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{})
  end

  @impl true
  def init(_state) do
    setup_audio()

    state =
      %__MODULE__{next_prayer_name: next_prayer_name, time_to_azan: time_to_azan} =
      generate_state()

    schedule_azan(next_prayer_name, time_to_azan)
    {:ok, state}
  end

  @impl true
  def handle_info(:play_azan, %__MODULE__{next_prayer_name: current_prayer_name}) do
    play_azan(current_prayer_name)
    play_dua()

    new_state =
      %__MODULE__{next_prayer_name: next_prayer_name, time_to_azan: time_to_azan} =
      generate_state()

    schedule_azan(next_prayer_name, time_to_azan)
    {:noreply, %{new_state | azan_performed_at: Timex.now()}}
  end

  @impl true
  def handle_call(:fetch_state, _, state) do
    {:reply, state, state}
  end

  def setup_audio() do
    System.cmd("amixer", ["cset", "numid=3", "1"])
    System.cmd("amixer", ["cset", "numid=1", "90%"])
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

  def play_audio(filename) do
    path = Path.join(:code.priv_dir(:muadzin), filename)
    audio_player_cmd = Application.get_env(:muadzin, :audio_player_cmd)
    audio_player_args = Application.get_env(:muadzin, :audio_player_args)

    System.cmd(audio_player_cmd, audio_player_args ++ [path])
  end

  def generate_coordinate() do
    %Azan.Coordinate{latitude: @latitude, longitude: @longitude}
  end

  def generate_params() do
    Azan.CalculationMethod.muslim_world_league()
  end

  # @spec fetch_prayer_time(:today | :tomorrow) :: PrayerTime.t()
  def fetch_prayer_time(:today) do
    date = Timex.now() |> Timex.Timezone.convert(@timezone) |> DateTime.to_date()
    generate_coordinate() |> PrayerTime.find(date, generate_params())
  end

  def fetch_prayer_time(:tomorrow) do
    date = Timex.now() |> DateTime.to_date() |> Date.add(1)
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
      |> Timex.diff(Timex.now(), :minutes)

    {next_prayer_name, time_to_azan, prayer_time}
  end

  def calc_time_to_azan(next_prayer_name, prayer_time) do
    Logger.info("Next prayer: #{next_prayer_name}")
    Logger.info(prayer_time |> inspect())

    time_to_azan =
      prayer_time
      |> PrayerTime.time_for_prayer(next_prayer_name)
      |> Timex.diff(Timex.now(), :minutes)

    {next_prayer_name, time_to_azan, prayer_time}
  end

  @spec generate_state() :: %__MODULE__{}
  def generate_state do
    today_prayer_time = fetch_prayer_time(:today)
    next_prayer_name = today_prayer_time |> PrayerTime.next_prayer(Timex.now())
    current_prayer_name = today_prayer_time |> PrayerTime.current_prayer(Timex.now())

    # Recalculate the prayer time
    {next_prayer_name, time_to_azan, prayer_time} =
      calc_time_to_azan(next_prayer_name, today_prayer_time)

    %__MODULE__{
      today_prayer_time: prayer_time,
      next_prayer_name: next_prayer_name,
      current_prayer_name: current_prayer_name,
      time_to_azan: time_to_azan,
      scheduled_at: Timex.now()
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
