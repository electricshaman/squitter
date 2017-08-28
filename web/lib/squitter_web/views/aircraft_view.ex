defmodule Squitter.Web.AircraftView do
  use Squitter.Web, :view

  def site_location do
    # TODO: Pull this from the Squitter app
    [35.4690, -97.5085]
  end
end
