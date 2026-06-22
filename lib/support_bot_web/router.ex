defmodule SupportBotWeb.Router do
  use SupportBotWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {SupportBotWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  scope "/", SupportBotWeb do
    pipe_through :browser

    get "/", PageController, :home
    live "/chat", ChatLive
    live "/tickets", TicketLive.Index
    live "/tickets/:id", TicketLive.Show
    live "/kb", KBLive.Index
    live "/kb/:slug", KBLive.Show
  end

  if Application.compile_env(:support_bot, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser
      live_dashboard "/dashboard", metrics: SupportBotWeb.Telemetry
    end
  end
end
