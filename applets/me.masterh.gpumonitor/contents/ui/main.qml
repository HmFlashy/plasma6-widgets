import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    property bool gpuActive: false
    property string gpuName: "NVIDIA GPU"
    property real gpuUtil: 0
    property real gpuTemp: 0
    property real gpuClock: 0
    property real gpuMaxClock: 2000
    property real gpuVramUsed: 0
    property real gpuVramTotal: 4096
    property real gpuPower: 0
    property real gpuMaxPower: 80

    property var utilHistory: []
    property var tempHistory: []
    property var clockHistory: []
    property var vramHistory: []
    property var powerHistory: []
    property int idleZeroCount: 0
    property int cooldownTicks: 0

    readonly property bool hideWhenSuspended: Plasmoid.configuration.hideWhenSuspended
    readonly property int maxSamples: Plasmoid.configuration.maxSamples
    readonly property bool inEditMode: Plasmoid.containment && Plasmoid.containment.corona ? Plasmoid.containment.corona.editMode : false
    readonly property bool showCard: root.gpuActive || !root.hideWhenSuspended || root.inEditMode

    readonly property string passiveCmd: "for d in /sys/bus/pci/devices/*; do v=$(cat \"$d/vendor\" 2>/dev/null); c=$(cat \"$d/class\" 2>/dev/null); if [ \"$v\" = \"0x10de\" ] && { [ \"${c#0x0300}\" != \"$c\" ] || [ \"${c#0x0302}\" != \"$c\" ]; }; then cat \"$d/power/runtime_status\" 2>/dev/null || echo active; exit 0; fi; done"
    readonly property string activeCmd: "s=active; for d in /sys/bus/pci/devices/*; do v=$(cat \"$d/vendor\" 2>/dev/null); c=$(cat \"$d/class\" 2>/dev/null); if [ \"$v\" = \"0x10de\" ] && { [ \"${c#0x0300}\" != \"$c\" ] || [ \"${c#0x0302}\" != \"$c\" ]; }; then s=$(cat \"$d/power/runtime_status\" 2>/dev/null || echo active); break; fi; done; if [ \"$s\" = \"active\" ]; then nvidia-smi --query-gpu=utilization.gpu,temperature.gpu,clocks.current.graphics,memory.used,memory.total,power.draw,clocks.max.graphics,power.limit,name --format=csv,noheader,nounits 2>/dev/null | head -n1; else echo SUSPENDED; fi"
    readonly property string checkCmd: cooldownTicks > 0 ? passiveCmd : activeCmd

    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: root.showCard ? PlasmaCore.Types.DefaultBackground : PlasmaCore.Types.NoBackground

    function pushSample(arr, val) {
        var next = arr.slice()
        next.push(val)
        while (next.length > root.maxSamples) {
            next.shift()
        }
        return next
    }

    P5Support.DataSource {
        id: executable
        engine: "executable"
        connectedSources: [root.checkCmd]
        interval: Plasmoid.configuration.intervalMs

        onNewData: function(sourceName, data) {
            var out = (data["stdout"] || "").trim()
            if (!out || out === "SUSPENDED" || out === "suspended") {
                root.cooldownTicks = 0
                root.idleZeroCount = 0
                if (root.gpuActive) {
                    root.gpuActive = false
                    root.utilHistory = []
                    root.tempHistory = []
                    root.clockHistory = []
                    root.vramHistory = []
                    root.powerHistory = []
                }
                return
            }
            if (out === "active") {
                if (root.cooldownTicks > 0) {
                    root.cooldownTicks -= 1
                }
                return
            }
            var parts = out.split(",")
            if (parts.length >= 6) {
                var u = parseFloat(parts[0].trim())
                var t = parseFloat(parts[1].trim())
                var c = parseFloat(parts[2].trim())
                var vu = parseFloat(parts[3].trim())
                var vt = parseFloat(parts[4].trim())
                var pw = parseFloat(parts[5].trim())
                var mc = parts.length > 6 ? parseFloat(parts[6].trim()) : NaN
                var pl = parts.length > 7 ? parseFloat(parts[7].trim()) : NaN
                var rawName = parts.length > 8 ? parts.slice(8).join(",").trim() : ""
                root.gpuActive = true
                if (rawName) {
                    var cleanName = rawName.replace(/^NVIDIA\s+(GeForce\s+)?/, "").trim()
                    if (cleanName) root.gpuName = cleanName
                }
                if (!isNaN(mc) && mc > 0) { root.gpuMaxClock = mc }
                if (!isNaN(pl) && pl > 0) {
                    root.gpuMaxPower = pl
                } else if (!isNaN(pw) && pw > root.gpuMaxPower) {
                    root.gpuMaxPower = Math.ceil(pw / 20) * 20
                }
                if (!isNaN(u)) { root.gpuUtil = u; root.utilHistory = root.pushSample(root.utilHistory, u) }
                if (!isNaN(t)) { root.gpuTemp = t; root.tempHistory = root.pushSample(root.tempHistory, t) }
                if (!isNaN(c)) { root.gpuClock = c; root.clockHistory = root.pushSample(root.clockHistory, c) }
                if (!isNaN(vt) && vt > 0) { root.gpuVramTotal = vt }
                if (!isNaN(vu)) { root.gpuVramUsed = vu; root.vramHistory = root.pushSample(root.vramHistory, vu) }
                if (!isNaN(pw)) { root.gpuPower = pw; root.powerHistory = root.pushSample(root.powerHistory, pw) }

                // If GPU is idle (0% util & < 60 MB VRAM), pause nvidia-smi for ~12s so D3cold sleep can engage
                if ((isNaN(u) || u === 0) && (isNaN(vu) || vu < 60)) {
                    root.idleZeroCount += 1
                    if (root.idleZeroCount >= 3) {
                        root.cooldownTicks = 8
                        root.idleZeroCount = 0
                    }
                } else {
                    root.idleZeroCount = 0
                }
            }
        }
    }

    component MiniChart: Item {
        id: chart
        property var samples: []
        property real maxValue: 100
        property color lineColor: "#2ecc71"
        property string labelText: ""
        property string valueText: ""
        property string unitSuffix: ""

        Layout.fillWidth: true
        Layout.fillHeight: true
        implicitHeight: innerCol.implicitHeight
        Layout.minimumHeight: innerCol.implicitHeight
        clip: true

        onSamplesChanged: canvas.requestPaint()

        ColumnLayout {
            id: innerCol
            anchors.fill: parent
            spacing: 4

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 6

                ColumnLayout {
                    Layout.fillHeight: true
                    PlasmaComponents.Label { text: Math.round(chart.maxValue) + chart.unitSuffix; font.pointSize: Kirigami.Theme.smallFont.pointSize; opacity: 0.7 }
                    Item { Layout.fillHeight: true }
                    PlasmaComponents.Label { text: Math.round(chart.maxValue * 0.5) + chart.unitSuffix; font.pointSize: Kirigami.Theme.smallFont.pointSize; opacity: 0.7 }
                    Item { Layout.fillHeight: true }
                    PlasmaComponents.Label { text: "0" + chart.unitSuffix; font.pointSize: Kirigami.Theme.smallFont.pointSize; opacity: 0.7 }
                }

                Canvas {
                    id: canvas
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.clearRect(0, 0, width, height)

                        ctx.strokeStyle = "rgba(255, 255, 255, 0.14)"
                        ctx.lineWidth = 1
                        for (var g = 0; g <= 4; g++) {
                            var gy = Math.round((height - 1) * g / 4) + 0.5
                            ctx.beginPath()
                            ctx.moveTo(0, gy)
                            ctx.lineTo(width, gy)
                            ctx.stroke()
                        }

                        var pts = chart.samples
                        if (!pts || pts.length < 2) return

                        var n = root.maxSamples
                        var stepX = width / (n - 1)
                        var startIdx = n - pts.length

                        ctx.beginPath()
                        for (var i = 0; i < pts.length; i++) {
                            var x = (startIdx + i) * stepX
                            var norm = Math.max(0, Math.min(1, pts[i] / chart.maxValue))
                            var y = height - 1 - norm * (height - 2)
                            if (i === 0) ctx.moveTo(x, y)
                            else ctx.lineTo(x, y)
                        }

                        ctx.strokeStyle = chart.lineColor
                        ctx.lineWidth = 1.6
                        ctx.stroke()

                        ctx.lineTo((startIdx + pts.length - 1) * stepX, height - 1)
                        ctx.lineTo(startIdx * stepX, height - 1)
                        ctx.closePath()
                        ctx.fillStyle = Qt.rgba(chart.lineColor.r, chart.lineColor.g, chart.lineColor.b, 0.22)
                        ctx.fill()
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                Rectangle {
                    width: 4
                    height: 14
                    color: chart.lineColor
                    radius: 1
                }
                PlasmaComponents.Label {
                    text: chart.labelText
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                PlasmaComponents.Label {
                    text: chart.valueText
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                }
            }
        }
    }

    fullRepresentation: Item {
        readonly property int visibleCharts: (Plasmoid.configuration.showTemp ? 1 : 0)
            + (Plasmoid.configuration.showClock ? 1 : 0)
            + (Plasmoid.configuration.showUtil ? 1 : 0)
            + (Plasmoid.configuration.showVram ? 1 : 0)
            + (Plasmoid.configuration.showPower ? 1 : 0)
        readonly property int chartRows: Math.max(1, Math.ceil(visibleCharts / 2))

        Layout.minimumWidth: Kirigami.Units.gridUnit * 18
        Layout.minimumHeight: Kirigami.Units.gridUnit * (3 + chartRows * 5)
        Layout.preferredWidth: Kirigami.Units.gridUnit * 24
        Layout.preferredHeight: Kirigami.Units.gridUnit * (3.5 + chartRows * 5.8)

        visible: root.showCard

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.smallSpacing

            PlasmaComponents.Label {
                Layout.alignment: Qt.AlignHCenter
                text: root.gpuActive ? root.gpuName : root.gpuName + " (en veille)"
                font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.15
                opacity: root.gpuActive ? 0.95 : 0.6
            }

            GridLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: root.gpuActive
                columns: 2
                rowSpacing: Kirigami.Units.mediumSpacing
                columnSpacing: Kirigami.Units.mediumSpacing

                MiniChart {
                    visible: Plasmoid.configuration.showTemp
                    samples: root.tempHistory
                    maxValue: 90
                    lineColor: Plasmoid.configuration.tempColor
                    labelText: "Température"
                    valueText: Math.round(root.gpuTemp) + " °C"
                    unitSuffix: " °C"
                }

                MiniChart {
                    visible: Plasmoid.configuration.showClock
                    samples: root.clockHistory
                    maxValue: root.gpuMaxClock
                    lineColor: Plasmoid.configuration.clockColor
                    labelText: "Fréquence"
                    valueText: (root.gpuClock / 1000).toFixed(2) + " GHz"
                    unitSuffix: " MHz"
                }

                MiniChart {
                    visible: Plasmoid.configuration.showUtil
                    samples: root.utilHistory
                    maxValue: 100
                    lineColor: Plasmoid.configuration.utilColor
                    labelText: "Utilisation totale"
                    valueText: Math.round(root.gpuUtil) + " %"
                    unitSuffix: " %"
                }

                MiniChart {
                    visible: Plasmoid.configuration.showVram
                    samples: root.vramHistory
                    maxValue: root.gpuVramTotal
                    lineColor: Plasmoid.configuration.vramColor
                    labelText: "VRAM"
                    valueText: Math.round(root.gpuVramUsed) + " Mo"
                    unitSuffix: " Mo"
                }

                MiniChart {
                    visible: Plasmoid.configuration.showPower
                    samples: root.powerHistory
                    maxValue: root.gpuMaxPower
                    lineColor: Plasmoid.configuration.powerColor
                    labelText: "Puissance"
                    valueText: Math.round(root.gpuPower) + " W"
                    unitSuffix: " W"
                }
            }
        }
    }
}
