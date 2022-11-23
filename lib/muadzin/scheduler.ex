defmodule Muadzin.Scheduler do
  @moduledoc """
  Documentation for Muadzin Prayer.
  """

  @coordinate %Azan.Coordinate{latitude: 35.67220046284479, longitude: 139.90246423845966}
  @params Azan.CalculationMethod.muslim_world_league()

  alias Azan.PrayerTime

  use GenServer
  use TypedStruct

  require Logger

  typedstruct do
    field(:today_prayer_time, PrayerTime.t(), enforce: true)
    field(:next_prayer, :atom, enforce: true)
    field(:current_prayer, :atom, enforce: true)
    field(:time_to_azan, :integer, enforce: true)
    field(:scheduled_time, Time.t(), enforce: true)
  end

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{})
  end

  @impl true
  def init(state) do
    setup_audio()
    schedule_azan()
    {:ok, state}
  end

  @impl true
  def handle_info(current_prayer, state) do
    play_azan(current_prayer)

    schedule_azan()
    {:noreply, state}
  end

  def setup_audio() do
    System.cmd("amixer", ["cset", "numid=3", "1"])
    System.cmd("amixer", ["cset", "numid=1", "90%"])
  end

  def play_azan(:fajr) do
    IO.puts("playing fajr azan")
    azan_audio = Path.join(:code.priv_dir(:muadzin), "azan-fajr.mp3")
    AudioPlayer.play(azan_audio)
  end

  def play_azan(_) do
    IO.puts("playing azan")
    azan_audio = Path.join(:code.priv_dir(:muadzin), "azan.mp3")
    AudioPlayer.play(azan_audio)
  end

  def should_azan_now?(prayer_name) do
    prayer_time = fetch_prayer_time(:today) |> Map.get(prayer_name)
    now = DateTime.utc_now()
    prayer_time |> DateTime.diff(now, :second) |> abs() < 60
  end

  def fetch_prayer_time(:today) do
    date = DateTime.utc_now() |> DateTime.to_date()
    @coordinate |> PrayerTime.find(date, @params)
  end

  def fetch_prayer_time(:tomorrow) do
    date = DateTime.utc_now() |> DateTime.to_date() |> Date.add(1)
    @coordinate |> PrayerTime.find(date, @params)
  end

  def calc_time_to_azan(:none, _prayer_time) do
    next_prayer = :fajr

    time_to_azan =
      fetch_prayer_time(:tomorrow)
      |> PrayerTime.time_for_prayer(next_prayer)
      |> Timex.diff(Timex.now(), :minutes)

    {next_prayer, time_to_azan}
  end

  def calc_time_to_azan(next_prayer, today_prayer_time) do
    time_to_azan =
      today_prayer_time
      |> PrayerTime.time_for_prayer(next_prayer)
      |> Timex.diff(Timex.now(), :minutes)

    {next_prayer, time_to_azan}
  end

  def get_next_prayer() do
    today_prayer_time = fetch_prayer_time(:today)
    next_prayer = today_prayer_time |> PrayerTime.next_prayer(Timex.now())
  end

  defp schedule_azan() do
    today_prayer_time = fetch_prayer_time(:today)
    next_prayer = today_prayer_time |> PrayerTime.next_prayer(Timex.now())

    {next_prayer, time_to_azan} = calc_time_to_azan(next_prayer, today_prayer_time)

    IO.puts("Next prayer: #{next_prayer}, time to azan: #{time_to_azan} minutes")

    Process.send_after(
      self(),
      next_prayer,
      time_to_azan * 1000 * 60
    )
  end
end
