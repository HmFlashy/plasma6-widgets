import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Dialogs
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.kde.plasma.plasma5support as P5Support

KCM.SimpleKCM {
    id: configRoot

    property alias cfg_title: titleField.text
    property alias cfg_linkedFolder: linkedFolderField.text
    property alias cfg_previewGrid: previewGridSpin.value
    property alias cfg_popupIconSize: iconSizeSpin.value
    property alias cfg_customPopupWidth: widthSpin.value
    property alias cfg_customPopupHeight: heightSpin.value
    property string cfg_appsJson: "[]"

    property var currentApps: []
    property var installedApps: []
    property string searchQuery: ""

    onCfg_appsJsonChanged: {
        try {
            const parsed = JSON.parse(cfg_appsJson || "[]")
            if (Array.isArray(parsed)) currentApps = parsed
        } catch (e) {
            currentApps = []
        }
    }

    function saveApps(list) {
        currentApps = list
        cfg_appsJson = JSON.stringify(list)
    }

    function addApp(item) {
        const next = currentApps.slice()
        if (!next.some(x => x.target === item.target && x.name === item.name)) {
            next.push({ name: item.name, icon: item.icon || "application-x-executable", target: item.target })
            saveApps(next)
        }
    }

    function removeApp(index) {
        const next = currentApps.slice()
        next.splice(index, 1)
        saveApps(next)
    }

    function moveApp(index, delta) {
        const targetIndex = index + delta
        if (targetIndex < 0 || targetIndex >= currentApps.length) return
        const next = currentApps.slice()
        const tmp = next[index]
        next[index] = next[targetIndex]
        next[targetIndex] = tmp
        saveApps(next)
    }

    P5Support.DataSource {
        id: appScanner
        engine: "executable"
        connectedSources: []
        onNewData: (sourceName, data) => {
            const stdout = (data["stdout"] || "").trim()
            disconnectSource(sourceName)
            if (!stdout) return
            try {
                const list = JSON.parse(stdout)
                if (Array.isArray(list)) installedApps = list
            } catch (e) {}
        }
    }

    Component.onCompleted: {
        try {
            const parsed = JSON.parse(cfg_appsJson || "[]")
            if (Array.isArray(parsed)) currentApps = parsed
        } catch (e) {}

        const py =
            "import glob, json, os\n" +
            "dirs = [\n" +
            "    os.path.expanduser('~/.local/share/applications'),\n" +
            "    '/usr/local/share/applications',\n" +
            "    '/usr/share/applications',\n" +
            "    os.path.expanduser('~/.local/share/flatpak/exports/share/applications'),\n" +
            "    '/var/lib/flatpak/exports/share/applications',\n" +
            "    '/var/lib/snapd/desktop/applications',\n" +
            "    os.path.expanduser('~/Desktop'),\n" +
            "    os.path.expanduser('~/Bureau'),\n" +
            "]\n" +
            "seen = {}\n" +
            "for d in dirs:\n" +
            "    if not os.path.isdir(d): continue\n" +
            "    for p in sorted(glob.glob(os.path.join(d, '*.desktop'))):\n" +
            "        bid = os.path.basename(p)\n" +
            "        if bid in seen: continue\n" +
            "        name, icon, nodisp, hidden = '', 'application-x-executable', False, False\n" +
            "        in_main = False\n" +
            "        try:\n" +
            "            for line in open(p, errors='ignore'):\n" +
            "                s = line.strip()\n" +
            "                if s.startswith('['): in_main = (s == '[Desktop Entry]'); continue\n" +
            "                if not in_main or '=' not in s: continue\n" +
            "                k, v = s.split('=', 1)\n" +
            "                if k == 'Name' and not name: name = v\n" +
            "                elif k == 'Icon': icon = v\n" +
            "                elif k == 'NoDisplay' and v.lower() == 'true': nodisp = True\n" +
            "                elif k == 'Hidden' and v.lower() == 'true': hidden = True\n" +
            "        except Exception: continue\n" +
            "        if name and not nodisp and not hidden:\n" +
            "            seen[bid] = {'name': name, 'icon': icon, 'target': p}\n" +
            "print(json.dumps(sorted(seen.values(), key=lambda x: x['name'].lower())))\n"
        appScanner.connectSource("echo '" + Qt.btoa(py) + "' | base64 -d | python3 -")
    }

    readonly property var filteredInstalled: {
        const q = searchQuery.trim().toLowerCase()
        if (!q) return installedApps.slice(0, 40)
        return installedApps.filter(x => x.name.toLowerCase().includes(q) || x.target.toLowerCase().includes(q)).slice(0, 40)
    }

    ColumnLayout {
        spacing: Kirigami.Units.largeSpacing

        Kirigami.FormLayout {
            Layout.fillWidth: true

            QQC2.TextField {
                id: titleField
                Kirigami.FormData.label: "Group name:"
                placeholderText: "e.g. Dev, Games, AI…"
            }

            RowLayout {
                Kirigami.FormData.label: "Linked folder:"
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                QQC2.TextField {
                    id: linkedFolderField
                    Layout.fillWidth: true
                    placeholderText: "Optional — auto-sync .desktop apps & files from a folder"
                }

                QQC2.Button {
                    icon.name: "folder-open"
                    text: "Browse…"
                    onClicked: folderDialog.open()
                }

                QQC2.Button {
                    icon.name: "edit-clear"
                    QQC2.ToolTip.text: "Unlink folder"
                    QQC2.ToolTip.visible: hovered
                    enabled: linkedFolderField.text.length > 0
                    onClicked: linkedFolderField.text = ""
                }
            }

            FolderDialog {
                id: folderDialog
                title: "Select a folder to link to App Drawer"
                onAccepted: {
                    const p = decodeURIComponent(selectedFolder.toString().replace(/^file:\/\//, ""))
                    linkedFolderField.text = p
                }
            }

            QQC2.SpinBox {
                id: previewGridSpin
                Kirigami.FormData.label: "Panel preview (2=2×2, 3=3×3):"
                from: 2
                to: 3
            }

            QQC2.SpinBox {
                id: iconSizeSpin
                Kirigami.FormData.label: "Popup icon size (px):"
                from: 24
                to: 96
                stepSize: 8
            }

            QQC2.SpinBox {
                id: widthSpin
                Kirigami.FormData.label: "Popup width (px, 0 = auto):"
                from: 0
                to: 1200
                stepSize: 20
            }

            QQC2.SpinBox {
                id: heightSpin
                Kirigami.FormData.label: "Popup height (px, 0 = auto):"
                from: 0
                to: 900
                stepSize: 20
            }

            QQC2.Button {
                icon.name: "zoom-fit-best"
                text: "Reset to auto size"
                enabled: widthSpin.value > 0 || heightSpin.value > 0
                onClicked: {
                    widthSpin.value = 0
                    heightSpin.value = 0
                }
            }
        }

        Kirigami.Heading {
            level: 4
            text: "Applications in this group (" + currentApps.length + ")"
        }

        QQC2.Frame {
            Layout.fillWidth: true
            Layout.preferredHeight: 160

            QQC2.ScrollView {
                anchors.fill: parent
                ListView {
                    model: currentApps
                    clip: true
                    delegate: RowLayout {
                        width: ListView.view.width
                        spacing: Kirigami.Units.smallSpacing

                        Kirigami.Icon {
                            Layout.preferredWidth: 22
                            Layout.preferredHeight: 22
                            source: modelData.icon || "application-x-executable"
                        }

                        QQC2.Label {
                            Layout.fillWidth: true
                            text: modelData.name
                            elide: Text.ElideRight
                        }

                        QQC2.ToolButton {
                            icon.name: "go-up"
                            enabled: index > 0
                            onClicked: configRoot.moveApp(index, -1)
                        }

                        QQC2.ToolButton {
                            icon.name: "go-down"
                            enabled: index < currentApps.length - 1
                            onClicked: configRoot.moveApp(index, 1)
                        }

                        QQC2.ToolButton {
                            icon.name: "edit-delete"
                            onClicked: configRoot.removeApp(index)
                        }
                    }
                }
            }
        }

        Kirigami.Heading {
            level: 4
            text: "Add an application"
        }

        QQC2.TextField {
            Layout.fillWidth: true
            placeholderText: "Search installed applications (e.g. firefox, code, dolphin…)"
            onTextChanged: configRoot.searchQuery = text
        }

        QQC2.Frame {
            Layout.fillWidth: true
            Layout.preferredHeight: 160

            QQC2.ScrollView {
                anchors.fill: parent
                ListView {
                    model: configRoot.filteredInstalled
                    clip: true
                    delegate: RowLayout {
                        width: ListView.view.width
                        spacing: Kirigami.Units.smallSpacing

                        Kirigami.Icon {
                            Layout.preferredWidth: 22
                            Layout.preferredHeight: 22
                            source: modelData.icon || "application-x-executable"
                        }

                        QQC2.Label {
                            Layout.fillWidth: true
                            text: modelData.name
                            elide: Text.ElideRight
                        }

                        QQC2.Button {
                            icon.name: "list-add"
                            text: "Add"
                            onClicked: configRoot.addApp(modelData)
                        }
                    }
                }
            }
        }

        Kirigami.Heading {
            level: 4
            text: "Add a web link (URL) or command"
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            QQC2.TextField {
                id: customName
                Layout.preferredWidth: 140
                placeholderText: "Name"
            }

            QQC2.TextField {
                id: customTarget
                Layout.fillWidth: true
                placeholderText: "https://... or cmd:..."
            }

            QQC2.TextField {
                id: customIcon
                Layout.preferredWidth: 130
                placeholderText: "Icon (optional)"
                text: "internet-web-browser"
            }

            QQC2.Button {
                icon.name: "list-add"
                text: "Add"
                enabled: customTarget.text.trim().length > 0
                onClicked: {
                    configRoot.addApp({
                        name: customName.text.trim() || customTarget.text.trim(),
                        icon: customIcon.text.trim() || "internet-web-browser",
                        target: customTarget.text.trim()
                    })
                    customName.text = ""
                    customTarget.text = ""
                }
            }
        }
    }
}
