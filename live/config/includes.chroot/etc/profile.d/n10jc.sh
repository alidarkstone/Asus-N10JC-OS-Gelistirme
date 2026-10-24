# Chicony 04f2:b071 webcam on the N10JC is mounted upside down: flip in libv4l.
export LIBV4LCONTROL_FLAGS=3
export GTK_THEME=WhiteSur-Light
# Start the desktop on tty1 after (auto)login. X's own log stays in
# ~/.local/share/xorg/Xorg.0.log; the session log is ~/.cache/n10-session.log.
if [ -z "${DISPLAY:-}" ] && [ "$(tty)" = /dev/tty1 ] && command -v startx >/dev/null; then
  mkdir -p "$HOME/.cache"
  exec startx /usr/local/bin/n10-session -- -nolisten tcp vt1 >"$HOME/.cache/startx.log" 2>&1
fi
