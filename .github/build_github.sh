# copy lc
wget https://github.com/LiveContainer/dylibify/releases/download/1.0/dylibify
chmod +x dylibify
brew install ldid

# move lc to working folder
mv "$archive_path.xcarchive/Products/Applications" Payload

# Suppress SideStore update banner: version must be strict 3-part semver (major.minor.patch),
# otherwise SemanticVersion() fails to parse and hasUpdate falls back to string mismatch = update shown.
# 9999.0.0 parses OK and is greater than any upstream LiveContainer release.
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString 9999.0.0" ./Payload/LiveContainer.app/Info.plist

# temporarily move sidestore support framrwork to tmp before zip
mkdir tmp
mv Payload/LiveContainer.app/Frameworks/SideStore.framework ./tmp

zip -r "$scheme.ipa" "Payload" -x "._*" -x ".DS_Store" -x "__MACOSX"

mv ./tmp/SideStore.framework Payload/LiveContainer.app/Frameworks

# put sidestore related keys into Info.plist and settings bundle
/usr/libexec/PlistBuddy -c 'Add :ALTAppGroups array' ./Payload/LiveContainer.app/Info.plist
/usr/libexec/PlistBuddy -c 'Add :ALTAppGroups: string group.com.SideStore.SideStore' ./Payload/LiveContainer.app/Info.plist

/usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:1 dict" ./Payload/LiveContainer.app/Info.plist
/usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:1:CFBundleURLName string com.kdt.livecontainer.sidestoreurlscheme" ./Payload/LiveContainer.app/Info.plist
/usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:1:CFBundleURLSchemes array" ./Payload/LiveContainer.app/Info.plist
/usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:1:CFBundleURLSchemes:0 string sidestore" ./Payload/LiveContainer.app/Info.plist
/usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:2 dict" ./Payload/LiveContainer.app/Info.plist
/usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:2:CFBundleURLName string com.kdt.livecontainer.sidestorebackupurlscheme" ./Payload/LiveContainer.app/Info.plist
/usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:2:CFBundleURLSchemes array" ./Payload/LiveContainer.app/Info.plist
/usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:2:CFBundleURLSchemes:0 string sidestore-com.kdt.livecontainer" ./Payload/LiveContainer.app/Info.plist

/usr/libexec/PlistBuddy -c "Add :INIntentsSupported array" ./Payload/LiveContainer.app/Info.plist
/usr/libexec/PlistBuddy -c "Add :INIntentsSupported:0 string RefreshAllIntent" ./Payload/LiveContainer.app/Info.plist
/usr/libexec/PlistBuddy -c "Add :INIntentsSupported:1 string ViewAppIntent" ./Payload/LiveContainer.app/Info.plist
/usr/libexec/PlistBuddy -c "Add :NSUserActivityTypes array" ./Payload/LiveContainer.app/Info.plist
/usr/libexec/PlistBuddy -c "Add :NSUserActivityTypes:0 string RefreshAllIntent" ./Payload/LiveContainer.app/Info.plist
/usr/libexec/PlistBuddy -c "Add :NSUserActivityTypes:1 string ViewAppIntent" ./Payload/LiveContainer.app/Info.plist

/usr/libexec/PlistBuddy -c "Add :PreferenceSpecifiers:3:Type string PSToggleSwitchSpecifier" ./Payload/LiveContainer.app/Settings.bundle/Root.plist
/usr/libexec/PlistBuddy -c "Add :PreferenceSpecifiers:3:Title string Open SideStore" ./Payload/LiveContainer.app/Settings.bundle/Root.plist
/usr/libexec/PlistBuddy -c "Add :PreferenceSpecifiers:3:Key string LCOpenSideStore" ./Payload/LiveContainer.app/Settings.bundle/Root.plist
/usr/libexec/PlistBuddy -c "Add :PreferenceSpecifiers:3:DefaultValue bool false" ./Payload/LiveContainer.app/Settings.bundle/Root.plist

# download SideStore
cd tmp
wget https://github.com/liehuu/SideStore/releases/download/nightly/SideStore.ipa
unzip SideStore.ipa
cd ..

# SideStore
mv ./tmp/Payload/SideStore.app ./Payload/LiveContainer.app/Frameworks/SideStoreApp.framework
./dylibify ./Payload/LiveContainer.app/Frameworks/SideStoreApp.framework/SideStore ./Payload/LiveContainer.app/Frameworks/SideStoreApp.framework/SideStore.dylib
rm ./Payload/LiveContainer.app/Frameworks/SideStoreApp.framework/SideStore
mv ./Payload/LiveContainer.app/Frameworks/SideStoreApp.framework/SideStore.dylib ./Payload/LiveContainer.app/Frameworks/SideStoreApp.framework/SideStore
ldid -S"" ./Payload/LiveContainer.app/Frameworks/SideStoreApp.framework/SideStore
cp ./.github/sidelc/LCAppInfo.plist ./Payload/LiveContainer.app/Frameworks/SideStoreApp.framework/

# copy intents
cp ./Payload/LiveContainer.app/Frameworks/SideStoreApp.framework/Intents.intentdefinition ./Payload/LiveContainer.app/
cp ./Payload/LiveContainer.app/Frameworks/SideStoreApp.framework/ViewApp.intentdefinition ./Payload/LiveContainer.app/

# The main app now carries its own AppShortcutsProvider
# (LiveContainer/LCAppShortcuts.swift), so Xcode emits the app's own
# Metadata.appintents at archive time. Do NOT overwrite it with the dylibified
# SideStore's copy: that copy describes upstream's ShortcutsProvider, whose type
# is compiled into the framework binary rather than the main app one, so
# AppIntents can never resolve it -- the "Couldn't find AppShortcutsProvider"
# failure. Any leftover metadata inside the embedded bundles is likewise a
# phantom entry, so remove it.
find ./Payload/LiveContainer.app/Frameworks ./Payload/LiveContainer.app/PlugIns \
     -name "Metadata.appintents" -exec rm -rf {} + 2>/dev/null || true

# AltWidgetExtension
mv ./Payload/LiveContainer.app/Frameworks/SideStoreApp.framework/PlugIns/AltWidgetExtension.appex ./Payload/LiveContainer.app/PlugIns/LiveWidgetExtension.appex
cp -r ./Payload/LiveContainer.app/Frameworks/SideStoreApp.framework/Frameworks ./Payload/LiveContainer.app/PlugIns/LiveWidgetExtension.appex
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier com.kdt.livecontainer.LiveWidget"  ./Payload/LiveContainer.app/PlugIns/LiveWidgetExtension.appex/Info.plist
/usr/libexec/PlistBuddy -c "Set :CFBundleExecutable LiveWidgetExtension"  ./Payload/LiveContainer.app/PlugIns/LiveWidgetExtension.appex/Info.plist
mv ./Payload/LiveContainer.app/PlugIns/LiveWidgetExtension.appex/AltWidgetExtension ./Payload/LiveContainer.app/PlugIns/LiveWidgetExtension.appex/LiveWidgetExtension

# Sign
rm -r .zsign_cache
find payloadlc/Payload -type d -name "_CodeSignature" -exec rm -r {} +

ldid -S.github/sidelc/LiveWidgetExtension_adhoc.xml ./Payload/LiveContainer.app/PlugIns/LiveWidgetExtension.appex/LiveWidgetExtension

# ---------------------------------------------------------------------------
# AppIntents self-check.
# Prove the shipped bundle exposes exactly one working refresh shortcut and that
# its provider is compiled into the MAIN APP binary -- AppIntents resolves the
# provider named in the main bundle's metadata against the main app binary, so a
# provider living in an embedded framework can never be found. Runs before
# packaging so a bad build never turns into a downloadable ipa.
# ---------------------------------------------------------------------------
summary() { printf '%s\n' "$1" >> "${GITHUB_STEP_SUMMARY:-/dev/stdout}"; }

APP="./Payload/LiveContainer.app"
EXE="$APP/LiveContainer"
SELF_CHECK_PASS=true

summary "===== APPINTENTS SELF-CHECK ====="
summary "CFBundleVersion: $(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP/Info.plist" 2>/dev/null)"

# 1. the main app must ship its own generated metadata
if [ -e "$APP/Metadata.appintents" ]; then
    summary "- [OK] main app Metadata.appintents present ($(du -sh "$APP/Metadata.appintents" 2>/dev/null | awk '{print $1}'))"
else
    summary "- [FAIL] main app Metadata.appintents MISSING (Xcode generated none for the main app target)"
    SELF_CHECK_PASS=false
fi

# 2. provider and intent must be compiled into the MAIN APP binary
if [ -f "$EXE" ]; then
    for sym in LiveContainerShortcutsProvider LCRefreshAllAppsIntent; do
        # grep -c rather than grep -q: -q exits early, and the resulting SIGPIPE
        # would be reported as a pipeline failure under `set -o pipefail`.
        if [ "$(strings -a "$EXE" 2>/dev/null | grep -c "$sym" || true)" -gt 0 ]; then
            summary "- [OK] $sym found in main app binary"
        else
            summary "- [FAIL] $sym NOT in main app binary (AppIntents cannot resolve the provider)"
            SELF_CHECK_PASS=false
        fi
    done
    # informational: the legacy SiriKit class the old migration-backed intent depended on
    summary "- [info] legacy 'RefreshAllIntent' hits in main app binary: $(strings -a "$EXE" 2>/dev/null | grep -c 'RefreshAllIntent' || true)"
else
    summary "- [FAIL] main app executable not found at $EXE"
    SELF_CHECK_PASS=false
fi

# 3. the framework must export the C entry points the main app dlopen()s
FW="$APP/Frameworks/SideStore.framework/SideStore"
if [ -f "$FW" ]; then
    for sym in LCRefreshAllAppsStart LCRefreshAllAppsIsRunning; do
        if nm -gU "$FW" 2>/dev/null | grep -q "$sym"; then
            summary "- [OK] $sym exported by SideStore.framework"
        else
            summary "- [FAIL] $sym NOT exported by SideStore.framework (main app cannot drive the refresh)"
            SELF_CHECK_PASS=false
        fi
    done
else
    summary "- [FAIL] SideStore.framework not found at $FW"
    SELF_CHECK_PASS=false
fi

# 4. no competing metadata left inside embedded bundles
STRAY=$(find "$APP/Frameworks" "$APP/PlugIns" -name "Metadata.appintents" 2>/dev/null | wc -l | tr -d ' ')
if [ "$STRAY" -eq 0 ]; then
    summary "- [OK] no Metadata.appintents under Frameworks/PlugIns (no phantom provider)"
else
    summary "- [FAIL] $STRAY stray Metadata.appintents under Frameworks/PlugIns"
    SELF_CHECK_PASS=false
fi

summary ""
if [ "$SELF_CHECK_PASS" = true ]; then
    summary "VERDICT: [CLEAN] provider is in the main app binary -- safe to install."
else
    summary "VERDICT: [FAIL] do NOT install; no ipa produced."
    exit 1
fi
summary "===== END APPINTENTS SELF-CHECK ====="

# package
zip -r "$scheme+SideStore.ipa" "Payload" -x "._*" -x ".DS_Store" -x "__MACOSX"