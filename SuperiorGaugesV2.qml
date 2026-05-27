import QtQuick 2.5
import QtQml 2.7
import QtQuick.Controls 2.10
import QtQuick.Layouts 1.3
import QtQuick.Controls.Styles 1.4
import QtGraphicalEffects 1.0
import QtQuick.Controls.Material 2.2
import Vedder.vesc.vescinterface 1.0
import Vedder.vesc.utility 1.0
import Vedder.vesc.commands 1.0
import Vedder.vesc.configparams 1.0
Item {
    id: rtData
    property var dialogParent: ApplicationWindow.overlay
    anchors.fill: parent
    property alias updateData: commandsUpdate.enabled
    property Commands mCommands: VescIf.commands()
    property ConfigParams mMcConf: VescIf.mcConfig()
    property int odometerValue: 0
    property double efficiency_lpf: 0
    property bool isHorizontal: rtData.width > rtData.height
    property int gaugeSize: (isHorizontal ? Math.min((height)/1.25, width / 2.5 - 20) :
                                            Math.min(width / 1.37, (height) / 2.4 - 10 ))
    property int gaugeSize2: gaugeSize * 0.55

    // Kalibracja napięcia: 1.0 = brak korekcji.
    // Zwiększ jeśli VESC pokazuje za niskie napięcie, zmniejsz jeśli za wysokie (np. 1.022 = +2.2%)
    readonly property real defaultVoltageCalibMultiplier: 1.0000

    // Tabela SOC — 21 napięć pojedynczego ogniwa dla 0%, 5%, 10% … 100%
    // Zmień wartości na krzywą swojego ogniwa (muszą być rosnąco)
    readonly property var defaultSocVoltages: [
    //   0%     5%     10%    15%    20%    25%    30%
        3.110, 3.363, 3.419, 3.48, 3.521, 3.557, 3.593,
    //  35%    40%    45%    50%    55%    60%    65%
        3.625, 3.666, 3.716, 3.77, 3.819, 3.863, 3.899,
    //  70%    75%    80%    85%    90%    95%   100%
        3.948, 4.009, 4.048, 4.065, 4.076, 4.101, 4.200
    ]
    // ─────────────────────────────────────────────────────────────

    property real voltageCalibMultiplier: defaultVoltageCalibMultiplier
    property real calibratedVoltage: 0.0
    property int  socUpdateTick: 0  // throttle SOC/range updates to ~1s
    property int batterySeriesCells: 20
ListModel { id: socTableModel }
property var interpolatedSocVoltage: []   // 0-100% lookup table

function populateSocTable() {
    socTableModel.clear()
    for (var i = 0; i < 21; i++) {
        socTableModel.append({ "soc": i*5, "voltage": defaultSocVoltages[i] })
    }
}

function updateInterpolatedTable() {
    interpolatedSocVoltage = new Array(101)
    for (var i = 0; i <= 100; i++) {
        var pos = i / 5.0
        var low = Math.floor(pos)
        var high = Math.ceil(pos)
        var frac = pos - low
        var vLow = socTableModel.get(low).voltage * batterySeriesCells
        var vHigh = (low === high) ? vLow : socTableModel.get(high).voltage * batterySeriesCells
        interpolatedSocVoltage[i] = vLow * (1 - frac) + vHigh * frac
    }
}

function getCustomSoc(v) {
    if (v >= interpolatedSocVoltage[100]) return 100.0
    if (v <= interpolatedSocVoltage[0]) return 0.0
    for (var p = 0; p < 100; p++) {
        if (v >= interpolatedSocVoltage[p] && v <= interpolatedSocVoltage[p+1]) {
            var frac = (v - interpolatedSocVoltage[p]) / (interpolatedSocVoltage[p+1] - interpolatedSocVoltage[p])
            return p + frac
        }
    }
    return 0.0
}
Component.onCompleted: {
    populateSocTable()
    updateInterpolatedTable()
    startupCanDetectTimer.start()
}

// Initial CAN detection: checks after 200ms, retries every 1s for up to 20s
Timer {
    id: startupCanDetectTimer; interval: 200; repeat: false
    onTriggered: {
        var devs = VescIf.getCanDevsLast()
        screen2Item.slaveCanId = (devs.length > 0) ? devs[0] : -1
        if (screen2Item.slaveCanId < 0) { canRetryTimer.retryCount = 0; canRetryTimer.start() }
    }
}
Timer {
    id: canRetryTimer; interval: 1000; repeat: true
    property int retryCount: 0; property int maxRetries: 20
    onTriggered: {
        retryCount++
        var devs = VescIf.getCanDevsLast()
        if (devs.length > 0) { screen2Item.slaveCanId = devs[0]; stop() }
        else if (retryCount >= maxRetries) stop()
    }
}
Connections {
    target: VescIf
    function onPortConnectedChanged() {
        if (VescIf.isPortConnected()) {
            screen2Item.slaveCanId = -1
            canRetryTimer.retryCount = 0; canRetryTimer.stop()
            startupCanDetectTimer.start()
        } else {
            canRetryTimer.stop(); screen2Item.slaveCanId = -1
        }
    }
}

    Rectangle { anchors.fill: parent; color: Utility.getAppHexColor("darkBackground") }

SwipeView {
    id: swipeView
    anchors.fill: parent
    orientation: Qt.Vertical
    currentIndex: 0
    clip: true

    Item {
        GridLayout {
            anchors.fill: parent
            columns: isHorizontal ? 2 : 1
            columnSpacing: 0
            rowSpacing: 0

               GridLayout {
        width: parent.width
        height: parent.height
        columns: isHorizontal ? 2 : 1
        columnSpacing: 0
        rowSpacing: 0
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            Layout.fillWidth: true
            Layout.rowSpan: 1
            Layout.preferredHeight: gaugeSize2*1.1
            color: "transparent"
            CustomGauge {
                id: currentGauge
                width:gaugeSize2
                height:gaugeSize2
                anchors.centerIn: parent
                anchors.horizontalCenterOffset: -0.675*gaugeSize2
                anchors.verticalCenterOffset: 0.1*gaugeSize2
                minimumValue: -60
                maximumValue: 60
                value: 0
                labelStep: maximumValue > 60 ? 20 : 10
                nibColor: {nibColor = Utility.getAppHexColor("tertiary1")}
                unitText: "A"
                typeText: "Phase\nCurrent"
                minAngle: -210
                maxAngle: 15
                CustomGauge {
                    id: batCurrentGauge
                    width: gaugeSize2
                    height: gaugeSize2
                    anchors.centerIn: parent
                    anchors.horizontalCenterOffset: gaugeSize2*1.35
                    maximumValue: 99
                    minimumValue: -60
                    minAngle: 210
                    maxAngle: -15
                    labelStep: 25
                    value: 0
                    unitText: "A"
                    typeText: "Battery\nCurrent"
                    nibColor: {nibColor = Utility.getAppHexColor("tertiary1")}
                    CustomGauge {
                        id: powerGauge
                        width: gaugeSize2*1.05
                        height: gaugeSize2*1.05
                        anchors.centerIn: parent
                        anchors.horizontalCenterOffset: -0.675*gaugeSize2
                        anchors.verticalCenterOffset: -0.1*gaugeSize2
                        maximumValue: 10000
                        minimumValue: -10000
                        tickmarkScale: 0.001
                        tickmarkSuffix: "k"
                        labelStep: maximumValue > 6000 ? 2000 : 1000
                        value: 0
                        unitText: "W"
                        typeText: "Power"
                        nibColor: {nibColor = Utility.getAppHexColor("tertiary2")}
                    }
                }
            }
        }

        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            Layout.fillWidth: true
            Layout.preferredHeight: gaugeSize
            Layout.fillHeight: true
            color: "transparent"
            Layout.rowSpan: isHorizontal ? 3:1

            CustomGauge {
                id: speedGauge
                width: gaugeSize
                height: gaugeSize
                anchors.centerIn: parent
                anchors.horizontalCenterOffset: (width/4 - gaugeSize2)/2
                minimumValue: 0
                maximumValue: 60
                minAngle: -225
                maxAngle: 45
                labelStep: maximumValue > 60 ? 20 : 10
                value: 0
                unitText: VescIf.useImperialUnits() ? "mph" : "km/h"
                typeText: "Speed"

                Image {
                    anchors.centerIn: parent
                    antialiasing: true
                    opacity: 0.4
                    height: parent.height*0.05
                    fillMode: Image.PreserveAspectFit
                    source: {source = "qrc" + Utility.getThemePath() + "icons/vesc-96.png"}
                    anchors.horizontalCenterOffset: (gaugeSize)/3.25 + gaugeSize2/2
                    anchors.verticalCenterOffset: -0.8*(gaugeSize)/2
                }

                Button {
                    id: button
                    anchors.centerIn:  parent
                    anchors.horizontalCenterOffset: -0.75*(gaugeSize)/2
                    anchors.verticalCenterOffset: 0.75*(gaugeSize)/2
                    onClicked: {
                        var impFact = VescIf.useImperialUnits() ? 0.621371192 : 1.0
                        odometerBox.realValue = odometerValue*impFact/1000.0
                        settingsDialog.open()
                    }

                    Dialog {
                        id: settingsDialog
                        modal: true
                        focus: true
                        width: parent.width - 20
                        height: Math.min(implicitHeight, parent.height - 60)
                        closePolicy: Popup.CloseOnEscape

                        Overlay.modal: Rectangle {
                            color: "#AA000000"
                        }

                        x: 10
                        y: Math.max((parent.height - height) / 2, 10)
                        parent: dialogParent
                        standardButtons: Dialog.Ok | Dialog.Cancel

                        onOpened: {
                            negSpeedBox.checked = VescIf.speedGaugeUseNegativeValues()
                        }

                        onAccepted: {
                            VescIf.setSpeedGaugeUseNegativeValues(negSpeedBox.checked)
                            mCommands.emitEmptySetupValues()
                        }

                        ColumnLayout {
                            id: scrollColumn
                            anchors.fill: parent

                            ScrollView {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                clip: true
                                contentWidth: parent.width

                                ColumnLayout {
                                    anchors.fill: parent
                                    spacing: 10

                                    GroupBox {
                                        title: qsTr("Update Odometer")
                                        Layout.fillWidth: true

                                        RowLayout {
                                            anchors.fill: parent

                                            DoubleSpinBox {
                                                id: odometerBox
                                                decimals: 2
                                                realFrom: 0.0
                                                realTo: 20000000
                                                Layout.fillWidth: true
                                            }

                                            Button {
                                                text: "Set"

                                                onClicked: {
                                                    var impFact = VescIf.useImperialUnits() ? 0.621371192 : 1.0
                                                    mCommands.setOdometer(Math.round(odometerBox.realValue*1000/impFact))
                                                }
                                            }
                                        }
                                    }

                                    GroupBox {
                                        title: qsTr("Settings")
                                        Layout.fillWidth: true

                                        CheckBox {
                                            id: negSpeedBox
                                            anchors.fill: parent
                                            text: "Use Negative Speed"
                                            checked: VescIf.speedGaugeUseNegativeValues()
                                        }
                                    }
                                }
                            }
                        }
                    }
                    background: Rectangle {
                        color: {color = Utility.isDarkMode() ? Utility.getAppHexColor("darkBackground") : Utility.getAppHexColor("normalBackground")}
                        opacity: button.down ? 0 : 1
                        implicitWidth: gaugeSize2*0.28
                        implicitHeight: gaugeSize2*0.28
                        radius: 400
                        Image {
                            anchors.centerIn: parent
                            antialiasing: true
                            opacity: 0.5
                            height: parent.width*0.6
                            width: height
                            source: {source = "qrc" + Utility.getThemePath() + "icons/Settings-96.png"}
                        }
                        Canvas {
                            anchors.fill: parent
                            Component.onCompleted: requestPaint()
                            property real outerRadius: parent.width/2.0;
                            property real borderWidth: outerRadius*0.1;
                            property color lightBG: {lightBG = Utility.getAppHexColor("lightestBackground")}
                            property color darkBG: {darkBG = Utility.getAppHexColor("darkBackground")}
                            onPaint: {
                                var ctx = getContext("2d");
                                //create outer gauge metal bezel effect
                                ctx.beginPath();
                                var gradient2 = ctx.createLinearGradient(parent.width,0,0 ,parent.height);
                                // Add three color stops
                                gradient2.addColorStop(1, lightBG);
                                gradient2.addColorStop(0.7, darkBG);
                                gradient2.addColorStop(0.1, lightBG);
                                ctx.strokeStyle = gradient2;
                                ctx.lineWidth = borderWidth;
                                ctx.arc(outerRadius,
                                        outerRadius,
                                        outerRadius - borderWidth/2,
                                        0, 2 * Math.PI);
                                ctx.stroke();
                                ctx.beginPath();
                                var gradient3 = ctx.createLinearGradient(parent.width,0,0 ,parent.height);
                                // Add three color stops
                                gradient3.addColorStop(1, darkBG);
                                gradient3.addColorStop(0.8, lightBG);
                                gradient3.addColorStop(0, darkBG);
                                ctx.strokeStyle = gradient3;
                                ctx.lineWidth = borderWidth;
                                ctx.arc(outerRadius,
                                        outerRadius,
                                        outerRadius - 3*borderWidth/2,
                                        0, 2 * Math.PI);
                                ctx.stroke();
                            }
                        }
                    }
                }
                CustomGauge {
                    id: batteryGauge
                    width: gaugeSize2
                    height: gaugeSize2
                    anchors.centerIn: parent
                    anchors.horizontalCenterOffset: parent.width/4 + width/2
                    minAngle: -225
                    maxAngle: 45
                    minimumValue: 0
                    maximumValue: 100
                    value: 0
                    centerTextVisible: false
                    property color greenColor: {greenColor = "green"}
                    property color orangeColor: {orangeColor = Utility.getAppHexColor("orange")}
                    property color redColor: {redColor = "red"}
                    nibColor: value > 50 ? greenColor : value > 20 ? orangeColor : redColor
                    Text {
                        id: batteryLabel
                        color: {color = Utility.getAppHexColor("lightText")}
                        text: "BATTERY"
                        font.pixelSize: gaugeSize2/18.0
                        verticalAlignment: Text.AlignVCenter
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: - gaugeSize2*0.12
                        anchors.margins: 10
                        font.family:  "Roboto"
                    }
                    Text {
                        id: rangeValLabel
                        color: {color = Utility.getAppHexColor("lightText")}
                        text: "∞"
                        font.pixelSize: text === "∞"? gaugeSize2/6.3 : gaugeSize2/8.0
                        anchors.verticalCenterOffset: text === "∞"? -0.015*gaugeSize2 : 0
                        verticalAlignment: Text.AlignVCenter
                        anchors.centerIn: parent
                        anchors.margins: 10
                        font.family:  "Roboto"
                    }
                    Text {
                        id: rangeLabel
                        color: {color = Utility.getAppHexColor("lightText")}
                        text: "KM RANGE"
                        font.pixelSize: gaugeSize2/20.0
                        verticalAlignment: Text.AlignVCenter
                        anchors.centerIn: parent
                        anchors.horizontalCenterOffset: gaugeSize2*0.3
                        anchors.margins: 10
                        font.family:  "Roboto"
                    }
                    Text {
                        id: battValLabel
                        color: {color = Utility.getAppHexColor("lightText")}
                        text: parseFloat(batteryGauge.value).toFixed(0) +"%"
                        font.pixelSize: gaugeSize2/12.0
                        verticalAlignment: Text.AlignVCenter
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: gaugeSize2*0.15
                        //anchors.horizontalCenterOffset: (width -parent.width)/2
                        anchors.margins: 10
                        font.family:  "Roboto"
                    }
                    Behavior on nibColor {
                        ColorAnimation {
                            duration: 1000;
                            easing.type: Easing.InOutSine
                            easing.overshoot: 3
                        }
                    }
                }
            }

            Item {
                id: voltmeterRect
                anchors.centerIn: parent
                anchors.horizontalCenterOffset: parent.width/4 + gaugeSize2*0.18
                anchors.verticalCenterOffset: gaugeSize2*0.72
                width: gaugeSize2*0.86
                height: gaugeSize2*0.36
                z: 1

                Canvas {
                    id: voltmeterCanvas
                    anchors.fill: parent
                    property color bgColor: Utility.getAppHexColor("darkBackground")
                    property color borderColor: Utility.getAppHexColor("lightestBackground")
                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.clearRect(0, 0, width, height)
                        var r = 8
                        var cut = height * 0.55
                        var bw = 3

                        // fill
                        ctx.beginPath()
                        ctx.moveTo(cut, 0)
                        ctx.lineTo(width - r, 0)
                        ctx.arcTo(width, 0, width, r, r)
                        ctx.lineTo(width, height - r)
                        ctx.arcTo(width, height, width - r, height, r)
                        ctx.lineTo(r, height)
                        ctx.arcTo(0, height, 0, height - r, r)
                        ctx.lineTo(0, cut)
                        ctx.closePath()
                        ctx.fillStyle = bgColor
                        ctx.fill()

                        // border
                        ctx.beginPath()
                        ctx.moveTo(cut, 0)
                        ctx.lineTo(width - r, 0)
                        ctx.arcTo(width, 0, width, r, r)
                        ctx.lineTo(width, height - r)
                        ctx.arcTo(width, height, width - r, height, r)
                        ctx.lineTo(r, height)
                        ctx.arcTo(0, height, 0, height - r, r)
                        ctx.lineTo(0, cut)
                        ctx.closePath()
                        ctx.strokeStyle = borderColor
                        ctx.lineWidth = bw
                        ctx.stroke()
                    }
                    Connections {
                        target: voltmeterRect
                        function onWidthChanged() { voltmeterCanvas.requestPaint() }
                        function onHeightChanged() { voltmeterCanvas.requestPaint() }
                    }
                }

                Text {
                    id: voltmeterValue
                    anchors.centerIn: parent
                    anchors.horizontalCenterOffset: voltmeterRect.height * 0.1
                    color: {color = Utility.getAppHexColor("lightText")}
                    text: parseFloat(calibratedVoltage).toFixed(1) + " V"
                    font.pixelSize: gaugeSize2 * 0.22
                    font.bold: false
                    font.family: "Roboto"
                    verticalAlignment: Text.AlignVCenter
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }

        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            Layout.fillWidth: true
            Layout.preferredHeight: gaugeSize2*1.1
            Layout.rowSpan: 3
            color: "transparent"
            CustomGauge {
                id: escTempGauge
                width:gaugeSize2
                height:gaugeSize2
                anchors.centerIn: parent
                anchors.horizontalCenterOffset: -0.675*gaugeSize2
                anchors.verticalCenterOffset: -0.1*gaugeSize2
                minimumValue: 0
                maximumValue: 100
                value: 0
                labelStep: 20
                property real throttleStartValue: 70
                property color blueColor: {blueColor = Utility.getAppHexColor("tertiary2")}
                property color orangeColor: {orangeColor = Utility.getAppHexColor("orange")}
                property color redColor: {redColor = "red"}
                nibColor: value > throttleStartValue ? redColor : (value > 40 ? orangeColor: blueColor)
                Behavior on nibColor {
                    ColorAnimation {
                        duration: 1000;
                        easing.type: Easing.InOutSine
                        easing.overshoot: 3
                    }
                }
                unitText: "°C"
                typeText: "TEMP\nESC"
                minAngle: -195
                maxAngle: 30
                CustomGauge {
                    id: motTempGauge
                    width: gaugeSize2
                    height: gaugeSize2
                    anchors.centerIn: parent
                    anchors.horizontalCenterOffset: gaugeSize2*1.35
                    maximumValue: 100
                    minimumValue: 0
                    minAngle: 195
                    maxAngle: -30
                    labelStep: 20
                    value: 0
                    unitText: "°C"
                    typeText: "TEMP\nMOTOR"
                    property real throttleStartValue: 70
                    property color blueColor: {blueColor = Utility.getAppHexColor("tertiary2")}
                    property color orangeColor: {orangeColor = Utility.getAppHexColor("orange")}
                    property color redColor: {redColor = "red"}
                    nibColor: value > throttleStartValue ? redColor : (value > 40 ? orangeColor: blueColor)
                    Behavior on nibColor {
                        ColorAnimation {
                            duration: 1000;
                            easing.type: Easing.InOutSine
                            easing.overshoot: 3
                        }
                    }
                    CustomGauge {
                        id: efficiencyGauge
                        width: gaugeSize2*1.05
                        height: gaugeSize2*1.05
                        anchors.centerIn: parent
                        anchors.horizontalCenterOffset: -0.675*gaugeSize2
                        anchors.verticalCenterOffset: 0.1*gaugeSize2
                        minimumValue: -50
                        maximumValue:  50
                        minAngle: -127
                        maxAngle: 127
                        labelStep: maximumValue > 60 ? 20 : 10
                        value: 0
                        unitText: VescIf.useImperialUnits() ? "Wh/mi" : "Wh/km"
                        typeText: "Consump."
                        property color blueColor: {blueColor = Utility.getAppHexColor("tertiary2")}
                        property color orangeColor: {orangeColor = Utility.getAppHexColor("orange")}
                        property color redColor: {redColor = "red"}
                        nibColor: value > 45.0 ? redColor : (value > 25.0 ? orangeColor: blueColor)
                        Text {
                            id: consumValLabel
                            color: {color = Utility.getAppHexColor("lightText")}
                            text: "0"
                            font.pixelSize: gaugeSize2*0.15
                            anchors.verticalCenterOffset: 0.265*gaugeSize2
                            verticalAlignment: Text.AlignVCenter
                            anchors.centerIn: parent
                            anchors.margins: 10
                            font.family:  "Roboto"
                            Text {
                                id: avgLabel
                                color: {color = Utility.getAppHexColor("lightText")}
                                text: "AVG"
                                font.pixelSize: gaugeSize2*0.06
                                anchors.verticalCenterOffset: 0.135*gaugeSize2
                                verticalAlignment: Text.AlignVCenter
                                anchors.centerIn: parent
                                anchors.margins: 10
                                font.family:  "Roboto"
                            }
                        }
                        Behavior on nibColor {
                            ColorAnimation {
                                duration: 100;
                                easing.type: Easing.InOutSine
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            id: textRect
            color: "transparent"
            Layout.fillWidth: true
            Layout.preferredHeight:  gaugeSize2*0.26
            Layout.alignment: Qt.AlignBottom
            Layout.rowSpan: 1
            Layout.bottomMargin: 0
            Text {
                id: odoLabel
                color: {color = Utility.getAppHexColor("lightText")}
                text: "ODOMETER"
                anchors.horizontalCenterOffset:  gaugeSize2*-2/3
                font.pixelSize: gaugeSize2/18.0
                verticalAlignment: Text.AlignVCenter
                anchors.centerIn: parent
                anchors.verticalCenterOffset: - gaugeSize2*0.12
                anchors.margins: 10
                font.family:  "Roboto"
            }
            Text {
                id: timeLabel
                color: {color = Utility.getAppHexColor("lightText")}
                text: "UP-TIME"
                anchors.horizontalCenterOffset:  gaugeSize2*2/3
                font.pixelSize: gaugeSize2/18.0
                verticalAlignment: Text.AlignVCenter
                anchors.centerIn: parent
                anchors.verticalCenterOffset: - gaugeSize2*0.12
                anchors.margins: 10
                font.family:  "Roboto"
            }
            Text {
                id: tripLabel
                color: {color = Utility.getAppHexColor("lightText")}
                text: "TRIP"
                anchors.horizontalCenterOffset:  0
                font.pixelSize: gaugeSize2/18.0
                verticalAlignment: Text.AlignVCenter
                anchors.centerIn: parent
                anchors.verticalCenterOffset: - gaugeSize2*0.12
                anchors.margins: 10
                font.family:  "Roboto"
            }
            Rectangle {
                id:clockRect
                width:2*gaugeSize2
                height: rideTime.implicitHeight + gaugeSize2*0.025
                anchors.centerIn: parent
                color: {color = Utility.getAppHexColor("darkBackground")}
                anchors.verticalCenterOffset: gaugeSize2*0.005
                border.color: {border.color = Utility.getAppHexColor("lightestBackground")}
                border.width: 1
                radius: gaugeSize2*0.03
                Text{
                    id: rideTime
                    color: {color = Utility.getAppHexColor("lightText")}
                    anchors.horizontalCenterOffset: gaugeSize2*2/3
                    text: "00:00:00"
                    font.pixelSize: gaugeSize2/10.0
                    verticalAlignment: Text.AlignVCenter
                    font.letterSpacing: gaugeSize2*0.001
                    anchors.centerIn: parent
                    anchors.margins: 10
                    font.family:  "Exan"
                }
                Glow{
                    anchors.fill: rideTime
                    radius: 0
                    samples: 9
                    color: "#55ffffff"
                    source: rideTime
                }
                Text{
                    id: odometer
                    color: {color = Utility.getAppHexColor("lightText")}
                    anchors.horizontalCenterOffset:  gaugeSize2*-2/3
                    text: "0.0"
                    font.pixelSize: gaugeSize2/10.0
                    verticalAlignment: Text.AlignVCenter
                    font.letterSpacing: gaugeSize2*0.001
                    anchors.centerIn: parent
                    anchors.margins: 10
                    font.family:  "Exan"
                }
                Glow{
                    anchors.fill: odometer
                    radius: 0
                    samples: 9
                    color: "#55ffffff"
                    source: odometer
                }
                Text{
                    id: trip
                    color: {color = Utility.getAppHexColor("lightText")}
                    anchors.horizontalCenterOffset: 0
                    text: "0.0"
                    font.pixelSize: gaugeSize2/10.0
                    verticalAlignment: Text.AlignVCenter
                    font.letterSpacing: gaugeSize2*0.001
                    anchors.centerIn: parent
                    anchors.margins: 10
                    font.family:  "Exan"
                }
                Glow{
                    anchors.fill: trip
                    radius: 0
                    samples: 9
                    color: "#55ffffff"
                    source: trip
                }
            }
        }
    } 
            

        }
    }


    Item {
        id: screen2Item
        property bool legalModeActive: false

        property bool _legalEnable:    false
        property int  _legalSlaveId:  -1

        property int  startupSocTicksLeft: 40   // ~800ms delay before storing startup SOC
        property real startupSoc:      -1   // SOC przy starcie (pierwsze odczytanie > 0)
        property real currentSoc:       0   // aktualny SOC
        property real maxCurrentVesc1:  0   // max battery current VESC1 [A]
        property real maxCurrentVesc2:  0   // max battery current VESC2 [A]
        property int  slaveCanId:      -1   // CAN ID slave'a (-1 = nieznany)
        property real maxPowerVoltage:  0   // voltage at max power [V]
        property real maxPower:         0   // max total power [W]
        property real maxRegen:         0   // max total regen [W]
        property int  numVescs:         1   // number of VESCs
        property real totalWhConsumed:  0   // total Wh consumed
        property real totalWhCharged:   0   // total Wh recharged
        property real batteryAh:        0   // battery capacity [Ah] from config
        property real socUsedPercent:   0   // SOC used since start [%]
        property real whPerKmSoc:       0   // Wh/km from SOC
        property real tripDistKm:       0   // dystans sesji [km]
        property var  whkmWindow:       []  // rolling 2km window for Wh/km
        property real whkmVesc2km:     -1   // Wh/km last 2km (-1 = not enough data)
        property real maxMotorCurrent:  0   // max motor current [A]
        property real maxVoltage:       0   // max battery voltage [V]
        property real minVoltage:    9999   // min battery voltage [V]
        property real rangeRemainKm:   -1   // estimated remaining range [km]
        property real rangeFull100Km:  -1   // full range 100-0% [km] from SOC Wh/km
        property real rangeFull100KmVesc: -1 // full range 100-0% [km] from session Wh/km
        property real whKmSession:      -1   // session Wh/km (from power-on)
        property real startupDistKm:    -1   // tachometer_abs when script started

        function calcErpm20() {
            var poles = mMcConf.getParamInt("si_motor_poles") / 2.0
            var gear  = mMcConf.getParamDouble("si_gear_ratio")
            var wheel = mMcConf.getParamDouble("si_wheel_diameter")
            var speedFact = (poles * 60.0 * gear) / (wheel * Math.PI)
            if (speedFact < 1e-3) speedFact = 1e-3
            return (20.0 / 3.6) * speedFact
        }

        // Legal Mode: getMcconf → modify → setMcconf (permanent write), repeated for slave via CAN
        // Token guard prevents stray onUpdated from other getMcconf() calls in the app.
        // Single: 600W/30%   Dual: 300W/20%
        property int  _legalStep:    0
        property int  _legalToken:   0
        property int  _pendingToken: -1
        property real _savedMasterErpm: 0; property real _savedMasterWatt: 0; property real _savedMasterCurr: 1.0
        property real _savedSlaveErpm:  0; property real _savedSlaveWatt:  0; property real _savedSlaveCurr:  1.0

        function startLegalSequence(enable) {
            var canDevs   = VescIf.getCanDevsLast()
            _legalEnable  = enable
            _legalSlaveId = (canDevs.length > 0) ? canDevs[0] : -1
            slaveCanId    = _legalSlaveId
            _legalStep    = 1
            _legalToken   = (_legalToken + 1) % 1000
            _pendingToken = _legalToken
            VescIf.canTmpOverrideEnd()
            mCommands.getMcconf()
        }

        Connections {
            target: mMcConf
            function onUpdated() {
                if (screen2Item._legalStep === 0) return
                if (screen2Item._pendingToken !== screen2Item._legalToken) return
                screen2Item._pendingToken = -1

                var isDual = (screen2Item._legalSlaveId >= 0)
                var watt   = isDual ? 300.0 : 600.0
                var curr   = isDual ? 0.2   : 0.3
                var erpm20 = screen2Item.calcErpm20()

                if (screen2Item._legalStep === 1) {
                    if (screen2Item._legalEnable) {
                        screen2Item._savedMasterErpm = mMcConf.getParamDouble("l_max_erpm")
                        screen2Item._savedMasterWatt = mMcConf.getParamDouble("l_watt_max")
                        screen2Item._savedMasterCurr = mMcConf.getParamDouble("l_current_max_scale")
                        mMcConf.updateParamDouble("l_max_erpm", erpm20)
                        mMcConf.updateParamDouble("l_min_erpm", -erpm20)
                        mMcConf.updateParamDouble("l_watt_max", watt)
                        mMcConf.updateParamDouble("l_current_max_scale", curr)
                    } else {
                        mMcConf.updateParamDouble("l_max_erpm", screen2Item._savedMasterErpm)
                        mMcConf.updateParamDouble("l_min_erpm", -screen2Item._savedMasterErpm)
                        mMcConf.updateParamDouble("l_watt_max", screen2Item._savedMasterWatt)
                        mMcConf.updateParamDouble("l_current_max_scale", screen2Item._savedMasterCurr)
                    }
                    mCommands.setMcconf(false)
                    legalTimer.start()
                } else if (screen2Item._legalStep === 2) {
                    if (screen2Item._legalEnable) {
                        screen2Item._savedSlaveErpm = mMcConf.getParamDouble("l_max_erpm")
                        screen2Item._savedSlaveWatt = mMcConf.getParamDouble("l_watt_max")
                        screen2Item._savedSlaveCurr = mMcConf.getParamDouble("l_current_max_scale")
                        mMcConf.updateParamDouble("l_max_erpm", erpm20)
                        mMcConf.updateParamDouble("l_min_erpm", -erpm20)
                        mMcConf.updateParamDouble("l_watt_max", watt)
                        mMcConf.updateParamDouble("l_current_max_scale", curr)
                    } else {
                        mMcConf.updateParamDouble("l_max_erpm", screen2Item._savedSlaveErpm)
                        mMcConf.updateParamDouble("l_min_erpm", -screen2Item._savedSlaveErpm)
                        mMcConf.updateParamDouble("l_watt_max", screen2Item._savedSlaveWatt)
                        mMcConf.updateParamDouble("l_current_max_scale", screen2Item._savedSlaveCurr)
                    }
                    mCommands.setMcconf(false)
                    legalTimer.start()
                }
            }
        }

        Timer {
            id: legalTimer; interval: 700; repeat: false
            onTriggered: {
                if (screen2Item._legalStep === 1 && screen2Item._legalSlaveId >= 0) {
                    screen2Item._legalStep = 2
                    screen2Item._pendingToken = screen2Item._legalToken
                    VescIf.canTmpOverride(true, screen2Item._legalSlaveId)
                    mCommands.getMcconf()
                } else {
                    VescIf.canTmpOverrideEnd()
                    screen2Item._legalStep = 0
                    screen2Item.legalModeActive = screen2Item._legalEnable
                    var isDual = (screen2Item._legalSlaveId >= 0)
                    var msg = screen2Item._legalEnable
                        ? ("Legal ON: 20km/h / " + (isDual ? "300W/20%" : "600W/30%") + (isDual ? " (dual)" : ""))
                        : "Legal OFF: restored"
                    VescIf.emitStatusMessage(msg, true)
                }
            }
        }

        Rectangle {
            anchors.fill: parent
            color: Utility.getAppHexColor("darkBackground")
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            Item {
                Layout.fillWidth: true
                height: 48
                Text {
                    anchors.centerIn: parent
                    text: "Made by Custom.VESC"
                    font.pixelSize: 19
                    font.bold: true
                    font.letterSpacing: 1.2
                    font.family: "Roboto"
                    color: "#ff9500"
                    horizontalAlignment: Text.AlignHCenter
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Utility.getAppHexColor("lightestBackground")
                opacity: 0.35
            }

            // --- Statystyki sesji ---
            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: 8
                rowSpacing: 6

                // helper: etykieta lewa
                function styleLabel(txt) { return txt }

                // Wiersz: SOC przy starcie
                Label {
                    text: "SOC przy starcie:"
                    font.pixelSize: 14
                    color: Utility.getAppHexColor("disabledText")
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                }
                RowLayout {
                    spacing: 6
                    Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                    Label {
                        text: screen2Item.startupSoc < 0
                              ? "—"
                              : parseFloat(screen2Item.startupSoc).toFixed(1) + " %"
                        font.pixelSize: 14
                        font.bold: true
                        color: Utility.getAppHexColor("lightText")
                    }
                    Label {
                        visible: screen2Item.startupSoc >= 0 && screen2Item.tripDistKm >= 0
                        text: "(" + parseFloat(screen2Item.tripDistKm).toFixed(2) + " km)"
                        font.pixelSize: 13
                        color: Utility.getAppHexColor("disabledText")
                    }
                }

                Label {
                    text: "SOC aktualny:"
                    font.pixelSize: 14
                    color: Utility.getAppHexColor("disabledText")
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                }
                Label {
                    text: parseFloat(screen2Item.currentSoc).toFixed(1) + " %"
                    font.pixelSize: 14
                    font.bold: true
                    color: {
                        var s = screen2Item.currentSoc
                        if (s > 30) return "#00e676"
                        if (s > 15) return Utility.getAppHexColor("orange")
                        return "#ff5252"
                    }
                    Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                }

                // Wiersz: SOC zuzyte od startu
                Label {
                    text: "SOC zużyte:"
                    font.pixelSize: 14
                    color: Utility.getAppHexColor("disabledText")
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                }
                Label {
                    text: screen2Item.startupSoc < 0
                          ? "\u2014"
                          : parseFloat(screen2Item.socUsedPercent).toFixed(1) + " %"
                    font.pixelSize: 14
                    font.bold: true
                    color: {
                        var u = screen2Item.socUsedPercent
                        if (u < 20) return Utility.getAppHexColor("lightText")
                        if (u < 50) return Utility.getAppHexColor("orange")
                        return "#ff5252"
                    }
                    Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                }

                Rectangle {
                    Layout.columnSpan: 2; Layout.fillWidth: true
                    height: 1
                    color: Utility.getAppHexColor("lightestBackground")
                    opacity: 0.35
                }
                // Wiersz: Wh/km z SOC
                Label {
                    text: "Wh/km (z SOC):"
                    font.pixelSize: 14
                    color: Utility.getAppHexColor("disabledText")
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                }
                RowLayout {
                    spacing: 4
                    Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                    Label {
                        text: (screen2Item.startupSoc < 0 || screen2Item.tripDistKm < 0.01)
                              ? "\u2014"
                              : parseFloat(screen2Item.whPerKmSoc).toFixed(1) + " Wh/km"
                        font.pixelSize: 14
                        font.bold: true
                        color: "#00e676"
                    }
                    Label {
                        visible: screen2Item.batteryAh > 0
                        text: screen2Item.batteryAh > 0
                              ? (batterySeriesCells + "S \u00b7 " + parseFloat(screen2Item.batteryAh).toFixed(1) + " Ah")
                              : ""
                        font.pixelSize: 11
                        color: Utility.getAppHexColor("disabledText")
                    }
                }

                // Wiersz: Wh/km z VESC (ostatnie 2 km)
                Label {
                    text: "Wh/km (VESC 2km):"
                    font.pixelSize: 14
                    color: Utility.getAppHexColor("disabledText")
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                }
                Label {
                    text: screen2Item.whkmVesc2km < 0
                          ? "— (zbyt krótki dystans)"
                          : parseFloat(screen2Item.whkmVesc2km).toFixed(1) + " Wh/km"
                    font.pixelSize: screen2Item.whkmVesc2km < 0 ? 11 : 14
                    font.bold: true
                    color: screen2Item.whkmVesc2km < 0 ? Utility.getAppHexColor("disabledText") : "#ffcc02"
                    Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                }

                Label {
                    text: "Zasięg pozostały:"
                    font.pixelSize: 14
                    color: Utility.getAppHexColor("disabledText")
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                }
                Label {
                    text: screen2Item.rangeRemainKm < 0
                          ? "— (zbyt krótki dystans)"
                          : parseFloat(screen2Item.rangeRemainKm).toFixed(1) + " km"
                    font.pixelSize: 14
                    font.bold: true
                    color: {
                        var r = screen2Item.rangeRemainKm
                        if (r < 0)   return Utility.getAppHexColor("lightText")
                        if (r < 5)   return "#ff5252"
                        if (r < 15)  return Utility.getAppHexColor("orange")
                        return "#00e676"
                    }
                    Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                }

                Label {
                    text: "Zasięg 100→0%:"
                    font.pixelSize: 14
                    color: Utility.getAppHexColor("disabledText")
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                }
                Label {
                    text: screen2Item.rangeFull100Km < 0
                          ? "— (zbyt krótki dystans)"
                          : parseFloat(screen2Item.rangeFull100Km).toFixed(1) + " km"
                    font.pixelSize: 14
                    font.bold: true
                    color: Utility.getAppHexColor("lightText")
                    Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                }

                Label {
                    text: "Zasięg 100→0% (VESC):"
                    font.pixelSize: 14
                    color: Utility.getAppHexColor("disabledText")
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                }
                Label {
                    text: screen2Item.rangeFull100KmVesc < 0
                          ? "— (zbyt krótki dystans)"
                          : parseFloat(screen2Item.rangeFull100KmVesc).toFixed(1) + " km"
                    font.pixelSize: screen2Item.rangeFull100KmVesc < 0 ? 11 : 14
                    font.bold: true
                    color: screen2Item.rangeFull100KmVesc < 0
                           ? Utility.getAppHexColor("disabledText")
                           : "#ffcc02"
                    Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                }

                // Separator
                Rectangle {
                    Layout.columnSpan: 2
                    Layout.fillWidth: true
                    height: 1
                    color: Utility.getAppHexColor("lightestBackground")
                    opacity: 0.2
                }

                Label {
                    text: "Max prąd bat.:"
                    font.pixelSize: 14
                    color: Utility.getAppHexColor("disabledText")
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                }
                Label {
                    text: parseFloat(screen2Item.maxCurrentVesc1).toFixed(1) + " A"
                    font.pixelSize: 14
                    font.bold: true
                    color: Utility.getAppHexColor("lightText")
                    Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                }

                Label {
                    text: "Max prąd fazowy:"
                    font.pixelSize: 14
                    color: Utility.getAppHexColor("disabledText")
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                }
                Label {
                    text: parseFloat(screen2Item.maxMotorCurrent).toFixed(1) + " A"
                    font.pixelSize: 14
                    font.bold: true
                    color: Utility.getAppHexColor("lightText")
                    Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                }

                // Separator
                Rectangle {
                    Layout.columnSpan: 2
                    Layout.fillWidth: true
                    height: 1
                    color: Utility.getAppHexColor("lightestBackground")
                    opacity: 0.2
                }

                // Wiersz: max moc
                Label {
                    text: "Max moc:"
                    font.pixelSize: 14
                    color: Utility.getAppHexColor("disabledText")
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                }
                RowLayout {
                    spacing: 4
                    Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                    Label {
                        text: parseFloat(screen2Item.maxPower).toFixed(0) + " W"
                        font.pixelSize: 14
                        font.bold: true
                        color: Utility.getAppHexColor("lightText")
                    }
                    Label {
                        text: screen2Item.maxPowerVoltage > 0
                              ? ("@ " + parseFloat(screen2Item.maxPowerVoltage).toFixed(1) + " V")
                              : ""
                        font.pixelSize: 12
                        color: Utility.getAppHexColor("disabledText")
                    }
                }

                Label {
                    text: "Max regen:"
                    font.pixelSize: 14
                    color: Utility.getAppHexColor("disabledText")
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                }
                Label {
                    text: "-" + parseFloat(screen2Item.maxRegen).toFixed(0) + " W"
                    font.pixelSize: 14
                    font.bold: true
                    color: "#4fc3f7"
                    Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                }

                Label {
                    text: "Max napięcie bat.:"
                    font.pixelSize: 14
                    color: Utility.getAppHexColor("disabledText")
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                }
                Label {
                    text: screen2Item.maxVoltage > 0
                          ? parseFloat(screen2Item.maxVoltage).toFixed(2) + " V"
                          : "\u2014"
                    font.pixelSize: 14
                    font.bold: true
                    color: "#00e676"
                    Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                }

                Label {
                    text: "Min napięcie bat.:"
                    font.pixelSize: 14
                    color: Utility.getAppHexColor("disabledText")
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                }
                Label {
                    text: screen2Item.minVoltage < 9999
                          ? parseFloat(screen2Item.minVoltage).toFixed(2) + " V"
                          : "\u2014"
                    font.pixelSize: 14
                    font.bold: true
                    color: {
                        if (screen2Item.minVoltage >= screen2Item.maxVoltage * 0.9) return Utility.getAppHexColor("lightText")
                        if (screen2Item.minVoltage >= screen2Item.maxVoltage * 0.8) return Utility.getAppHexColor("orange")
                        return "#ff5252"
                    }
                    Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Utility.getAppHexColor("lightestBackground")
                opacity: 0.35
            }

            Item { Layout.fillHeight: true }

            // Kalibracja napięcia — tylko odczyt
            RowLayout {
                Layout.fillWidth: true
                Layout.bottomMargin: 4
                spacing: 6
                Label {
                    text: "Kalibracja napięcia:"
                    font.pixelSize: 12
                    color: Utility.getAppHexColor("disabledText")
                }
                Label {
                    text: parseFloat(voltageCalibMultiplier).toFixed(4)
                    font.pixelSize: 12
                    font.bold: true
                    color: Utility.getAppHexColor("lightText")
                }
                Item { Layout.fillWidth: true }
                Label {
                    text: "(" + parseFloat((voltageCalibMultiplier - 1.0) * 100).toFixed(2) + "%)"
                    font.pixelSize: 11
                    color: Utility.getAppHexColor("disabledText")
                }
            }

            // --- Przycisk Hulajnoga Legal ---
            Rectangle {
                id: legalRect
                Layout.fillWidth: true
                Layout.preferredHeight: 120
                Layout.bottomMargin: 4
                radius: 18

                color: legalPressArea.containsPress
                       ? (screen2Item.legalModeActive ? "#0d2d0d" : "#0d0d2d")
                       : (screen2Item.legalModeActive ? "#1a4020" : "#181828")

                border.width: 2.5
                border.color: screen2Item.legalModeActive ? "#00e676" : "#546e9a"

                // Zielony blask gdy aktywny
                layer.enabled: screen2Item.legalModeActive
                layer.effect: Glow {
                    radius: 12
                    samples: 17
                    color: "#40e676"
                    spread: 0.1
                }

                Column {
                    anchors.centerIn: parent
                    spacing: 5

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "LEGAL  MODE"
                        font.pixelSize: 18
                        font.bold: true
                        font.letterSpacing: 1.5
                        color: screen2Item.legalModeActive ? "#00e676" : "#aabbdd"
                        font.family: "Roboto"
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: {
                            var dual = screen2Item.slaveCanId >= 0
                            var watt = dual ? "300 W" : "600 W"
                            var curr = dual ? "20%" : "30%"
                            if (screen2Item.legalModeActive)
                                return "✔  ACTIVE  •  20 km/h  •  " + watt + "  •  " + curr + " current"
                            else
                                return "20 km/h  •  " + watt + "  •  " + curr + " current"
                        }
                        font.pixelSize: 12
                        color: screen2Item.legalModeActive ? "#80e676" : "#667799"
                        font.family: "Roboto"
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: screen2Item.slaveCanId >= 0 ? "DUAL MOTOR" : "SINGLE MOTOR"
                        font.pixelSize: 10
                        font.letterSpacing: 1
                        color: screen2Item.slaveCanId >= 0 ? "#39d353" : "#546e9a"
                        font.family: "Roboto"
                    }
                }

                MouseArea {
                    id: legalPressArea
                    anchors.fill: parent
                    onClicked: {
                                        screen2Item.startLegalSequence(!screen2Item.legalModeActive)
                    }
                }
            }


        }
    }
}

Column {
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    anchors.rightMargin: 6
    anchors.bottomMargin: 10
    spacing: 5
    Repeater {
        model: swipeView.count
        Rectangle {
            width: 6; height: 6; radius: 3
            color: index === swipeView.currentIndex
                   ? Utility.getAppHexColor("lightText")
                   : Utility.getAppHexColor("disabledText")
            opacity: index === swipeView.currentIndex ? 1.0 : 0.4
        }
    }
}
Timer {
    id: updateTimer; interval: 83; running: true; repeat: true
    onTriggered: { mCommands.getValuesSetup() }
}

// Refresh CAN device list every 5s (catches late-booting slaves)
Timer {
    id: canRefreshTimer; interval: 5000; running: true; repeat: true
    onTriggered: {
        if (canRetryTimer.running) return
        var devs = VescIf.getCanDevsLast()
        var newId = (devs.length > 0) ? devs[0] : -1
        if (newId !== screen2Item.slaveCanId) {
            screen2Item.slaveCanId = newId

        }
    }
}


    Connections {
        id: commandsUpdate
        target: mCommands

        property string lastFault: ""

        function onValuesSetupReceived(values, mask) {
            var currentMaxRound = Math.ceil(mMcConf.getParamDouble("l_current_max") / 5) * 5 * values.num_vescs
            var currentMinRound = Math.floor(mMcConf.getParamDouble("l_current_min") / 5) * 5 * values.num_vescs

            if (currentMaxRound > currentGauge.maximumValue || currentMaxRound < (currentGauge.maximumValue * 0.7)) {
                currentGauge.maximumValue = currentMaxRound
                currentGauge.minimumValue = currentMinRound
            }

            currentGauge.labelStep = Math.ceil((currentMaxRound - currentMinRound) / 40) * 5
            currentGauge.value = values.current_motor
            batCurrentGauge.value = values.current_in

            var batCurrentMaxConf = Math.ceil(mMcConf.getParamDouble("l_in_current_max") / 5) * 5 * values.num_vescs
            var batCurrentMinConf = Math.floor(mMcConf.getParamDouble("l_in_current_min") / 5) * 5 * values.num_vescs

            var measuredMax = Math.ceil(Math.max(values.current_in, batCurrentMaxConf) / 5) * 5
            var measuredMin = Math.floor(Math.min(values.current_in, batCurrentMinConf) / 5) * 5

            if (batCurrentMaxConf > 0) {
                var newMax = measuredMax
                var newMin = measuredMin

                if (newMax < batCurrentGauge.maximumValue * 0.7 && newMax <= batCurrentMaxConf) {
                    newMax = batCurrentMaxConf
                } else {
                    newMax = Math.max(newMax, batCurrentMaxConf)
                }
                if (newMin > batCurrentGauge.minimumValue * 0.7 && newMin >= batCurrentMinConf) {
                    newMin = batCurrentMinConf
                } else {
                    newMin = Math.min(newMin, batCurrentMinConf)
                }

                batCurrentGauge.maximumValue = newMax
                batCurrentGauge.minimumValue = newMin
                batCurrentGauge.labelStep = Math.ceil((newMax - newMin) / 40) * 5
            } else if (values.current_in > batCurrentGauge.maximumValue || values.current_in < batCurrentGauge.minimumValue) {
                batCurrentGauge.maximumValue = Math.max(batCurrentGauge.maximumValue, Math.ceil(values.current_in / 5) * 5)
                batCurrentGauge.minimumValue = Math.min(batCurrentGauge.minimumValue, Math.floor(values.current_in / 5) * 5)
                batCurrentGauge.labelStep = Math.ceil((batCurrentGauge.maximumValue - batCurrentGauge.minimumValue) / 40) * 5
            }
//            voltageGauge.value = values.v_in
            var cellsFromVesc = mMcConf.getParamInt("si_battery_cells")
            if (cellsFromVesc > 0 && cellsFromVesc !== batterySeriesCells) {
                batterySeriesCells = cellsFromVesc
                updateInterpolatedTable()
            }
            var effectiveVin = values.v_in * voltageCalibMultiplier
            calibratedVoltage = effectiveVin
            var customSoc = getCustomSoc(effectiveVin)
            batteryGauge.value = customSoc

            screen2Item.numVescs = values.num_vescs

            // SOC and range: update every 50 calls (~1s at 20ms interval)
            socUpdateTick++
            var doSocUpdate = (socUpdateTick >= 50)
            if (doSocUpdate) socUpdateTick = 0

            // Wait 7s before storing startup SOC (voltage stabilisation)
            if (screen2Item.startupSoc < 0 && effectiveVin > 10.0) {
                if (screen2Item.startupSocTicksLeft > 0) {
                    screen2Item.startupSocTicksLeft--
                } else {
                    screen2Item.startupSoc = customSoc
                    // Record odometer at script start — tripKm will be relative to this
                    screen2Item.startupDistKm = values.tachometer_abs / 1000.0
                }
            }

            if (doSocUpdate) screen2Item.currentSoc = customSoc

            if (values.current_motor > screen2Item.maxMotorCurrent)
                screen2Item.maxMotorCurrent = values.current_motor

            if (effectiveVin > 10.0) {
                if (effectiveVin > screen2Item.maxVoltage)
                    screen2Item.maxVoltage = effectiveVin
                if (effectiveVin < screen2Item.minVoltage)
                    screen2Item.minVoltage = effectiveVin
            }

            // Max battery current (total, firmware sums all VESCs)
            if (values.current_in > screen2Item.maxCurrentVesc1)
                screen2Item.maxCurrentVesc1 = values.current_in
            // Max power = peak battery current × calibrated voltage
            var powerNow = values.current_in * effectiveVin
            if (powerNow > screen2Item.maxPower) {
                screen2Item.maxPower = powerNow
                screen2Item.maxPowerVoltage = effectiveVin
            }
            if (values.current_in < 0) {
                var regenNow = Math.abs(values.current_in * effectiveVin)
                if (regenNow > screen2Item.maxRegen)
                    screen2Item.maxRegen = regenNow
            }

            screen2Item.totalWhConsumed = values.watt_hours
            screen2Item.totalWhCharged  = values.watt_hours_charged

            if (doSocUpdate) {
            // Rolling 2km Wh/km window (sampled every 10m while moving)
            if (Math.abs(values.speed) > 0.5) {
                var kmNow = values.tachometer_abs / 1000.0
                var whNow = values.watt_hours - values.watt_hours_charged
                var win   = screen2Item.whkmWindow
                if (win.length === 0 || (kmNow - win[win.length - 1].km) >= 0.01) {
                    win.push({ wh: whNow, km: kmNow })
                    while (win.length > 1 && (kmNow - win[0].km) > 2.0) win.shift()
                    screen2Item.whkmWindow = win
                    var span = kmNow - win[0].km
                    if (span >= 0.5) screen2Item.whkmVesc2km = (whNow - win[0].wh) / span
                }
            }

            } // end doSocUpdate (Wh/km window)

            var ahFromConf = mMcConf.getParamDouble("si_battery_ah")
            if (ahFromConf > 0) screen2Item.batteryAh = ahFromConf

            var absKm = values.tachometer_abs / 1000.0
            var tripKm = screen2Item.startupDistKm >= 0
                ? Math.max(0, absKm - screen2Item.startupDistKm)
                : absKm
            screen2Item.tripDistKm = tripKm

            var socUsed = 0
            if (screen2Item.startupSoc >= 0) {
                socUsed = Math.max(0, screen2Item.startupSoc - customSoc)
                screen2Item.socUsedPercent = socUsed
            }

            if (screen2Item.batteryAh > 0 && tripKm > 0.01 && screen2Item.startupSoc >= 0) {
                var totalWhFromSoc = batterySeriesCells * 3.6 * screen2Item.batteryAh * (socUsed / 100.0)
                screen2Item.whPerKmSoc = totalWhFromSoc / tripKm
                var remainingWh = batterySeriesCells * 3.6 * screen2Item.batteryAh * (customSoc / 100.0)
                screen2Item.rangeRemainKm = (screen2Item.whPerKmSoc > 0.1) ? (remainingWh / screen2Item.whPerKmSoc) : -1
                var fullWh = batterySeriesCells * 3.6 * screen2Item.batteryAh
                screen2Item.rangeFull100Km = (screen2Item.whPerKmSoc > 0.1) ? (fullWh / screen2Item.whPerKmSoc) : -1
            }

            // Zasięg 100→0% (VESC): pojemność z si_battery_ah × 3.6V × S / Wh/km sesji
            // Pojemność ta sama co wyświetlana obok Wh/km (z SOC) na ekranie 2
            if (screen2Item.whKmSession > 0.1 && screen2Item.batteryAh > 0) {
                var fullWhV = batterySeriesCells * 3.6 * screen2Item.batteryAh
                screen2Item.rangeFull100KmVesc = fullWhV / screen2Item.whKmSession
            } else {
                screen2Item.rangeFull100KmVesc = -1
            }

            var useImperial = VescIf.useImperialUnits()
            var useNegativeSpeedValues = VescIf.speedGaugeUseNegativeValues()

            var fl = mMcConf.getParamDouble("foc_motor_flux_linkage")
            var rpmMax = (values.v_in * 60.0) / (Math.sqrt(3.0) * 2.0 * Math.PI * fl)
            var speedFact = ((mMcConf.getParamInt("si_motor_poles") / 2.0) * 60.0 *
                             mMcConf.getParamDouble("si_gear_ratio")) /
                    (mMcConf.getParamDouble("si_wheel_diameter") * Math.PI)

            if (speedFact < 1e-3) {
                speedFact = 1e-3
            }

            var speedMax = 3.6 * rpmMax / speedFact
            var impFact = useImperial ? 0.621371192 : 1.0
            var speedMaxRound = Math.ceil((speedMax * impFact) / 10.0) * 10.0

            var dist = values.tachometer_abs / 1000.0
            var wh_consume = values.watt_hours - values.watt_hours_charged
            var wh_km_total = wh_consume / Math.max(dist , 1e-10)
            if (dist > 0.1) screen2Item.whKmSession = wh_km_total

            if (speedMaxRound > speedGauge.maximumValue || speedMaxRound < (speedGauge.maximumValue * 0.6) ||
                    useNegativeSpeedValues !== speedGauge.minimumValue < 0) {
                var labelStep = Math.ceil(speedMaxRound / 100) * 10

                if ((speedMaxRound / labelStep) > 30) {
                    labelStep = speedMaxRound / 30
                }

                speedGauge.labelStep = labelStep
                speedGauge.maximumValue = speedMaxRound
                speedGauge.minimumValue = useNegativeSpeedValues ? -speedMaxRound : 0
            }

            var speedNow = values.speed * 3.6 * impFact
            speedGauge.value = useNegativeSpeedValues ? speedNow : Math.abs(speedNow)

            speedGauge.unitText = useImperial ? "mph" : "km/h"

            var powerMax = Math.min(values.v_in * Math.min(mMcConf.getParamDouble("l_in_current_max"),
                                                           mMcConf.getParamDouble("l_current_max")),
                                    mMcConf.getParamDouble("l_watt_max")) * values.num_vescs
            var powerMin = Math.max(values.v_in * Math.max(mMcConf.getParamDouble("l_in_current_min"),
                                                           mMcConf.getParamDouble("l_current_min")),
                                    mMcConf.getParamDouble("l_watt_min")) * values.num_vescs
            var powerMaxRound = (Math.ceil(powerMax / 1000.0) * 1000.0)
            var powerMinRound = (Math.floor(powerMin / 1000.0) * 1000.0)

            if (powerMaxRound > powerGauge.maximumValue || powerMaxRound < (powerGauge.maximumValue * 0.6)) {
                powerGauge.maximumValue = powerMaxRound
                powerGauge.minimumValue = powerMinRound
            }

            powerGauge.value = (values.current_in * values.v_in)
            powerGauge.labelStep = Math.ceil((powerMaxRound - powerMinRound)/5000.0) * 1000.0
            var alpha = 0.05
            var efficiencyNow = Math.max( Math.min(values.current_in * values.v_in/Math.max(Math.abs(values.speed * 3.6 * impFact), 1e-6) , 60) , -60)
            efficiency_lpf = (1.0 - alpha) * efficiency_lpf + alpha *  efficiencyNow
            efficiencyGauge.value = efficiency_lpf
            efficiencyGauge.unitText = useImperial ? "WH/MI" : "WH/KM"
            if( (wh_km_total / impFact) < 999.0) {
                consumValLabel.text = parseFloat(wh_km_total / impFact).toFixed(1)
            } else {
                consumValLabel.text = "∞"
            }

            odometerValue = values.odometer
            batteryGauge.unitText = parseFloat(wh_km_total / impFact).toFixed(1) + "%"
            rangeLabel.text = useImperial ? "MI\nRANGE" : "KM\nRANGE"

            var firmwareLevel = values.battery_level
            var totalWh = (firmwareLevel > 0.001) ? (values.battery_wh / firmwareLevel) : 5000.0
            var customRemainingWh = totalWh * (customSoc / 100.0)

            if (customRemainingWh / (wh_km_total / impFact) < 999.0) {
                rangeValLabel.text = parseFloat(customRemainingWh / (wh_km_total / impFact)).toFixed(1)
            } else {
                rangeValLabel.text = "∞"
            }
            rideTime.text = new Date(values.uptime_ms).toISOString().substr(11, 8)
            odometer.text = parseFloat((values.odometer * impFact) / 1000.0).toFixed(1)
            trip.text = parseFloat((values.tachometer_abs * impFact) / 1000.0).toFixed(1)

            escTempGauge.value = values.temp_mos
            escTempGauge.maximumValue = Math.ceil(mMcConf.getParamDouble("l_temp_fet_end") / 5) * 5
            escTempGauge.throttleStartValue = Math.ceil(mMcConf.getParamDouble("l_temp_fet_start") / 5) * 5
            escTempGauge.labelStep = Math.ceil(escTempGauge.maximumValue/ 50) * 5
            motTempGauge.value = values.temp_motor
            motTempGauge.labelStep = Math.ceil(motTempGauge.maximumValue/ 50) * 5
            motTempGauge.maximumValue = Math.ceil(mMcConf.getParamDouble("l_temp_motor_end") / 5) * 5
            motTempGauge.throttleStartValue = Math.ceil(mMcConf.getParamDouble("l_temp_motor_start") / 5) * 5

            if (lastFault !== values.fault_str && values.fault_str !== "FAULT_CODE_NONE") {
                VescIf.emitStatusMessage(values.fault_str, false)
            }

            lastFault = values.fault_str
        }
    }
}