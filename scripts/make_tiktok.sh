#!/usr/bin/env bash
# Heather Newbuild Cottage x Frenchic: table upcycle
# (sand -> paint -> products -> table reveal -> tabletop detail -> chair).
#
# Usage: scripts/make_tiktok.sh SANDING PAINT PRODUCTS REVEAL TABLETOP CHAIR OUT.mp4
#
# - iPhone HLG/HDR converted to standard colour, then a very gentle soft, warm
#   grade that keeps paint colours and wood tones true.
# - Short, quiet dissolves through the process; a slower dissolve into the
#   reveal, which gets around two thirds of the running time and ends on the chair.
# - Two understated magazine-style captions in Cormorant Garamond, clear of
#   the TikTok interface.
# - Original sound kept; 1080x1920, 30fps, H.264/AAC.
set -euo pipefail

if [ $# -ne 7 ]; then
  echo "usage: $0 SANDING PAINT PRODUCTS REVEAL TABLETOP CHAIR OUT.mp4" >&2
  exit 1
fi

HERE="$(cd "$(dirname "$0")/.." && pwd)"
CAP="$HERE/captions"
FONTS="$HERE/fonts"

# Start and length (seconds) used from each clip.
S1=0;   D1=4.2
S2=0.2; D2=3.2
S3=1;   D3=3.0
S4=0;   D4=7.0
S5=0.5; D5=5.0
S6=0;   D6=3.5  # played in reverse so it settles on the chair
HOLD=0.8        # rest on the chair as the video fades out
XS=0.35  # dissolve between process shots
XR=1.0   # dissolve into the reveal
XV=0.6   # dissolve between reveal shots
O1=$(echo "$D1-$XS" | bc)
O2=$(echo "$O1+$D2-$XS" | bc)
O3=$(echo "$O2+$D3-$XR" | bc)
O4=$(echo "$O3+$D4-$XV" | bc)
O5=$(echo "$O4+$D5-$XV" | bc)
TOTAL=$(echo "$O5+$D6+$HOLD" | bc)

# HLG -> SDR bt709 at the standard 203-nit HLG reference white, with hable
# keeping window highlights and wood tones intact (npl=100 doubled brightness).
TOPHONE="zscale=t=linear:npl=203,format=gbrpf32le,zscale=p=bt709,tonemap=hable:desat=0,zscale=t=bt709:m=bt709:r=tv,format=yuv420p"
# Soft: gently opened midtones and eased highlights, no lifted blacks (they wash it out).
SOFT="curves=all='0/0 0.5/0.53 1/0.98',eq=saturation=0.97"
# Warm: only for shots with cool whites (paint tin and the three reveal shots).
# The sanding and windowsill shots are already warm and would tip into orange.
WARM="colorbalance=rm=0.025:gm=0.005:bm=-0.025:rh=0.015:bh=-0.02"
FIT="scale=1080:1920:force_original_aspect_ratio=increase,crop=1080:1920,setsar=1,fps=30,settb=AVTB"
AFMT="aformat=sample_rates=44100:channel_layouts=stereo"

# Captions: a magazine-style lockup set with libass. Line 1 of each caption
# file is a lead in small spaced capitals (Cormorant Garamond SemiBold), line 2
# the phrase in Cormorant Garamond Medium Italic. Ivory, with a soft blurred
# edge for legibility rather than a hard shadow; gentle fades in and out.
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
ts() { awk -v t="$1" 'BEGIN{h=int(t/3600); m=int((t-h*3600)/60); s=t-h*3600-m*60; printf "%d:%02d:%05.2f", h, m, s}'; }
lockup() { # file start end y
  local f="$1" s e y="$4" lead phrase
  s=$(ts "$2"); e=$(ts "$3")
  { IFS= read -r lead; IFS= read -r phrase || true; } < "$CAP/$f"
  lead=$(printf '%s' "$lead" | tr '[:lower:]' '[:upper:]')
  printf 'Dialogue: 0,%s,%s,Lead,,0,0,0,,{\\fad(700,700)\\blur5\\pos(540,%s)}%s\n' "$s" "$e" "$y" "$lead"
  printf 'Dialogue: 0,%s,%s,Phrase,,0,0,0,,{\\fad(700,700)\\blur5\\pos(540,%s)}%s\n' "$s" "$e" "$((y+72))" "$phrase"
}

ASS="$TMP/captions.ass"
{
  cat <<'HEAD'
[Script Info]
ScriptType: v4.00+
PlayResX: 1080
PlayResY: 1920
WrapStyle: 2

[V4+ Styles]
Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
Style: Lead,Cormorant Garamond SemiBold,56,&H00EAF5FB,&H00EAF5FB,&H8818212B,&H00000000,0,0,0,0,100,100,9,0,1,1.4,0,8,40,40,0,1
Style: Phrase,Cormorant Garamond Medium,86,&H00EAF5FB,&H00EAF5FB,&H8818212B,&H00000000,0,1,0,0,100,100,1,0,1,1.4,0,8,40,40,0,1

[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
HEAD
  lockup 01_opening.txt 0.3 "$(echo "$O1+0.1" | bc)" 1180
  lockup 02_reveal.txt "$(echo "$O3+2.0" | bc)" "$(echo "$O4+0.1" | bc)" 250
} > "$ASS"

ffmpeg -hide_banner -y \
  -ss "$S1" -t "$D1" -i "$1" \
  -ss "$S2" -t "$D2" -i "$2" \
  -ss "$S3" -t "$D3" -i "$3" \
  -ss "$S4" -t "$D4" -i "$4" \
  -ss "$S5" -t "$D5" -i "$5" \
  -ss "$S6" -t "$D6" -i "$6" \
  -filter_complex "
[0:v]$TOPHONE,$FIT,$SOFT[v0];
[1:v]$TOPHONE,$FIT,$SOFT,$WARM[v1];
[2:v]$TOPHONE,$FIT,$SOFT[v2];
[3:v]$TOPHONE,$FIT,$SOFT,$WARM[v3];
[4:v]$TOPHONE,$FIT,$SOFT,$WARM[v4];
[5:v]$TOPHONE,$FIT,$SOFT,$WARM,reverse,tpad=stop_mode=clone:stop_duration=$HOLD,settb=AVTB[v5];
[v0][v1]xfade=transition=fade:duration=$XS:offset=$O1[x1];
[x1][v2]xfade=transition=fade:duration=$XS:offset=$O2[x2];
[x2][v3]xfade=transition=fade:duration=$XR:offset=$O3[x3];
[x3][v4]xfade=transition=fade:duration=$XV:offset=$O4[x4];
[x4][v5]xfade=transition=fade:duration=$XV:offset=$O5[x5];
[x5]subtitles=$ASS:fontsdir=$FONTS,fade=t=out:st=$(echo "$TOTAL-$HOLD" | bc):d=$HOLD,format=yuv420p[v];
[0:a]volume=0.7,$AFMT[a0];
[1:a]$AFMT[a1];
[2:a]$AFMT[a2];
[3:a]$AFMT[a3];
[4:a]$AFMT[a4];
[5:a]$AFMT[a5];
[a0][a1]acrossfade=d=$XS[b1];
[b1][a2]acrossfade=d=$XS[b2];
[b2][a3]acrossfade=d=$XR[b3];
[b3][a4]acrossfade=d=$XV[b4];
[b4][a5]acrossfade=d=$XV[b5];
[b5]apad,afade=t=out:st=$(echo "$TOTAL-$HOLD" | bc):d=$HOLD[a]" \
  -map "[v]" -map "[a]" \
  -c:v libx264 -preset slow -crf 18 -maxrate 16M -bufsize 32M -profile:v high -pix_fmt yuv420p \
  -color_primaries bt709 -color_trc bt709 -colorspace bt709 \
  -c:a aac -b:a 192k -ar 44100 -movflags +faststart \
  -t "$TOTAL" "$7"

echo "Wrote $7 (${TOTAL}s)"
