#!/usr/bin/env bash
# Renders the in-engine showreel (scripts/cinematics/, docs/SHOWREEL.md) to
#   media/what-lies-ahead-showreel.mp4        H.264 + AAC, 1280x720 @ 30 fps
#   media/what-lies-ahead-showreel-sheet.jpg  contact sheet, one frame per shot
#
# Godot's movie maker renders the reel in segments (a few shots each) under
# xvfb with the OpenGL driver; each finished segment is kept in build/showreel/,
# so an interrupted render resumes where it stopped. Delete that folder to start
# over (do that after changing the shots).
#
#   tools/render_showreel.sh                  # the whole reel
#   tools/render_showreel.sh --to 16          # only the shots that start before 16 s (a test)
#   tools/render_showreel.sh --segment 12     # seconds per segment (default 10)
#
# GODOT (default: godot) is the editor binary; run from the project root.
set -euo pipefail

GODOT=${GODOT:-godot}
OUT=media/what-lies-ahead-showreel.mp4
SHEET=media/what-lies-ahead-showreel-sheet.jpg
WORK=build/showreel
SEGMENT=10
LIMIT=100000
FPS=30
while [ $# -gt 0 ]; do
	case "$1" in
		--to) LIMIT=$2; shift 2 ;;
		--segment) SEGMENT=$2; shift 2 ;;
		--out) OUT=$2; shift 2 ;;
		*) echo "unknown option $1" >&2; exit 2 ;;
	esac
done
mkdir -p "$WORK" "$(dirname "$OUT")"

# The shot list: "SHOT <index> <id> <start> <length>".
"$GODOT" --headless --audio-driver Dummy --path . --script res://scripts/cinematics/showreel_render.gd \
	-- --showreel --showreel-list=1 2>/dev/null | grep '^SHOT ' > "$WORK/shots.txt"
[ -s "$WORK/shots.txt" ] || { echo "could not list the shots" >&2; exit 1; }

# Segments: runs of whole shots of about SEGMENT seconds (cuts are shot starts).
segments=()
seg_start=""
while read -r _ index id start length; do
	awk "BEGIN{exit !($start >= $LIMIT)}" && break
	[ -z "$seg_start" ] && seg_start=$start
	seg_end=$(awk "BEGIN{print $start + $length}")
	if awk "BEGIN{exit !($seg_end - $seg_start >= $SEGMENT)}"; then
		segments+=("$seg_start:$seg_end")
		seg_start=""
	fi
done < "$WORK/shots.txt"
[ -n "$seg_start" ] && segments+=("$seg_start:$seg_end")

parts=()
for seg in "${segments[@]}"; do
	from=${seg%%:*}
	to=${seg##*:}
	avi="$WORK/seg_${from}_${to}.avi"
	if [ ! -s "$avi.done" ]; then
		echo "rendering $from s - $to s"
		log=$(xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT" --rendering-driver opengl3 --path . \
			--write-movie "$avi" --fixed-fps $FPS --resolution 1280x720 \
			--script res://scripts/cinematics/showreel_render.gd \
			-- --showreel --showreel-from="$from" --showreel-to="$to" 2>&1 | grep '^\[showreel\] start frame' || true)
		# Frames written before the reel's first frame are trimmed when joining.
		frame=$(echo "$log" | awk '{print $4}')
		echo "${frame:-0}" > "$avi.done"
	fi
	parts+=("$avi")
done

# Join the segments (trimming each one's lead-in) and encode.
inputs=()
filter=""
n=0
for avi in "${parts[@]}"; do
	skip=$(cat "$avi.done")
	inputs+=(-i "$avi")
	filter+="[$n:v]trim=start_frame=$skip,setpts=PTS-STARTPTS[v$n];[$n:a]atrim=start=$(awk "BEGIN{print $skip / $FPS}"),asetpts=PTS-STARTPTS[a$n];"
	n=$((n + 1))
done
concat=""
for ((i = 0; i < n; i++)); do concat+="[v$i][a$i]"; done
filter+="${concat}concat=n=$n:v=1:a=1[v][a]"
ffmpeg -v error -y "${inputs[@]}" -filter_complex "$filter" -map "[v]" -map "[a]" \
	-c:v libx264 -preset slow -crf 22 -pix_fmt yuv420p -movflags +faststart -c:a aac -b:a 160k "$OUT"

# Contact sheet: the frame 60% into every rendered shot.
rm -f "$WORK"/sheet_*.png
total=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$OUT")
while read -r _ index id start length; do
	at=$(awk "BEGIN{print $start + $length * 0.6}")
	awk "BEGIN{exit !($at < $total)}" || break
	ffmpeg -v error -y -ss "$at" -i "$OUT" -frames:v 1 -vf "scale=480:270,drawtext=text='$index $id':x=8:y=8:fontsize=18:fontcolor=white:box=1:boxcolor=black@0.5" \
		"$WORK/sheet_$(printf %02d "$index").png" 2>/dev/null \
		|| ffmpeg -v error -y -ss "$at" -i "$OUT" -frames:v 1 -vf scale=480:270 "$WORK/sheet_$(printf %02d "$index").png"
done < "$WORK/shots.txt"
ffmpeg -v error -y -pattern_type glob -i "$WORK/sheet_*.png" -vf "tile=4x7:padding=4" -frames:v 1 -q:v 3 "$SHEET"
ls -l "$OUT" "$SHEET"
