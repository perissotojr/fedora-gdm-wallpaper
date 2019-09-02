#! /bin/sh

set -e

if ! hash gresource 2>/dev/null; then
  echo "gresource binary not found. "
  echo " "
  echo "Please install glib2 or glib2-devel"
  echo " "
  echo "Fedora:"
  echo "# dnf install glib2-devel"
  exit 1
fi

if [ "$#" -eq "0" ]; then
  echo 'Usage:'
  echo '  set-gdm-wallpaper [FLAG] /path/to/image    Set login screen wallpaper'
  echo '    Flags:'
  echo '      -r       Stretch image to fit desktop. Work incorrectly with multiple monitors!'
  echo '  set-gdm-wallpaper --uninstall              Remove changes and set original wallpaper (original gresource file)'
  exit 1
fi

if [ "$1" = "--uninstall" ]; then
  # Restore file if current gresource file is modified by this script.
  # If wallpaper-gdm.png text inside gresource file, then this is modified file.
  if grep -q "wallpaper-gdm.png" /usr/share/gnome-shell/gnome-shell-theme.gresource; then
    cp -f /usr/share/gnome-shell/gnome-shell-theme.gresource.backup /usr/share/gnome-shell/gnome-shell-theme.gresource

    echo 'gnome-shell-theme.gresource recovered'
  fi

  exit
fi

if [ "$1" = "-r" ]; then
  doResize=true
fi

image="$1"

if [ ! -f "$image" ]; then
  echo "File not found: \"$image\" "
  exit 1
fi

echo "Updating wallpaper..."

workdir=$(mktemp -d)
cd "$workdir"

# Creating gnome-shell-theme.gresource.xml with theme file list and add header
echo '<?xml version="1.0" encoding="UTF-8"?>' >"$workdir/gnome-shell-theme.gresource.xml"
echo '<gresources><gresource>' >>"$workdir/gnome-shell-theme.gresource.xml"

for res_file in $(gresource list /usr/share/gnome-shell/gnome-shell-theme.gresource); do
  # create dir for theme file inside temp dir
  mkdir -p "$(dirname "$workdir$res_file")"

  if [ "$res_file" != "/org/gnome/shell/theme/wallpaper-gdm.png" ]; then
    # extract file ($res_file) from current theme and write it to temp dir ($workdir)
    gresource extract /usr/share/gnome-shell/gnome-shell-theme.gresource "$res_file" >"$workdir$res_file"

    # add extracted file name to gnome-shell-theme.gresource.xml
    echo "<file>${res_file#\/}</file>" >>"$workdir/gnome-shell-theme.gresource.xml"
  fi
done

# add our image ($image) to theme path and to xml file
echo "<file>org/gnome/shell/theme/wallpaper-gdm.png</file>" >>"$workdir/gnome-shell-theme.gresource.xml"
cp -f "$image" "$workdir/org/gnome/shell/theme/wallpaper-gdm.png"

# add footer to xml file
echo '</gresource></gresources>' >>"$workdir/gnome-shell-theme.gresource.xml"

if [ "$doResize" = true ]
then
 # find line with background file name inside gnome-shell.css and replace it with wallpaper-gdm.png
 # add background-size: cover for stretch image to fit desktop
 sed -i -e 's/background: #2e3436 url(resource:\/\/\/org\/gnome\/shell\/theme\/noise-texture.png);/background: #2e3436 url(resource:\/\/\/org\/gnome\/shell\/theme\/wallpaper-gdm.png);background-size: cover;/g' "$workdir/org/gnome/shell/theme/gnome-shell.css"
else
 # find line with background file name inside gnome-shell.css and replace it with wallpaper-gdm.png
 sed -i -e 's/background: #2e3436 url(resource:\/\/\/org\/gnome\/shell\/theme\/noise-texture.png);/background: #2e3436 url(resource:\/\/\/org\/gnome\/shell\/theme\/wallpaper-gdm.png);/g' "$workdir/org/gnome/shell/theme/gnome-shell.css"
fi
# create gresource file with file list inside gnome-shell-theme.gresource.xml
glib-compile-resources "$workdir/gnome-shell-theme.gresource.xml"

# Do backup only for original gresource file, not modified by this script.
# If wallpaper-gdm.png text inside gresource file, then this is modified file.
if ! grep -q "wallpaper-gdm.png" /usr/share/gnome-shell/gnome-shell-theme.gresource; then
  cp -f /usr/share/gnome-shell/gnome-shell-theme.gresource /usr/share/gnome-shell/gnome-shell-theme.gresource.backup
  echo "Backup"
fi

cp -f "$workdir/gnome-shell-theme.gresource" /usr/share/gnome-shell/

rm -rf "$workdir/theme"
rm -f "$workdir/gnome-shell-theme.gresource.xml"
rm -f "$workdir/gnome-shell-theme.gresource"

echo "Done!"
