defmodule RM.FIRST.Region do
  use Ecto.Schema
  import Ecto.Query

  alias RM.Local.Team

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "first_regions" do
    field :abbreviation, :string
    field :code, :string
    field :description, :string
    field :has_leagues, :boolean, default: false
    field :name, :string
    timestamps type: :utc_datetime_usec

    has_many :teams, Team

    embeds_one :stats, Stats, on_replace: :delete, primary_key: false do
      field :team_count, :integer, default: 0
    end
  end

  def team_count_update_query(region_ids) do
    count_query =
      from(__MODULE__, as: :region)
      |> where([region: r], r.id in ^region_ids)
      |> join(:left, [region: r], t in assoc(r, :teams), as: :team)
      |> group_by([region: r], r.id)
      |> select([region: r, team: t], %{id: r.id, count: count(t.id)})

    from(__MODULE__, as: :region)
    |> join(:inner, [region: r], s in subquery(count_query), on: s.id == r.id, as: :counts)
    |> update([region: r, counts: c],
      set: [
        stats: fragment("jsonb_set(?, '{team_count}', ?::varchar::jsonb)", r.stats, c.count)
      ]
    )
  end
end
