defmodule Peoplemedia.Geo.Nominatim do
  @moduledoc """
  Where somebody is, once, when their passport is issued.

  OpenStreetMap's Nominatim, over plain HTTP. No key, no account, no vendor —
  which matters more here than it looks: this is the only call this app makes to
  anywhere, and the alternative geocoders all want an identity to bill, which
  would mean this app's users had one.

  ## IT IS ASKED ONCE, AND ONLY FOR A COUNTRY

  The reference this is lifted from asked for a street and offered a list of
  addresses to pick from. This app has never shown anything finer than a
  country, so that is all that is read out of the answer — and everything else
  Nominatim returns is dropped on the floor rather than stored. A coordinate
  pair reaches this module and a country name leaves it; nothing in between is
  written down.

  ## THE NAME COMES FROM THE ISO CODE

  Nominatim's `country` field is whatever the local mapping community wrote, in
  whatever language — "Suomi", "Deutschland", "Nigeria". A list keyed on that
  would have the same country under two spellings the first time somebody's
  phone was set to another language. So the CODE is what is used, and the name
  is this app's own. That rule is the reference's and it is the one thing here
  worth copying exactly.

  ## THE USAGE POLICY

  Nominatim asks for no more than one request a second and a real User-Agent.
  One call per passport issued is human-paced by construction, so there is
  nothing to throttle — but the User-Agent is a courtesy that costs nothing and
  gets this app blocked if it is missing.
  """
  @behaviour Peoplemedia.Geo

  require Logger

  @base_url "https://nominatim.openstreetmap.org"
  @user_agent "peoplemedia/1.0 (https://peoplemedia.fly.dev)"

  @doc """
  Coordinates to `{:ok, %{country: name, country_code: code}}`.

  Every failure is `{:error, reason}` and none of them are fatal to the caller:
  the passport step treats "we do not know where you are" as a gate to clear
  rather than as a wall, because a geocoder being down is not a reason somebody
  cannot have an account.
  """
  @impl true
  def reverse_geocode(lat, lng) do
    url = "#{@base_url}/reverse?lat=#{lat}&lon=#{lng}&format=jsonv2&addressdetails=1"

    case Req.get(url, headers: [{"user-agent", @user_agent}], receive_timeout: 10_000) do
      {:ok, %{status: 200, body: %{"address" => %{"country_code" => code} = address}}} ->
        {:ok,
         %{
           country: country_name(code, address["country"]),
           country_code: String.downcase(code)
         }}

      {:ok, %{status: 200}} ->
        {:error, :no_country}

      {:ok, %{status: status}} ->
        Logger.warning("Nominatim reverse geocode HTTP #{status}")
        {:error, {:http, status}}

      {:error, reason} ->
        Logger.warning("Nominatim network error: #{inspect(reason)}")
        {:error, :network}
    end
  end

  # THE ROLL THIS APP ALREADY SCROLLS, keyed by ISO code. A place on the roll
  # gets the roll's own spelling, so the country box and the country somebody
  # was detected in can never be two different strings for one place.
  #
  # ANYWHERE ELSE IS TAKEN AS GIVEN, because the alternative is refusing to
  # place somebody for the crime of living in the nineteenth country. The roll
  # is a starting set, not a guest list — see `Directory.countries/1`, which
  # unions it with wherever people have actually turned up.
  @known %{
    "fi" => "Finland",
    "ng" => "Nigeria",
    "br" => "Brazil",
    "jp" => "Japan",
    "de" => "Germany",
    "ke" => "Kenya",
    "in" => "India",
    "ca" => "Canada",
    "mx" => "Mexico",
    "eg" => "Egypt",
    "fr" => "France",
    "id" => "Indonesia",
    "se" => "Sweden",
    "ph" => "Philippines",
    "gh" => "Ghana",
    "vn" => "Vietnam",
    "pl" => "Poland",
    "ar" => "Argentina"
  }

  defp country_name(code, fallback) do
    Map.get(@known, String.downcase(code)) || fallback || String.upcase(code)
  end
end
