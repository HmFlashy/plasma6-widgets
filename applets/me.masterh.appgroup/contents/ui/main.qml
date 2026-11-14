import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami
import org.kde.ksvg as KSvg

PlasmoidItem {
    id: root

    hideOnWindowDeactivate: !popupPinned

    property bool popupPinned: false
    property int dragSourceIndex: -1

    readonly property string groupTitle: Plasmoid.configuration.title || "Applications"
    readonly property int gridColumns: Math.max(2, Math.min(6, Plasmoid.configuration.columns || 3))
    readonly property int previewGridSize: Math.max(2, Math.min(3, Plasmoid.configuration.previewGrid || 2))
    readonly property int tileIconSize: Math.max(24, Math.min(96, Plasmoid.configuration.popupIconSize || 48))
    readonly property bool inEditMode: Plasmoid.containment && Plasmoid.containment.corona ? Plasmoid.containment.corona.editMode : false
    readonly property var apps: {
        try {
            const parsed = JSON.parse(Plasmoid.configuration.appsJson || "[]")
            return Array.isArray(parsed) ? parsed : []
        } catch (e) {
            return []
        }
    }

    toolTipMainText: groupTitle
    toolTipSubText: apps.length === 0
        ? "Vide — clic droit → Configurer pour ajouter des apps"
        : apps.length + (apps.length > 1 ? " éléments" : " élément")

    P5Support.DataSource {
        id: launcher
        engine: "executable"
        connectedSources: []
        onNewData: (sourceName, data) => {
            disconnectSource(sourceName)
        }
    }

    P5Support.DataSource {
        id: dropParser
        engine: "executable"
        connectedSources: []
        onNewData: (sourceName, data) => {
            const stdout = (data["stdout"] || "").trim()
            disconnectSource(sourceName)
            if (!stdout) return
            try {
                const item = JSON.parse(stdout)
                if (item && item.target) {
                    const next = root.apps.slice()
                    if (!next.some(x => x.target === item.target)) {
                        next.push(item)
                        Plasmoid.configuration.appsJson = JSON.stringify(next)
                    }
                }
            } catch (e) {}
        }
    }

    function shellQuote(str) {
        return "'" + String(str).replace(/'/g, "'\\''") + "'"
    }

    function launchItem(item) {
        if (!item || !item.target) return
        const target = item.target
        let cmd = ""
        if (target.startsWith("cmd:")) {
            cmd = target.slice(4) + " >/dev/null 2>&1 &"
        } else {
            cmd = "kioclient exec " + shellQuote(target) + " >/dev/null 2>&1 &"
        }
        launcher.connectSource(cmd)
        if (!root.popupPinned) root.expanded = false
    }

    function moveItem(fromIndex, toIndex) {
        if (fromIndex < 0 || fromIndex >= root.apps.length || toIndex < 0 || toIndex >= root.apps.length || fromIndex === toIndex) return
        const next = root.apps.slice()
        const moved = next.splice(fromIndex, 1)[0]
        next.splice(toIndex, 0, moved)
        Plasmoid.configuration.appsJson = JSON.stringify(next)
    }

    function removeItem(index) {
        if (index < 0 || index >= root.apps.length) return
        const next = root.apps.slice()
        next.splice(index, 1)
        Plasmoid.configuration.appsJson = JSON.stringify(next)
    }

    function addDroppedUrls(urls) {
        if (!urls || urls.length === 0) return
        for (let i = 0; i < urls.length; i++) {
            const raw = String(urls[i]).trim()
            if (!raw) continue
            const script =
                "python3 -c " +
                shellQuote(
                    "import json, sys, urllib.parse, os\n" +
                    "u = sys.argv[1]\n" +
                    "p = urllib.parse.unquote(u[7:]) if u.startswith('file://') else u\n" +
                    "if u.startswith('applications:'):\n" +
                    "    bid = u[len('applications:'):]\n" +
                    "    for d in [os.path.expanduser('~/.local/share/applications'), '/usr/share/applications', os.path.expanduser('~/.local/share/flatpak/exports/share/applications'), '/var/lib/flatpak/exports/share/applications']:\n" +
                    "        cand = os.path.join(d, bid)\n" +
                    "        if os.path.isfile(cand): p = cand; break\n" +
                    "name, icon = os.path.basename(p.rstrip('/')) or p, 'application-x-executable'\n" +
                    "if p.endswith('.desktop') and os.path.isfile(p):\n" +
                    "    in_main = False\n" +
                    "    for line in open(p, errors='ignore'):\n" +
                    "        s = line.strip()\n" +
                    "        if s.startswith('['): in_main = (s == '[Desktop Entry]'); continue\n" +
                    "        if not in_main or '=' not in s: continue\n" +
                    "        k, v = s.split('=', 1)\n" +
                    "        if k == 'Name' and name == os.path.basename(p.rstrip('/')): name = v\n" +
                    "        elif k == 'Icon': icon = v\n" +
                    "elif u.startswith('http://') or u.startswith('https://'):\n" +
                    "    name = urllib.parse.urlparse(u).netloc or u\n" +
                    "    icon = 'internet-web-browser'\n" +
                    "elif os.path.isdir(p):\n" +
                    "    icon = 'folder'\n" +
                    "target = p if (u.startswith('file://') or u.startswith('applications:')) else u\n" +
                    "print(json.dumps({'name': name, 'icon': icon, 'target': target}))\n"
                ) + " " + shellQuote(raw)
            dropParser.connectSource(script)
        }
    }

    function handleDrop(drop) {
        if (drop.hasUrls && drop.urls.length > 0) {
            addDroppedUrls(drop.urls)
            drop.acceptProposedAction()
            return
        }
        if (drop.hasText && drop.text.trim().length > 0) {
            const lines = drop.text.trim().split(/[\r\n]+/)
            addDroppedUrls(lines)
            drop.acceptProposedAction()
        }
    }

    compactRepresentation: Item {
        id: compactRoot
        Layout.minimumWidth: Kirigami.Units.iconSizes.medium + Kirigami.Units.smallSpacing * 2
        Layout.minimumHeight: Kirigami.Units.iconSizes.medium
        Layout.preferredWidth: height + Kirigami.Units.smallSpacing
        Layout.preferredHeight: parent ? parent.height : Kirigami.Units.iconSizes.large

        readonly property int iconAreaSize: Math.max(20, Math.min(width, height) - Kirigami.Units.smallSpacing * 2.5)
        readonly property int cellSpacing: root.previewGridSize === 3 ? 1 : 2
        readonly property int cellSize: Math.max(6, Math.floor((iconAreaSize - 4 - cellSpacing * (root.previewGridSize - 1)) / root.previewGridSize))

        KSvg.FrameSvgItem {
            id: taskFrame
            anchors.fill: parent
            imagePath: "widgets/tasks"
            prefix: root.expanded
                ? "focus"
                : (compactHover.containsMouse || dropCompact.containsDrag ? "hover" : "normal")
        }

        Rectangle {
            id: folderBox
            anchors.centerIn: parent
            width: compactRoot.iconAreaSize
            height: compactRoot.iconAreaSize
            radius: Math.max(5, Math.round(width * 0.22))
            scale: compactHover.pressed
                ? 0.90
                : (dropCompact.containsDrag
                    ? 1.12
                    : (root.expanded ? 1.06 : (compactHover.containsMouse ? 1.08 : 1.0)))
            color: dropCompact.containsDrag
                ? Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g, Kirigami.Theme.highlightColor.b, 0.25)
                : Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.12)
            border.width: 1
            border.color: dropCompact.containsDrag
                ? Kirigami.Theme.highlightColor
                : Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.22)

            Behavior on scale {
                NumberAnimation { duration: 160; easing.type: Easing.OutBack }
            }
            Behavior on color {
                ColorAnimation { duration: 150 }
            }
            Behavior on border.color {
                ColorAnimation { duration: 150 }
            }

            Kirigami.Icon {
                anchors.centerIn: parent
                width: Math.round(parent.width * 0.72)
                height: width
                source: "folder-activities"
                visible: root.apps.length === 0
            }

            Grid {
                anchors.centerIn: parent
                columns: root.previewGridSize
                rows: root.previewGridSize
                spacing: compactRoot.cellSpacing
                visible: root.apps.length > 0

                Repeater {
                    model: root.apps.slice(0, root.previewGridSize * root.previewGridSize)
                    delegate: Kirigami.Icon {
                        id: miniIcon
                        required property var modelData
                        required property int index
                        readonly property bool activeHover: compactHover.containsMouse || dropCompact.containsDrag
                        readonly property real mid: (root.previewGridSize - 1) / 2.0
                        readonly property real dx: (index % root.previewGridSize) - mid
                        readonly property real dy: Math.floor(index / root.previewGridSize) - mid

                        width: compactRoot.cellSize
                        height: compactRoot.cellSize
                        source: modelData.icon || "application-x-executable"
                        smooth: true
                        scale: activeHover ? 1.12 : 1.0
                        rotation: activeHover ? (dx < 0 ? -7 : (dx > 0 ? 7 : 0)) : 0
                        transform: Translate {
                            x: miniIcon.activeHover ? miniIcon.dx * 1.6 : 0
                            y: miniIcon.activeHover ? miniIcon.dy * 1.6 : 0
                            Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }
                            Behavior on y { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }
                        }
                        Behavior on scale {
                            NumberAnimation { duration: 180; easing.type: Easing.OutBack }
                        }
                        Behavior on rotation {
                            NumberAnimation { duration: 200; easing.type: Easing.OutBack }
                        }
                    }
                }
            }
        }

        MouseArea {
            id: compactHover
            anchors.fill: parent
            enabled: !root.inEditMode
            hoverEnabled: true
            onClicked: root.expanded = !root.expanded
        }

        DropArea {
            id: dropCompact
            anchors.fill: parent
            enabled: !root.inEditMode
            onEntered: (drag) => {
                if (drag.hasUrls || drag.hasText) drag.acceptProposedAction()
            }
            onDropped: (drop) => root.handleDrop(drop)
        }
    }

    fullRepresentation: Item {
        id: fullRoot
        readonly property int cellWidth: Math.max(Kirigami.Units.gridUnit * 4.6, root.tileIconSize + Kirigami.Units.gridUnit * 2.0)
        readonly property int cellHeight: Math.max(Kirigami.Units.gridUnit * 4.8, root.tileIconSize + Kirigami.Units.gridUnit * 2.4)
        readonly property int effectiveCols: root.apps.length === 0 ? 1 : Math.min(root.gridColumns, root.apps.length)
        readonly property int visibleRows: Math.max(1, Math.min(4, Math.ceil(Math.max(1, root.apps.length) / root.gridColumns)))
        readonly property int autoWidth: Math.max(Kirigami.Units.gridUnit * 12, effectiveCols * cellWidth + Kirigami.Units.largeSpacing * 2)
        readonly property int autoHeight: headerRow.implicitHeight + (root.apps.length === 0 ? Kirigami.Units.gridUnit * 6 : visibleRows * cellHeight) + Kirigami.Units.largeSpacing * 3 + Kirigami.Units.smallSpacing * 2

        implicitWidth: Plasmoid.configuration.customPopupWidth > 0 ? Plasmoid.configuration.customPopupWidth : autoWidth
        implicitHeight: Plasmoid.configuration.customPopupHeight > 0 ? Plasmoid.configuration.customPopupHeight : autoHeight
        Layout.preferredWidth: implicitWidth
        Layout.preferredHeight: implicitHeight
        Layout.minimumWidth: Kirigami.Units.gridUnit * 10
        Layout.minimumHeight: Kirigami.Units.gridUnit * 7

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.smallSpacing

            RowLayout {
                id: headerRow
                Layout.fillWidth: true

                Kirigami.Heading {
                    Layout.fillWidth: true
                    level: 4
                    text: root.groupTitle
                    elide: Text.ElideRight
                }

                PlasmaComponents.ToolButton {
                    icon.name: "window-pin"
                    checkable: true
                    checked: root.popupPinned
                    display: PlasmaComponents.AbstractButton.IconOnly
                    PlasmaComponents.ToolTip.text: root.popupPinned ? "Détacher le popup" : "Épingler le popup (reste ouvert)"
                    PlasmaComponents.ToolTip.visible: hovered
                    onToggled: root.popupPinned = checked
                }

                PlasmaComponents.ToolButton {
                    icon.name: "configure"
                    display: PlasmaComponents.AbstractButton.IconOnly
                    PlasmaComponents.ToolTip.text: "Configurer le groupe"
                    PlasmaComponents.ToolTip.visible: hovered
                    onClicked: Plasmoid.internalAction("configure").trigger()
                }
            }

            Kirigami.Separator {
                Layout.fillWidth: true
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                ColumnLayout {
                    anchors.centerIn: parent
                    width: parent.width - Kirigami.Units.largeSpacing * 2
                    visible: root.apps.length === 0
                    spacing: Kirigami.Units.smallSpacing

                    PlasmaComponents.Label {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        opacity: 0.75
                        text: "Aucune application.\nGlisse des apps ici ou clique sur Configurer."
                    }

                    PlasmaComponents.Button {
                        Layout.alignment: Qt.AlignHCenter
                        icon.name: "list-add"
                        text: "Ajouter des applications"
                        onClicked: Plasmoid.internalAction("configure").trigger()
                    }
                }

                GridView {
                    id: appGrid
                    anchors.fill: parent
                    visible: root.apps.length > 0
                    clip: true
                    cellWidth: fullRoot.cellWidth
                    cellHeight: fullRoot.cellHeight
                    model: root.apps

                    delegate: Item {
                        id: tileRoot
                        required property var modelData
                        required property int index
                        width: appGrid.cellWidth
                        height: appGrid.cellHeight

                        Rectangle {
                            id: tileCard
                            anchors.fill: parent
                            anchors.margins: 3
                            radius: Kirigami.Units.smallSpacing
                            opacity: root.dragSourceIndex === tileRoot.index ? 0.45 : 1.0
                            scale: tileMouse.pressed ? 0.93 : (tileMouse.containsMouse || tileDrop.containsDrag ? 1.05 : 1.0)
                            color: tileDrop.containsDrag
                                ? Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g, Kirigami.Theme.highlightColor.b, 0.32)
                                : (tileMouse.containsMouse
                                    ? Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g, Kirigami.Theme.highlightColor.b, 0.20)
                                    : "transparent")
                            border.width: (tileMouse.containsMouse || tileDrop.containsDrag) ? 1 : 0
                            border.color: Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g, Kirigami.Theme.highlightColor.b, 0.55)

                            Behavior on scale {
                                NumberAnimation { duration: 130; easing.type: Easing.OutQuad }
                            }
                            Behavior on color {
                                ColorAnimation { duration: 120 }
                            }

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: Kirigami.Units.smallSpacing
                                spacing: 4

                                Kirigami.Icon {
                                    Layout.alignment: Qt.AlignHCenter
                                    Layout.preferredWidth: root.tileIconSize
                                    Layout.preferredHeight: root.tileIconSize
                                    source: tileRoot.modelData.icon || "application-x-executable"
                                    smooth: true
                                }

                                PlasmaComponents.Label {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignTop
                                    maximumLineCount: 2
                                    wrapMode: Text.Wrap
                                    elide: Text.ElideRight
                                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                                    text: tileRoot.modelData.name || "App"
                                }
                            }
                        }

                        QQC2.Menu {
                            id: tileMenu
                            QQC2.MenuItem {
                                text: "Déplacer avant"
                                icon.name: "go-previous"
                                enabled: tileRoot.index > 0
                                onTriggered: root.moveItem(tileRoot.index, tileRoot.index - 1)
                            }
                            QQC2.MenuItem {
                                text: "Déplacer après"
                                icon.name: "go-next"
                                enabled: tileRoot.index < root.apps.length - 1
                                onTriggered: root.moveItem(tileRoot.index, tileRoot.index + 1)
                            }
                            QQC2.MenuSeparator {}
                            QQC2.MenuItem {
                                text: "Retirer du groupe"
                                icon.name: "edit-delete"
                                onTriggered: root.removeItem(tileRoot.index)
                            }
                        }

                        DropArea {
                            id: tileDrop
                            anchors.fill: parent
                            onEntered: (drag) => {
                                if (root.dragSourceIndex >= 0 || drag.hasUrls || drag.hasText) {
                                    drag.acceptProposedAction()
                                }
                            }
                            onDropped: (drop) => {
                                if (root.dragSourceIndex >= 0 && root.dragSourceIndex !== tileRoot.index) {
                                    root.moveItem(root.dragSourceIndex, tileRoot.index)
                                    root.dragSourceIndex = -1
                                    drop.acceptProposedAction()
                                    return
                                }
                                root.handleDrop(drop)
                            }
                        }

                        MouseArea {
                            id: tileMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            cursorShape: Qt.PointingHandCursor
                            drag.target: dragHandle
                            onPressed: (mouse) => {
                                if (mouse.button === Qt.LeftButton) {
                                    root.dragSourceIndex = tileRoot.index
                                }
                            }
                            onReleased: {
                                if (dragHandle.Drag.active) {
                                    dragHandle.Drag.drop()
                                }
                                dragHandle.x = 0
                                dragHandle.y = 0
                                root.dragSourceIndex = -1
                            }
                            onCanceled: {
                                dragHandle.x = 0
                                dragHandle.y = 0
                                root.dragSourceIndex = -1
                            }
                            onClicked: (mouse) => {
                                if (mouse.button === Qt.RightButton) {
                                    tileMenu.popup()
                                } else {
                                    root.launchItem(tileRoot.modelData)
                                }
                            }
                        }

                        Item {
                            id: dragHandle
                            width: 1
                            height: 1
                            Drag.active: tileMouse.drag.active
                            Drag.hotSpot.x: 0
                            Drag.hotSpot.y: 0
                        }
                    }
                }

                DropArea {
                    anchors.fill: parent
                    onEntered: (drag) => {
                        if (drag.hasUrls || drag.hasText) drag.acceptProposedAction()
                    }
                    onDropped: (drop) => root.handleDrop(drop)
                }
            }
        }
    }
}
