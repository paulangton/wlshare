#!/bin/bash
# This script enables screensharing via a video loopback on non-Gnome Wayland compositors
set -u

MONITOR_DISPLAY="DP-1"
LAPTOP_DISPLAY="eDP-1"
FIRST_V4L2_LOOPBACK="/dev/video3"
SECOND_V4L2_LOOPBACK="/dev/video4"

# Prepare logging locations
logs_dir="$HOME/.local/logs/wlshare"
mkdir -p $logs_dir

RECORDER_LOG="$logs_dir/wf-recorder.log"
FFMPEG_LOG="$logs_dir/ffmpeg.log"
touch $RECORDER_LOG
touch $FFMPEG_LOG

echo "Writing wf-recorder logs to $RECORDER_LOG"
echo "Writing ffmpeg logs to $FFMPEG_LOG"

num_outputs=$(swaymsg -s $SWAYSOCK -t get_outputs | jq -r '. | length')
echo "Displays: $num_outputs"
if [[ $num_outputs -gt 1 ]]
then
    shared_display=$MONITOR_DISPLAY
    echo "Detected a second monitor, recording display $shared_display"
else
    shared_display=$LAPTOP_DISPLAY
    echo "No monitors detected, recording the main laptop display $shared_display"
fi


# Use wf-recorder to output a stream of WL screenshots of the given display
# --pixel-format=yuyv422
yes 'Y' 2> /dev/null | wf-recorder --muxer=v4l2 --file=$FIRST_V4L2_LOOPBACK --codec=rawvideo --output=$shared_display &> $RECORDER_LOG &

sleep 2

# Zoom does not accept video streams with pixel format BGR0 but DOES accept yuyv422
# BUG: wf-recorder does not properly utilize the --pixel-formats argument, otherwise we couild just
# output pixel format yuyv422 here and be done
ffmpeg -f v4l2 -i $FIRST_V4L2_LOOPBACK -f v4l2 -pix_fmt yuyv422 $SECOND_V4L2_LOOPBACK &> $FFMPEG_LOG &

