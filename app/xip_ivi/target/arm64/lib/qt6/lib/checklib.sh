# List of missing libraries
libs=(
  "libxcb-icccm.so.4"
  "libxcb-image.so.0"
  "libxcb-keysyms.so.1"
  "libxcb-randr.so.0"
  "libxcb-render.so.0"
  "libxcb-render-util.so.0"
  "libxcb-shape.so.0"
  "libxcb-shm.so.0"
  "libxcb-sync.so.1"
  "libxcb.so.1"
  "libxcb-xfixes.so.0"
  "libxcb-xkb.so.1"
  "libxkbcommon.so.0"
  "libglib-2.0.so.0"
  "libX11-xcb.so.1"
  "libX11.so.6"
  "libSM.so.6"
  "libICE.so.6"
  "libxkbcommon-x11.so.0"
  "libEGL.so.1"
  "libfontconfig.so.1"
  "libGLX.so.0"
  "libOpenGL.so.0"
  "libpng16.so.16"
  "libharfbuzz.so.0"
  "libmd4c.so.0"
  "libfreetype.so.6"
  "libicui18n.so.74"
  "libicuuc.so.74"
  "libdouble-conversion.so.3"
  "libb2.so.1"
  "libpcre2-16.so.0"
  "libdbus-1.so.3"
)

# Loop through each library and check if it exists in /usr
for lib in "${libs[@]}"; do
  find /usr -name "$lib" 2>/dev/null | grep -q . && echo "$lib found in /usr" || echo "$lib not found in /usr"
done
