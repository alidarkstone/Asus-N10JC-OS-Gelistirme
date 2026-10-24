# Chicony 04f2:b071 webcam on the N10JC is mounted upside down: flip in libv4l.
export LIBV4LCONTROL_FLAGS=3
export GTK_THEME=WhiteSur-Light
# Start the desktop on tty1 after (auto)login.
if [ -z "${DISPLAY:-}" ] && [ "$(tty)" = /dev/tty1 ] && command -v startx >/dev/null; then
  exec startx -- -nolisten tcp vt1 >/dev/null 2>&1
fi
