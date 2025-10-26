defmodule NewProjectWeb.PageController do
  use NewProjectWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
