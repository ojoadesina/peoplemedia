defmodule Peoplemedia.Geo.Stub do
  @moduledoc """
  The geocoder, in tests. Answers from a small table of coordinates the tests
  actually use, and refuses everything else — so a test that means to exercise
  the failure path can, and one that drifts onto an unknown coordinate fails
  loudly rather than silently succeeding on a guess.
  """
  @behaviour Peoplemedia.Geo

  @places [
    {{60.17, 24.94}, %{country: "Finland", country_code: "fi"}},
    {{6.52, 3.37}, %{country: "Nigeria", country_code: "ng"}},
    {{64.15, -21.94}, %{country: "Iceland", country_code: "is"}}
  ]

  @impl true
  def reverse_geocode(lat, lng) do
    case Enum.find(@places, fn {{a, b}, _} ->
           round_to(a) == round_to(lat) and round_to(b) == round_to(lng)
         end) do
      {_, place} -> {:ok, place}
      nil -> {:error, :no_country}
    end
  end

  defp round_to(n), do: Float.round(n * 1.0, 2)
end
