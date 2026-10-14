# Decision: Profiles + My Notes placement (2026-10-14)

Board run 5 (profiles + My Notes). Decided by Silas from the research
desk's category pass; founder may override on review. Petra audited
the surfaces (PASS WITH FIXES, all fixes implemented); the placement
itself is this record.

## Research (named sources)
- YouVersion: Notes/Highlights/Bookmarks are headline features, but
  notes historically sat buried under "Saved" — a published redesign
  case study of the app flags exactly that as the discoverability
  failure and gives Notes a dedicated home.
- Dwell: five bottom tabs (Home, Plans, Passages, Playlists,
  Library); personal content collects in Library.
- Logos: Notes are a core tool reached through the app menu.
- Gospel Library: notes attach to highlighted text; a note icon by
  the text opens edit/delete.
- Olive Tree (help docs): a dedicated Notes list — tap a note to
  edit it, tap its reference to navigate to the Bible text. The
  closest existing pattern to this package's list semantics.
- Seed Bible (newer entrant): a profile screen ("Your content":
  notes, highlights, saves together) opened from an avatar / "You"
  entry.

## Adopted
- Profile entry as an avatar chip (active profile's initial) at the
  right of the home top bar — identity lives at the top of home in
  the category (YouVersion, Seed Bible).
- My Notes as a first-class list one tap from home (notes button
  beside the chip), NOT nested inside Profiles — YouVersion's
  "Saved" burial is the documented anti-pattern.
- My Notes rows carry reference + verse text + note text, edit from
  the list, tap the row to open the reader at the verse (Olive Tree
  semantics), canonical order (the app's own study logic: the canon
  is the index).
- The default profile's display name is "My Profile" until renamed;
  renaming never changes its id, so run 4's data is untouched.

## Rejected
- Bottom tab bar (Dwell's five tabs): Woven Word's navigation is a
  two-screen stack (home → reader). A tab shell built for two
  utility screens restructures the app beyond this package and
  leaves the remaining tabs with nothing honest to hold.
- Notes only inside the Profiles screen: repeats the burial the
  YouVersion redesign documents as a failure.
- Any account/sign-in framing: profiles are on-device only; the
  Profiles screen says so plainly instead of borrowing cloud
  language the app does not implement.
