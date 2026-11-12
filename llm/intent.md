# llm

## What this is for
Language models reached through their APIs are a first-class way of giving Trough input and getting work done.
This piece is the wire format: it writes the request a model's API expects, and reads the words out of the
stream of events the model sends back. The host owns the socket and the key's storage; the secure connection is
the tls piece; taking the reply's chunks apart is the http piece (`body`). First format: Anthropic's Messages
API (`POST /v1/messages`, streamed).

## Entries
- **request**(block, numbers: key handle, model handle, prompt handle; how many; argument: the most tokens the
  answer may have) → writes the whole HTTP request into the block from byte 64 and returns its length:
  `POST /v1/messages HTTP/1.1`, headers `Host: api.anthropic.com`, `Content-Type: application/json`,
  `X-Api-Key`, `Anthropic-Version: 2023-06-01`, `Connection: close`, `Content-Length`, a blank line, then
  `{"model":"…","max_tokens":N,"stream":true,"messages":[{"role":"user","content":"…"}]}`.
  The prompt is written as a JSON string: `"` and `\` get a backslash; line feed, carriage return and tab become
  `\n`, `\r`, `\t`; any other byte below 32 becomes `\u00XX` (lower-case hex); every other byte is written as it is.
  -1, with nothing written, if: fewer than 3 numbers; a handle is empty or not plain bytes; the key is empty,
  longer than 300, or has any byte outside 33 to 126 (so it cannot end its header line and add another); the model
  name is empty, longer than 100, or has a byte that is not a letter, digit, `.`, `_`, `:` or `-`; the prompt is
  empty; the argument is outside 1 to 64000; or the request does not fit the block.
- **text**(block, numbers: handle of the event stream received so far, already taken out of its chunks) → writes
  the answer's words so far into the block from byte 64 and returns their length. It joins, in order, the text of
  every event that says `"type":"text_delta"` and then, on the same line, `"text":"…"`, undoing the JSON string's
  escapes (`\"`, `\\`, `\/`, `\b`, `\f`, `\n`, `\r`, `\t`, and `\uXXXX`, two of which may make one character
  beyond U+FFFF) into UTF-8. An event whose string has not ended yet (the stream is still arriving), or whose
  escape is malformed, ends the reading there, and nothing of that event is written. -1 if the handle is empty or
  not plain bytes, or the words do not fit.
- **stopped**(-, numbers: the same handle) → 1 if the stream says `"type":"message_stop"`, 2 if it says
  `"type":"error"` (2 wins if both are there), 0 if neither yet; -1 for an unusable handle.

## Conventions
- No state; calls nothing. The key is read only to be copied into the request; it is never written anywhere else.
- Only what the API documents is relied on: one event to a line, `type` before `text` within a delta.

## Not done
Other providers' formats; a conversation of several turns; a system prompt; tool use; pictures in the prompt;
reading the token counts the stream reports.
