defmodule MuadzinWeb.Router do
  use MuadzinWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {MuadzinWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  scope "/", MuadzinWeb do
    pipe_through :browser

    live "/", PrayerTimesLive, :index
  end
end
