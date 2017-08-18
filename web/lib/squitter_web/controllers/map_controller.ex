defmodule Squitter.Web.MapController do
  use Squitter.Web, :controller

  def index(conn, _params) do
    render conn, "index.html"
  end
end
