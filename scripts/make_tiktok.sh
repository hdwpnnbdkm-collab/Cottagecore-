#!/usr/bin/env bash
# Cottagecore TikTok edit: table upcycle (sand -> paint -> products -> reveal).
#
# Usage: scripts/make_tiktok.sh SANDING.mov PAINT.mov PRODUCTS.mov REVEAL.mov OUT.mp4
#
# - Tone-maps iPhone HLG/HDR footage to SDR so colours look right on TikTok.
# - Warm, faded "old English countryside" grade with vignette + film grain.
# - Slow push-in on the static shots, soft crossfades, serif captions.
# - 1080x1920, 30fps, H.264/AAC, loudness normalised for mobile.
set -euo pipefail

if [ $# -ne 5 ]; then
  echo "usage: $0 SANDING PAINT PRODUCTS REVEAL OUT.mp4" >&2
  exit 1
fi

HERE="$(cd "$(dirname "$0")/.." && pwd)"
CAP="$HERE/captions"
FONT="${FONT:-/usr/share/fonts/truetype/crosextra/Caladea-Italic.ttf}"

# Clip lengths used (seconds) and crossfade length.
D1=5; D2=4; D3=5; D4=9.4; XF=0.6
O1=$(echo "$D1-$XF" | bc)
O2=$(echo "$O1+$D2-$XF" | bc)
O3=$(echo "$O2+$D3-$XF" | bc)
TOTAL=$(echo "$O3+$D4" | bc)

# HLG -> SDR bt709 tone map.
TONEMAP="zscale=t=linear:npl=100,format=gbrpf32le,zscale=p=bt709,tonemap=hable:desat=0,zscale=t=bt709:m=bt709:r=tv,format=yuv420p"
# Cottagecore grade: lifted/faded blacks, soft highlights, warm honey tones, muted saturation.
GRADE="curves=all='0/0.07 0.25/0.27 0.5/0.52 0.75/0.76 1/0.93':r='0/0.03 0.5/0.53 1/0.97':b='0/0.06 0.5/0.46 1/0.88',colorbalance=rs=0.05:gs=0.01:bs=-0.05:rm=0.04:bm=-0.04:rh=0.03:bh=-0.03,eq=saturation=0.84:contrast=0.97:brightness=0.03"
FILM="vignette=angle=PI/5.5,noise=alls=6:allf=t"
FIT="scale=1080:1920:force_original_aspect_ratio=increase,crop=1080:1920,setsar=1,fps=30"
# Gentle push-in for static shots (zoompan on an upscaled frame keeps it smooth).
PUSH="scale=2160:3840,zoompan=z='1+0.0009*on':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d=1:s=1080x1920:fps=30"

# Caption helper: one centred drawtext per line, fading in/out between start and end.
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
cap() { # file start end y size
  local f="$1" s="$2" e="$3" y="$4" sz="$5" i=0 out="" line
  while IFS= read -r line || [ -n "$line" ]; do
    printf '%s' "$line" > "$TMP/$f.$i"
    out+="${out:+,}drawtext=fontfile='$FONT':textfile='$TMP/$f.$i':fontsize=$sz:fontcolor=0xFFF6E6:borderw=2:bordercolor=0x4A3520@0.35:shadowcolor=0x2E1F12@0.6:shadowx=3:shadowy=4:x=(w-text_w)/2:y=$y+$i*($sz*1.25):enable='between(t,$s,$e)':alpha='min(1,min((t-$s)/0.5,($e-t)/0.5))'"
    i=$((i+1))
  done < "$CAP/$f"
  printf '%s' "$out"
}

C1=$(cap 01_hook.txt 0.2 "$O1" 280 92)
C2=$(cap 02_paint.txt "$(echo "$O1+0.4" | bc)" "$O2" 280 88)
C3=$(cap 03_products.txt "$(echo "$O2+0.4" | bc)" "$O3" 280 88)
C4=$(cap 04_reveal.txt "$(echo "$O3+0.6" | bc)" "$(echo "$TOTAL-0.3" | bc)" 280 90)

ffmpeg -hide_banner -y \
  -t "$D1" -i "$1" \
  -t "$D2" -i "$2" \
  -t "$D3" -i "$3" \
  -t "$D4" -i "$4" \
  -filter_complex "
[0:v]$TONEMAP,$FIT,$GRADE[v0];
[1:v]$TONEMAP,$PUSH,setsar=1,$GRADE[v1];
[2:v]$TONEMAP,$PUSH,setsar=1,$GRADE[v2];
[3:v]$TONEMAP,$FIT,$GRADE[v3];
[v0][v1]xfade=transition=fade:duration=$XF:offset=$O1[x1];
[x1][v2]xfade=transition=fade:duration=$XF:offset=$O2[x2];
[x2][v3]xfade=transition=fade:duration=$XF:offset=$O3[x3];
[x3]$FILM,$C1,$C2,$C3,$C4,fade=t=in:st=0:d=0.4,fade=t=out:st=$(echo "$TOTAL-0.8" | bc):d=0.8,format=yuv420p[v];
[0:a]volume=0.55,aformat=sample_rates=44100:channel_layouts=stereo[a0];
[1:a]aformat=sample_rates=44100:channel_layouts=stereo[a1];
[2:a]aformat=sample_rates=44100:channel_layouts=stereo[a2];
[3:a]aformat=sample_rates=44100:channel_layouts=stereo[a3];
[a0][a1]acrossfade=d=$XF[b1];
[b1][a2]acrossfade=d=$XF[b2];
[b2][a3]acrossfade=d=$XF[b3];
[b3]loudnorm=I=-16:TP=-1.5:LRA=11,afade=t=in:d=0.4,afade=t=out:st=$(echo "$TOTAL-1" | bc):d=1[a]" \
  -map "[v]" -map "[a]" \
  -c:v libx264 -preset slow -crf 20 -maxrate 14M -bufsize 28M -profile:v high -pix_fmt yuv420p \
  -color_primaries bt709 -color_trc bt709 -colorspace bt709 \
  -c:a aac -b:a 192k -ar 44100 -movflags +faststart \
  -t "$TOTAL" "$5"

echo "Wrote $5 (${TOTAL}s)"
