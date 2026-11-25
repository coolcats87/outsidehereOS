pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common.functions
import QtCore
import QtQuick
import Quickshell

/**
 * Paths the shell reads and writes. XDG dirs keep their "file://" prefix; the rest are plain paths.
 */
Singleton {
    // XDG dirs, with "file://"
    readonly property string home: StandardPaths.standardLocations(StandardPaths.HomeLocation)[0]
    readonly property string config: StandardPaths.standardLocations(StandardPaths.ConfigLocation)[0]
    readonly property string state: StandardPaths.standardLocations(StandardPaths.StateLocation)[0]
    readonly property string cache: StandardPaths.standardLocations(StandardPaths.CacheLocation)[0]
    readonly property string documents: StandardPaths.standardLocations(StandardPaths.DocumentsLocation)[0]
    readonly property string music: StandardPaths.standardLocations(StandardPaths.MusicLocation)[0]
    readonly property string videos: StandardPaths.standardLocations(StandardPaths.MoviesLocation)[0]

    // Inside this config folder
    property string scriptPath: Quickshell.shellPath("scripts")
    property string recordScriptPath: FileUtils.trimFileProtocol(`${Directories.scriptPath}/videos/record.sh`)

    // Settings: ~/.config/outsidehereOS/config.json
    property string shellConfig: FileUtils.trimFileProtocol(`${Directories.config}/outsidehereOS`)
    property string shellConfigPath: `${Directories.shellConfig}/config.json`

    // Runtime data
    property string notesPath: FileUtils.trimFileProtocol(`${Directories.state}/user/notes.txt`)
    property string notificationsPath: FileUtils.trimFileProtocol(`${Directories.cache}/notifications/notifications.json`)
    property string coverArt: FileUtils.trimFileProtocol(`${Directories.cache}/media/coverart`)
    property string tempImages: "/tmp/quickshell/media/images"
    property string screenshotTemp: "/tmp/quickshell/media/screenshot"

    Component.onCompleted: {
        Quickshell.execDetached(["mkdir", "-p", `${shellConfig}`])
        Quickshell.execDetached(["bash", "-c", `rm -rf '${coverArt}'; mkdir -p '${coverArt}'`])
        Quickshell.execDetached(["rm", "-rf", `${tempImages}`])
    }
}
