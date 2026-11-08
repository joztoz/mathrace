#!/bin/zsh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
cd ~/dev/mathrace
OUT=/tmp/mr-shots; rm -rf $OUT; mkdir -p $OUT
BID=funApp.Math-Race
build_ios() { xcodebuild -project "Math Race.xcodeproj" -scheme "Math Race" -destination "id=$1" -derivedDataPath /tmp/mr-dd-shots CODE_SIGNING_ALLOWED=NO build 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)"; }
prep() {
  xcrun simctl boot $1 2>/dev/null; xcrun simctl bootstatus $1 >/dev/null
  xcrun simctl ui $1 appearance light
  xcrun simctl status_bar $1 override --time "9:41" --batteryState charged --batteryLevel 100 --wifiBars 3 --cellularBars 4 2>/dev/null
}
shot() { # dev name lang wait args...
  local U=$1 NAME=$2 L=$3 W=$4; shift 4
  xcrun simctl terminate $U $BID 2>/dev/null
  xcrun simctl launch $U $BID -appLanguage $L -AppleLanguages "($L)" "$@" >/dev/null
  sleep $W
  xcrun simctl io $U screenshot "$OUT/$NAME-$L.png" >/dev/null 2>&1 && echo "ok $NAME-$L"
}
run_ios() { # udid prefix kind
  local U=$1 P=$2
  build_ios $U; prep $U
  xcrun simctl install $U "/tmp/mr-dd-shots/Build/Products/Debug-iphonesimulator/Math Race.app"
  for L in en sk; do
    shot $U $P-01-single $L 5 -shotPro -shotSingle
    shot $U $P-02-duel $L 5 -shotPro -shotDuel
    shot $U $P-03-settings $L 5 -shotPro -shotSettings
    shot $U $P-04-start $L 4
    [ "$3" = big ] && shot $U $P-00-faceoff $L 7 -shotPro -faceOffDemo -faceOffAutoStart
  done
  xcrun simctl shutdown $U
}
run_ios 94F468DB-D319-42E5-B962-D0C2E9160219 iphone small
run_ios E40C5168-3BB0-409C-808D-E161D3B7964B ipad big
# Watch
for W in 2BB6852D-DD65-4951-9AEA-08AD0E992DF3:watch-ultra 2AF48E61-5583-4A26-8247-4EE37D9DD3AC:watch-46; do
  U=${W%%:*}; N=${W##*:}
  xcodebuild -project "Math Race.xcodeproj" -scheme "Math Race Watch Watch App" -destination "id=$U" -derivedDataPath /tmp/mr-dd-shots CODE_SIGNING_ALLOWED=NO build 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)"
  xcrun simctl boot $U 2>/dev/null; xcrun simctl bootstatus $U >/dev/null
  xcrun simctl install $U "/tmp/mr-dd-shots/Build/Products/Debug-watchsimulator/Math Race Watch Watch App.app"
  xcrun simctl launch $U funApp.Math-Race.watchkitapp >/dev/null; sleep 6
  xcrun simctl io $U screenshot "$OUT/$N-01.png" >/dev/null 2>&1 && echo "ok $N"
  xcrun simctl shutdown $U
done
cd $OUT && for f in *.png; do echo "$f $(sips -g pixelWidth -g pixelHeight $f | awk '/pixel/{printf $2" "}')"; done
