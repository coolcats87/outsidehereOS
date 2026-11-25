import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Shapes

/**
 * Fake screen corner with Apple's continuous ("squircle") curve instead of a circular arc:
 * the curve eases into the straight edges, like the corners of a Mac or iPhone display.
 * Same API as RoundCorner (corner = RoundCorner.CornerEnum.*), drop-in for ScreenCorners.
 */
Item {
    id: root
    property var corner: RoundCorner.CornerEnum.TopLeft
    property int implicitSize: 26
    property color color: "#000000"
    property real exponent: 4.2 // superellipse power: 2 = circle; higher = flatter, more "continuous"
    property real leftVisualMargin: 0
    property real topVisualMargin: 0
    property real rightVisualMargin: 0
    property real bottomVisualMargin: 0

    readonly property bool isTopLeft: corner === RoundCorner.CornerEnum.TopLeft
    readonly property bool isBottomLeft: corner === RoundCorner.CornerEnum.BottomLeft
    readonly property bool isTopRight: corner === RoundCorner.CornerEnum.TopRight
    readonly property bool isBottomRight: corner === RoundCorner.CornerEnum.BottomRight
    readonly property bool isTop: isTopLeft || isTopRight
    readonly property bool isBottom: isBottomLeft || isBottomRight
    readonly property bool isLeft: isTopLeft || isBottomLeft
    readonly property bool isRight: isTopRight || isBottomRight

    implicitWidth: implicitSize
    implicitHeight: implicitSize

    // The black wedge for a top-left corner in an s×s box: from the corner along the top edge,
    // back along the superellipse, down the left edge. Mirrored for the others.
    readonly property var points: {
        const s = root.implicitSize, n = root.exponent, steps = 40;
        const pts = [Qt.point(0, 0)];
        for (let i = 0; i <= steps; i++) {
            const t = (i / steps) * Math.PI / 2;
            const x = s - s * Math.pow(Math.cos(t), 2 / n);
            const y = s - s * Math.pow(Math.sin(t), 2 / n);
            pts.push(Qt.point(x, y));
        }
        pts.push(Qt.point(0, 0));
        return pts.map(p => Qt.point(root.isRight ? s - p.x : p.x, root.isBottom ? s - p.y : p.y));
    }

    Shape {
        anchors {
            top: root.isTop ? parent.top : undefined
            bottom: root.isBottom ? parent.bottom : undefined
            left: root.isLeft ? parent.left : undefined
            right: root.isRight ? parent.right : undefined
            leftMargin: root.leftVisualMargin
            topMargin: root.topVisualMargin
            rightMargin: root.rightVisualMargin
            bottomMargin: root.bottomVisualMargin
        }
        width: root.implicitSize
        height: root.implicitSize
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeWidth: 0
            strokeColor: "transparent"
            fillColor: root.color
            PathPolyline { path: root.points }
        }
    }
}
