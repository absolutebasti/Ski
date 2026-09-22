#!/usr/bin/env python3
"""Add the DroplineWatch watchOS target to ios/Runner.xcodeproj (WP-13).

Run once, from the repo's `app/` directory:

    python3 ios/DroplineWatch/tools/add_watch_target.py
    xcodebuild -list -project ios/Runner.xcodeproj      # DroplineWatch must appear

Prerequisite: the watchOS platform must be installed in Xcode
(Xcode > Settings > Components, or `xcodebuild -downloadPlatform watchOS`).
Without it, *every* Runner build fails with
"This scheme builds an embedded Apple Watch app. watchOS NN must be installed".

Undo: `git checkout -- ios/Runner.xcodeproj/project.pbxproj`.
Everything else (target settings, capabilities, bundle id) is documented in
docs/WATCH.md — the script sets it all, the doc explains the Xcode-GUI path.
"""
import sys

PATH = 'ios/Runner.xcodeproj/project.pbxproj'
P = 'AA13000000000000000000'
SWIFT = ['DroplineWatchApp.swift', 'ContentView.swift', 'WatchModel.swift', 'WatchSessionManager.swift',
         'WorkoutManager.swift', 'WatchLive.swift', 'WatchStrings.swift', 'WatchTheme.swift']


def i(x):
    return P + x


def main():
    s = open(PATH).read()
    if 'DroplineWatch' in s:
        print('DroplineWatch target already present — nothing to do')
        return 0

    fileref = {n: i('%02X' % (0x10 + k)) for k, n in enumerate(SWIFT)}
    fileref['Info.plist'] = i('18')
    fileref['DroplineWatch.entitlements'] = i('19')
    fileref['Assets.xcassets'] = i('1A')
    bf = {n: i('%02X' % (0x20 + k)) for k, n in enumerate(SWIFT)}
    bf['Assets.xcassets'] = i('2A')

    add = ''
    for n in SWIFT:
        add += '\t\t%s /* %s in Sources */ = {isa = PBXBuildFile; fileRef = %s /* %s */; };\n' % (bf[n], n, fileref[n], n)
    add += '\t\t%s /* Assets.xcassets in Resources */ = {isa = PBXBuildFile; fileRef = %s /* Assets.xcassets */; };\n' % (bf['Assets.xcassets'], fileref['Assets.xcassets'])
    add += '\t\t%s /* DroplineWatch.app in Embed Watch Content */ = {isa = PBXBuildFile; fileRef = %s /* DroplineWatch.app */; settings = {ATTRIBUTES = (RemoveHeadersOnCopy, ); }; };\n' % (i('0E'), i('02'))
    s = s.replace('/* End PBXBuildFile section */', add + '/* End PBXBuildFile section */', 1)

    s = s.replace('/* Begin PBXContainerItemProxy section */', '''/* Begin PBXContainerItemProxy section */
\t\t%s /* PBXContainerItemProxy */ = {
\t\t\tisa = PBXContainerItemProxy;
\t\t\tcontainerPortal = 97C146E61CF9000F007C117D /* Project object */;
\t\t\tproxyType = 1;
\t\t\tremoteGlobalIDString = %s;
\t\t\tremoteInfo = DroplineWatch;
\t\t};
''' % (i('0C'), i('03')), 1)

    s = s.replace('/* Begin PBXCopyFilesBuildPhase section */', '''/* Begin PBXCopyFilesBuildPhase section */
\t\t%s /* Embed Watch Content */ = {
\t\t\tisa = PBXCopyFilesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tdstPath = "$(CONTENTS_FOLDER_PATH)/Watch";
\t\t\tdstSubfolderSpec = 16;
\t\t\tfiles = (
\t\t\t\t%s /* DroplineWatch.app in Embed Watch Content */,
\t\t\t);
\t\t\tname = "Embed Watch Content";
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t};
''' % (i('0D'), i('0E')), 1)

    add = '\t\t%s /* DroplineWatch.app */ = {isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = DroplineWatch.app; sourceTree = BUILT_PRODUCTS_DIR; };\n' % i('02')
    for n in SWIFT:
        add += '\t\t%s /* %s */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = %s; sourceTree = "<group>"; };\n' % (fileref[n], n, n)
    add += '\t\t%s /* Info.plist */ = {isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = "<group>"; };\n' % fileref['Info.plist']
    add += '\t\t%s /* DroplineWatch.entitlements */ = {isa = PBXFileReference; lastKnownFileType = text.plist.entitlements; path = DroplineWatch.entitlements; sourceTree = "<group>"; };\n' % fileref['DroplineWatch.entitlements']
    add += '\t\t%s /* Assets.xcassets */ = {isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = Assets.xcassets; sourceTree = "<group>"; };\n' % fileref['Assets.xcassets']
    s = s.replace('/* End PBXFileReference section */', add + '/* End PBXFileReference section */', 1)

    s = s.replace('/* End PBXFrameworksBuildPhase section */', '''\t\t%s /* Frameworks */ = {
\t\t\tisa = PBXFrameworksBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t};
/* End PBXFrameworksBuildPhase section */''' % i('09'), 1)

    children = ''.join('\t\t\t\t%s /* %s */,\n' % (fileref[n], n) for n in SWIFT)
    children += '\t\t\t\t%s /* Assets.xcassets */,\n' % fileref['Assets.xcassets']
    children += '\t\t\t\t%s /* Info.plist */,\n' % fileref['Info.plist']
    children += '\t\t\t\t%s /* DroplineWatch.entitlements */,\n' % fileref['DroplineWatch.entitlements']
    s = s.replace('/* End PBXGroup section */', '''\t\t%s /* DroplineWatch */ = {
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
%s\t\t\t);
\t\t\tpath = DroplineWatch;
\t\t\tsourceTree = "<group>";
\t\t};
/* End PBXGroup section */''' % (i('01'), children), 1)
    s = s.replace('\t\t\t\t331C8082294A63A400263BE5 /* RunnerTests */,\n\t\t\t);\n\t\t\tsourceTree = "<group>";',
                  '\t\t\t\t331C8082294A63A400263BE5 /* RunnerTests */,\n\t\t\t\t%s /* DroplineWatch */,\n\t\t\t);\n\t\t\tsourceTree = "<group>";' % i('01'), 1)
    s = s.replace('\t\t\t\t331C8081294A63A400263BE5 /* RunnerTests.xctest */,\n',
                  '\t\t\t\t331C8081294A63A400263BE5 /* RunnerTests.xctest */,\n\t\t\t\t%s /* DroplineWatch.app */,\n' % i('02'), 1)

    s = s.replace('/* End PBXNativeTarget section */', '''\t\t%s /* DroplineWatch */ = {
\t\t\tisa = PBXNativeTarget;
\t\t\tbuildConfigurationList = %s /* Build configuration list for PBXNativeTarget "DroplineWatch" */;
\t\t\tbuildPhases = (
\t\t\t\t%s /* Sources */,
\t\t\t\t%s /* Frameworks */,
\t\t\t\t%s /* Resources */,
\t\t\t);
\t\t\tbuildRules = (
\t\t\t);
\t\t\tdependencies = (
\t\t\t);
\t\t\tname = DroplineWatch;
\t\t\tproductName = DroplineWatch;
\t\t\tproductReference = %s /* DroplineWatch.app */;
\t\t\tproductType = "com.apple.product-type.application";
\t\t};
/* End PBXNativeTarget section */''' % (i('03'), i('04'), i('08'), i('09'), i('0A'), i('02')), 1)

    s = s.replace('\t\t\t\t9705A1C41CF9048500538489 /* Embed Frameworks */,\n',
                  '\t\t\t\t9705A1C41CF9048500538489 /* Embed Frameworks */,\n\t\t\t\t%s /* Embed Watch Content */,\n' % i('0D'), 1)
    s = s.replace('''\t\t\tbuildRules = (
\t\t\t);
\t\t\tdependencies = (
\t\t\t);
\t\t\tname = Runner;''', '''\t\t\tbuildRules = (
\t\t\t);
\t\t\tdependencies = (
\t\t\t\t%s /* PBXTargetDependency */,
\t\t\t);
\t\t\tname = Runner;''' % i('0B'), 1)

    s = s.replace('''\t\t\t\t97C146ED1CF9000F007C117D = {
\t\t\t\t\tCreatedOnToolsVersion = 7.3.1;''', '''\t\t\t\t%s = {
\t\t\t\t\tCreatedOnToolsVersion = 26.0;
\t\t\t\t};
\t\t\t\t97C146ED1CF9000F007C117D = {
\t\t\t\t\tCreatedOnToolsVersion = 7.3.1;''' % i('03'), 1)
    s = s.replace('''\t\t\t\t331C8080294A63A400263BE5 /* RunnerTests */,
\t\t\t);
\t\t};
/* End PBXProject section */''', '''\t\t\t\t331C8080294A63A400263BE5 /* RunnerTests */,
\t\t\t\t%s /* DroplineWatch */,
\t\t\t);
\t\t};
/* End PBXProject section */''' % i('03'), 1)

    s = s.replace('/* End PBXResourcesBuildPhase section */', '''\t\t%s /* Resources */ = {
\t\t\tisa = PBXResourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t\t%s /* Assets.xcassets in Resources */,
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t};
/* End PBXResourcesBuildPhase section */''' % (i('0A'), bf['Assets.xcassets']), 1)

    srcfiles = ''.join('\t\t\t\t%s /* %s in Sources */,\n' % (bf[n], n) for n in SWIFT)
    s = s.replace('/* End PBXSourcesBuildPhase section */', '''\t\t%s /* Sources */ = {
\t\t\tisa = PBXSourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
%s\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t};
/* End PBXSourcesBuildPhase section */''' % (i('08'), srcfiles), 1)

    s = s.replace('/* End PBXTargetDependency section */', '''\t\t%s /* PBXTargetDependency */ = {
\t\t\tisa = PBXTargetDependency;
\t\t\ttarget = %s /* DroplineWatch */;
\t\t\ttargetProxy = %s /* PBXContainerItemProxy */;
\t\t};
/* End PBXTargetDependency section */''' % (i('0B'), i('03'), i('0C')), 1)

    # The watch target inherits Flutter/Generated.xcconfig so that
    # CFBundleShortVersionString / CFBundleVersion always match the phone app —
    # App Store Connect rejects a watch app whose version differs.
    settings = '''\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;
\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
\t\t\t\tASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
\t\t\t\tCLANG_ENABLE_MODULES = YES;
\t\t\t\tCODE_SIGN_ENTITLEMENTS = DroplineWatch/DroplineWatch.entitlements;
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tCURRENT_PROJECT_VERSION = "$(FLUTTER_BUILD_NUMBER)";
\t\t\t\tDEVELOPMENT_TEAM = 5GDU97KSQU;
\t\t\t\tENABLE_PREVIEWS = YES;
\t\t\t\tGENERATE_INFOPLIST_FILE = NO;
\t\t\t\tINFOPLIST_FILE = DroplineWatch/Info.plist;
\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (
\t\t\t\t\t"$(inherited)",
\t\t\t\t\t"@executable_path/Frameworks",
\t\t\t\t);
\t\t\t\tMARKETING_VERSION = "$(FLUTTER_BUILD_NAME)";
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = de.torchtechnology.dropline.watchkitapp;
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSDKROOT = watchos;
\t\t\t\tSKIP_INSTALL = YES;
\t\t\t\tSUPPORTED_PLATFORMS = "watchsimulator watchos";
\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t\tTARGETED_DEVICE_FAMILY = 4;
\t\t\t\tWATCHOS_DEPLOYMENT_TARGET = 10.0;
'''
    cfgs = ''
    for cid, name, extra in [
        (i('05'), 'Debug', '\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = "-Onone";\n\t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;\n\t\t\t\tDEBUG_INFORMATION_FORMAT = dwarf;\n'),
        (i('06'), 'Profile', '\t\t\t\tSWIFT_COMPILATION_MODE = wholemodule;\n\t\t\t\tDEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";\n'),
        (i('07'), 'Release', '\t\t\t\tSWIFT_COMPILATION_MODE = wholemodule;\n\t\t\t\tDEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";\n'),
    ]:
        cfgs += '''\t\t%s /* %s */ = {
\t\t\tisa = XCBuildConfiguration;
\t\t\tbaseConfigurationReference = 9740EEB31CF90195004384FC /* Generated.xcconfig */;
\t\t\tbuildSettings = {
%s%s\t\t\t};
\t\t\tname = %s;
\t\t};
''' % (cid, name, settings, extra, name)
    s = s.replace('/* End XCBuildConfiguration section */', cfgs + '/* End XCBuildConfiguration section */', 1)

    s = s.replace('/* End XCConfigurationList section */', '''\t\t%s /* Build configuration list for PBXNativeTarget "DroplineWatch" */ = {
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\t%s /* Debug */,
\t\t\t\t%s /* Release */,
\t\t\t\t%s /* Profile */,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t};
/* End XCConfigurationList section */''' % (i('04'), i('05'), i('07'), i('06')), 1)

    open(PATH, 'w').write(s)
    print('DroplineWatch target added to', PATH)
    return 0


if __name__ == '__main__':
    sys.exit(main())
