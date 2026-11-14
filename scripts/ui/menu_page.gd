class_name MenuPage
extends Control
## Base for main-menu pages registered through UiExtension (data/ui/*.tres).
##
## The shell (main_menu.gd) owns the frame every page lives in:
##   - the top bar: home, a tab per page (UiExtension.title, sorted by
##     `order`), the player's level, name and Sparks, settings and quit;
##   - the header row of the open page: the BACK sign and a marquee sign with
##     the page's title, and to their right whatever header_extra() returns;
##   - the world behind (or the page's own backdrop()), BACK / Esc, the page
##     transition and handing keyboard focus to first_focus().
## A page that returns true from uses_shell_header() draws only its content.
## The shell sizes it to the content rectangle: below the header row, inside
## UiKit.PAGE_MARGIN at the sides and bottom. Build it with the kit
## (docs/UI_STYLE.md) and do not add a title or a BACK button of your own.
##
## Pages written before the shell (uses_shell_header() false, the default)
## draw their own title and BACK and expect the whole 1920x1080 canvas: the
## shell shows them scaled to fit under the top bar, without the header row.

## Emit to go back (the shell also calls handle_back() for BACK and Esc).
signal back
## Ask the menu to open another page by id (e.g. "play", "arsenal", "locker").
signal open_page(page_id: StringName)

## Height of the shell's top bar (canvas pixels).
const TOP_BAR := 84.0
## Height of the header row (BACK sign and marquee) under the top bar.
const HEADER := 116.0


## True for a page built for the shell: the shell draws the header row and
## gives the page the content rectangle.
func uses_shell_header() -> bool:
	return false


## Optional: a control for the right of the header row, next to the marquee
## (the Arsenal's slot plates, a collection counter, a tab row). The shell
## calls this once, after the page is ready.
func header_extra() -> Control:
	return null


## Optional: a full-screen layer shown behind the shell and the page instead
## of the live world (the Arsenal's booth diorama). The shell calls this
## once, after the page is ready, and shows it only while the page is open.
func backdrop() -> Control:
	return null


## Called every time the page is shown.
func refresh() -> void:
	pass


## A page may also declare `const HEAVY_RESOURCES: PackedStringArray`, the
## files it loads when built: the shell loads them on the loader thread before
## it builds the page in the background.

## Optional: work to do ahead of the first visit, while the menu idles (make
## the card pool, say). Queue it on `queue` in small jobs; no side effects a
## player would notice (nothing marked seen, no sounds).
func prewarm(_queue: BuildQueue) -> void:
	pass


## BACK or Esc was pressed. Return true if the page used it (closed a
## sub-view, cancelled something); false lets the shell leave the page.
func handle_back() -> bool:
	return false


## Optional: the control that should take keyboard/gamepad focus when shown.
## Default: the node named "FirstFocus".
func first_focus() -> Control:
	return find_child("FirstFocus", true, false) as Control
