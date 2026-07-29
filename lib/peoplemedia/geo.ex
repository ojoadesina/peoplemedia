defmodule Peoplemedia.Geo do
  @moduledoc """
  Coordinates in, a country out — behind a name, so the tests do not phone
  Strasbourg.

  THE INDIRECTION EARNS ITS KEEP HERE and would not in most places. This is the
  only outbound call the app makes, and a test that exercises the sign-up flow
  would otherwise hit a public service run by volunteers, on every run, from
  every machine — slow, flaky offline, and rude. `config/test.exs` points this
  at a stub that answers instantly and truthfully enough.
  """
  @callback reverse_geocode(float(), float()) ::
              {:ok, %{country: String.t(), country_code: String.t()}} | {:error, term()}

  @doc "Whoever is answering this question in this environment."
  def reverse_geocode(lat, lng), do: impl().reverse_geocode(lat, lng)

  defp impl,
    do: Application.get_env(:peoplemedia, :geocoder, Peoplemedia.Geo.Nominatim)
end
