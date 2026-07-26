# Media attribution

The fixture users in `lib/peoplemedia_web/live/home_live.ex` point at real
media hosted by Wikimedia Commons. Nothing is vendored into this repo — the
browser fetches each file from `upload.wikimedia.org` at play time — but the
licences below still require attribution wherever the work is shown, so they
are recorded here.

Every clip is under one minute. We link Commons' generated transcodes rather
than the originals: Safari cannot play Ogg Vorbis at all, and the source WebM
files are 9–14 MB apiece for a screen that is forty-five pixels square.

## Voices — Wikimedia Commons Voice Intro Project

People recording a short spoken introduction of themselves.

| Speaker | Duration | Licence |
|---|---|---|
| Simone Giertz | 9.1s | CC BY 3.0 |
| Charles Duke | 9.3s | CC0 |
| Dan Barker | 13.4s | CC BY-SA 4.0 |
| Robin Llwyd ab Owain | 17.9s | CC BY-SA 3.0 |
| Richard Rogers | 21.8s | CC0 |

## Faces — Wikitongues

Single speakers talking to camera, recorded for language documentation.

| Speaker | Language | Duration | Licence |
|---|---|---|---|
| Paulus | Mentuka | 37.3s | CC BY-SA 4.0 |
| Hermica | Bengape | 35.5s | CC BY-SA 4.0 |
| Célestin | Kilega | 46.6s | CC BY-SA 4.0 |
| Donald | Tswana | 54.5s | CC BY-SA 4.0 |

## The presence stream — Wikitongues and the Voice intro project

A second, non-overlapping set, used for the presences inside a person's stream.
The clips above stay where they were: they are the LIVE presence the frame
carries in the relationship list, and nothing in the stream reuses them.

### Faces — Wikitongues, CC BY-SA 4.0

| Speaker | Language | Duration |
|---|---|---|
| Sedang | Iban | 37.4s |
| Tarkhan | Jek | 46.9s |
| Jeries | Syriac | 48.5s |
| Uladzislau | Belarusian | 54.3s |
| Yernur | Kazakh | 56.5s |
| Rizki | Malay | 58.4s |

### Voices — Commons Voice intro project

| Speaker | Duration | Licence |
|---|---|---|
| Andy Mabbett | 10.5s | CC BY-SA 3.0 |
| Bettany Hughes | 15.6s | CC BY-SA 4.0 |
| Brian Schmidt | 16.2s | CC BY-SA 4.0 |
| David Harewood | 16.7s | CC BY-SA 4.0 |
| David Lammy | 17.5s | CC BY-SA 4.0 |
| Alison Balsom | 18.1s | CC BY-SA 4.0 |

None of this second set is public domain — every item is CC BY or CC BY-SA and
carries an attribution requirement. Video credit is Wikitongues plus the named
recordist; audio credit is the uploader on each Commons file page.

## Licence texts

- CC0 1.0 — https://creativecommons.org/publicdomain/zero/1.0/
- CC BY 3.0 — https://creativecommons.org/licenses/by/3.0/
- CC BY-SA 3.0 — https://creativecommons.org/licenses/by-sa/3.0/
- CC BY-SA 4.0 — https://creativecommons.org/licenses/by-sa/4.0/

## A note for whoever wires up the real thing

`upload.wikimedia.org` rate-limits aggressively and answers HTTP 429 with an
HTML body when hit hard without a descriptive User-Agent. Browsers loading one
clip at a time do not trip it; a test harness looping over every URL will.
