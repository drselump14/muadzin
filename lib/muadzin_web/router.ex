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

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", MuadzinWeb do
    pipe_through :browser

    live "/", PrayerTimesLive, :index
  end

  scope "/api", MuadzinWeb.Api do
    pipe_through :api

    get "/next-prayer", PrayerController, :next_prayer
    get "/prayers", PrayerController, :all_prayers
  end
end
