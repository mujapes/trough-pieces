# Shell

## What this is for
The first piece that decides what happens, not just how something is drawn. It receives events (a finger down,
moved, lifted; the clock; the screen's size), keeps track of which screen is showing, and draws the right one
by calling other pieces. With this, a screen's behaviour lives in a piece and can be replaced while it runs.

## Entries
- **migrate**(state) → brings the state block up to layout 1 (a block of zeros becomes a fresh one: home
  screen, nothing pressed). Returns 1, or 0 for a block it does not recognise (left untouched).
- **event**(state, numbers: kind, x, y, hour, minute; how many; -) → takes one event and returns 1 if what is
  on screen should be drawn again, else 0. Missing numbers count as 0. Kinds:
  1 finger down at x y, 2 finger moved to x y, 3 finger lifted, 4 the time is hour:minute,
  5 the screen is x wide and y tall (ignored unless both are between 16 and 4096). Other kinds do nothing.
- **render**(state, numbers: handle of the picture to draw on; how many; -) → draws the current screen on that
  picture. Returns the number of drawing calls made, or -1 if the state is not layout 1 or the handle does not
  hold a sound picture. The state is not changed.

## Behaviour
- Home screen (0): while a finger is down, the tile under it (home hit) is pressed; lifting on a tile opens it:
  the opened screen (1) shows, remembering which tile. A finger down outside any tile presses nothing.
- Opened screen (1): a placeholder for an app. A strip 28 pixels tall across the top is "back": a finger put
  down in it and then lifted returns to the home screen.
- The time is kept as given, wrapped into 0-23 and 0-59.
- Before the screen's size is known, nothing can be pressed.

## State (512 bytes, owned by the host, little-endian; layout 1)
| bytes | what |
| 0-3 | layout version (1) |
| 4-7 | the letters SHEL |
| 8-11, 12-15 | screen width and height (0 until known) |
| 16-19 | screen showing: 0 home, 1 opened |
| 20-23 | pressed: a tile 0-15, -1 nothing, -2 the back strip |
| 24-27, 28-31 | hour, minute |
| 32-35 | the tile that was opened |
| 36-43 | events taken, a 64-bit count |

## Uses
Through the call table: home render (socket 12), home hit (13), paint clear (3), paint fill_rect (4),
text draw (5), text measure (6).

## Conventions
- Nothing is kept outside the state block. Every pixel goes through the pieces it calls.
