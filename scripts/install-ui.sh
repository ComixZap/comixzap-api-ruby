cwd=$(pwd)

pushd $(dirname "$0") > /dev/null
scriptdir=$(pwd)
popd > /dev/null

browserfolder="comixzap-browser-ui"

rootdir=$(dirname "$scriptdir")
browserdir="$rootdir/$browserfolder"

cd "$rootdir"
git submodule
git submodule update --init

cd "$browserdir"
npm install
echo '{}' > config.json
./node_modules/.bin/gulp build

if [ ! -e "$rootdir/public" ] ; then
  ln -s "$browserfolder/dist" "$rootdir/public" 
fi

cd "$cwd"
