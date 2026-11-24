#!/usr/bin/env bash
# Fetch lyrics from LRCLIB (https://lrclib.net) for the dynamic island.
# Usage: lrclib-fetch.sh <artist> <title> <album> <duration-seconds>
# Prints one JSON object ({syncedLyrics, plainLyrics, instrumental, ...}) or nothing.
artist="$1"; title="$2"; album="$3"; duration="$4"
UA="quickshell-dynamic-island/1.0"
API="https://lrclib.net/api"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/quickshell/lyrics"
mkdir -p "$CACHE"
key=$(printf '%s\n%s' "${artist,,}" "${title,,}" | sha1sum | cut -d' ' -f1)
if [[ -s "$CACHE/$key.json" ]]; then cat "$CACHE/$key.json"; exit 0; fi

out=""
args=(-sf --max-time 8 -A "$UA" -G)
if [[ -n "$artist" ]]; then
    q=(--data-urlencode "artist_name=$artist" --data-urlencode "track_name=$title")
    [[ -n "$album" ]] && q+=(--data-urlencode "album_name=$album")
    [[ "$duration" =~ ^[0-9]+$ && "$duration" -gt 0 ]] && q+=(--data-urlencode "duration=$duration")
    out=$(curl "${args[@]}" "$API/get" "${q[@]}")
    # Exact match without synced lyrics: still try search for a synced one
    if [[ -n "$out" && $(jq -r '.syncedLyrics // empty' <<<"$out") == "" ]]; then plain="$out"; out=""; fi
fi
if [[ -z "$out" ]]; then
    q=(--data-urlencode "track_name=$title")
    [[ -n "$artist" ]] && q+=(--data-urlencode "artist_name=$artist")
    res=$(curl "${args[@]}" "$API/search" "${q[@]}")
    if [[ -n "$res" ]]; then
        d=${duration:-0}; [[ "$d" =~ ^[0-9]+$ ]] || d=0
        # Prefer synced results, then closest duration
        out=$(jq -c --argjson d "$d" '
            [ .[] | select(.syncedLyrics != null and .syncedLyrics != "") ]
            | sort_by(if $d > 0 then ((.duration // 0) - $d | fabs) else 0 end)
            | (if $d > 0 then map(select(((.duration // 0) - $d | fabs) < 8)) else . end)
            | .[0] // empty' <<<"$res")
    fi
fi
[[ -z "$out" ]] && out="$plain"
if [[ -n "$out" ]]; then
    printf '%s' "$out" > "$CACHE/$key.json"
    printf '%s' "$out"
fi
