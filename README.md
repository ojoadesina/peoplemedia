# Peoplemedia

People Media (currently presence media) is social media where people are the
primary focus, enabling relationships through authentic human presence.

## Running it

* Run `mix setup` to install and setup dependencies
* Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

Ready to run in production? Please [check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).

## What is here so far

A single surface: the people you hold, as a list you scroll. A fixed band a
third of the way down IS the selection — rows pass through it, and whichever
lands there is chosen. At the far edge, a frame shows what is coming through
from that person: nothing, their voice, or their face.

There is no database yet, and the app does not depend on Ecto. The users are
fixtures. The media they point at is real, though — see [ATTRIBUTION.md](ATTRIBUTION.md).

## Learn more

* Official website: https://www.phoenixframework.org/
* Guides: https://hexdocs.pm/phoenix/overview.html
* Docs: https://hexdocs.pm/phoenix
* Forum: https://elixirforum.com/c/phoenix-forum
* Source: https://github.com/phoenixframework/phoenix
