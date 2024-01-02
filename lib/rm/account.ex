defmodule RM.Account do
  alias RM.Repo

  def regions_for_user(user) do
    user = Repo.preload(user, :regions)
    user.regions
  end
end
