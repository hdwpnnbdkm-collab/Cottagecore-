#!/usr/bin/env bash
# Heather Newbuild Cottage: table upcycle (sand -> paint -> products -> reveal).
#
# Usage: scripts/make_tiktok.sh SANDING.mov PAINT.mov PRODUCTS.mov REVEAL.mov OUT.mp4
#
# - No colour grade, filters or lighting changes. iPhone HLG/HDR is only
#   converted to standard colour so it looks as it does on the phone.
# - Natural cuts, one slow dissolve into the reveal, no zooms.
# - Two understated serif overlays, kept clear of the TikTok interface.
# - Original sound kept; 1080x1920, 30fps, H.264/AAC.
set -euo pipefail

if [ $# -ne 5 ]; then
  echo "usage: $0 SANDING PAINT PRODUCTS REVEAL OUT.mp4" >&2
  exit 1
fi

HERE="$(cd "$(dirname "$0")/.." && pwd)"
CAP="$HERE/captions"
FONT="${FONT:-/usr/share/fonts/truetype/crosextra/Caladea-Italic.ttf}"

# Start and length (seconds) used from each clip, and the dissolve into the reveal.
S1=0;   D1=4.5
S2=0.2; D2=3.6
S3=1;   D3=3.4
S4=0;   D4=7.4
XF=0.8
OFF=$(echo "$D1+$D2+$D3-$XF" | bc)
TOTAL=$(echo "$OFF+$D4" | bc)

# HLG -> SDR bt709 conversion only; mobius keeps it closest to how the iPhone displays it.
TOPHONE="zscale=t=linear:npl=100,format=gbrpf32le,zscale=p=bt709,tonemap=mobius:desat=0,zscale=t=bt709:m=bt709:r=tv,format=yuv420p"
FIT="scale=1080:1920:force_original_aspect_ratio=increase,crop=1080:1920,setsar=1,fps=30"
AFMT="aformat=sample_rates=44100:channel_layouts=stereo"

# Caption helper: cream text on darker footage, mushroom text on bright windows.
# One centred drawtext per line, gently fading in/out between start and end.
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
cap() { # file start end y size colour shadow
  local f="$1" s="$2" e="$3" y="$4" sz="$5" col="$6" sh="$7" i=0 out="" line
  while IFS= read -r line || [ -n "$line" ]; do
    printf '%s' "$line" > "$TMP/$f.$i"
    out+="${out:+,}drawtext=fontfile='$FONT':textfile='$TMP/$f.$i':fontsize=$sz:fontcolor=$col:shadowcolor=$sh:shadowx=2:shadowy=2:x=(w-text_w)/2:y=$y+$i*($sz*1.3):enable='between(t,$s,$e)':alpha='min(1,min((t-$s)/0.6,($e-t)/0.6))'"
    i=$((i+1))
  done < "$CAP/$f"
  printf '%s' "$out"
}

C1=$(cap 01_opening.txt 0.3 "$(echo "$D1-0.2" | bc)" 330 70 0xFBF5EA 0x2B2118@0.45)
C2=$(cap 02_reveal.txt "$(echo "$OFF+1.6" | bc)" "$(echo "$TOTAL-0.4" | bc)" 330 66 0x5C4D3F 0xFFFDF8@0.5)

ffmpeg -hide_banner -y \
  -ss "$S1" -t "$D1" -i "$1" \
  -ss "$S2" -t "$D2" -i "$2" \
  -ss "$S3" -t "$D3" -i "$3" \
  -ss "$S4" -t "$D4" -i "$4" \
  -filter_complex "
[0:v]$TOPHONE,$FIT[v0];
[1:v]$TOPHONE,$FIT[v1];
[2:v]$TOPHONE,$FIT[v2];
[3:v]$TOPHONE,$FIT[v3];
[0:a]volume=0.7,$AFMT,afade=t=out:st=$(echo "$D1-0.15" | bc):d=0.15[a0];
[1:a]$AFMT[a1];
[2:a]$AFMT[a2];
[3:a]$AFMT[a3];
[v0][a0][v1][a1][v2][a2]concat=n=3:v=1:a=1[vc][ac];
[vc]fps=30,settb=AVTB[vc2];
[v3]settb=AVTB[v3b];
[vc2][v3b]xfade=transition=fade:duration=$XF:offset=$OFF[vx];
[ac][a3]acrossfade=d=$XF[ax];
[vx]$C1,$C2,fade=t=out:st=$(echo "$TOTAL-0.6" | bc):d=0.6,format=yuv420p[v];
[ax]afade=t=out:st=$(echo "$TOTAL-0.6" | bc):d=0.6[a]" \
  -map "[v]" -map "[a]" \
  -c:v libx264 -preset slow -crf 18 -maxrate 16M -bufsize 32M -profile:v high -pix_fmt yuv420p \
  -color_primaries bt709 -color_trc bt709 -colorspace bt709 \
  -c:a aac -b:a 192k -ar 44100 -movflags +faststart \
  -t "$TOTAL" "$5"

echo "Wrote $5 (${TOTAL}s)"
