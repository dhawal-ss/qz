import QtQuick 2.14
import QtTest 1.14
import "../../src"

// HeroStrip: the key numbers above the tiles. The tiles are stand-ins with the DataObject properties
// it reads. Run: qmltestrunner -input tst/qml (QT_QPA_PLATFORM=offscreen, QT_QUICK_BACKEND=software)
TestCase {
    id: testCase
    name: "HeroStrip"
    width: 1300
    height: 900
    when: windowShown

    ThemeTokens { id: tokens }

    Component {
        id: tileComponent
        QtObject {
            property string name: ""
            property string value: ""
            property string secondLine: ""
            property string identificator: ""
            property string valueFontColor: "white"
        }
    }
    Component {
        id: heroComponent
        HeroStrip { theme: tokens; availableHeight: 700 }
    }

    function tile(name, value, id, second) {
        return createTemporaryObject(tileComponent, testCase,
                                     { name: name, value: value, identificator: id, secondLine: second || "" })
    }
    function fourTiles() {
        return [tile("Watt", "245", "watt", "AVG: 200 MAX: 400"), tile("Heart (bpm)", "0", "heart"),
                tile("Cadence (rpm)", "88", "cadence"), tile("Elapsed", "0:12:34", "elapsed")]
    }
    function make(width, tiles) {
        var h = createTemporaryObject(heroComponent, testCase, { width: width, tiles: tiles })
        verify(h)
        return h
    }
    function cells(h) {
        var found = []
        function walk(item) {
            if (!item || !item.children)
                return
            for (var i = 0; i < item.children.length; i++) {
                if (item.children[i].objectName === "heroCell")
                    found.push(item.children[i])
                walk(item.children[i])
            }
        }
        walk(h)
        return found
    }
    function heroValueOf(cell) {
        if (!cell || !cell.children)
            return null
        for (var i = 0; i < cell.children.length; i++)
            if (cell.children[i].objectName === "heroValue")
                return cell.children[i]
        return null
    }

    function test_no_tiles_no_height() {
        var h = make(390, [])
        compare(h.implicitHeight, 0)
    }

    function test_three_tiles_one_row() {
        var h = make(390, [tile("Watt", "245", "watt"), tile("Heart (bpm)", "120", "heart"), tile("Cadence (rpm)", "88", "cadence")])
        compare(h.columns, 3)
        compare(h.rows, 1)
    }

    function test_four_tiles_two_columns_on_a_phone_four_on_a_tablet() {
        var phone = make(390, fourTiles())
        compare(phone.columns, 2)
        compare(phone.rows, 2)
        var tablet = make(1280, fourTiles())
        compare(tablet.columns, 4)
        compare(tablet.rows, 1)
    }

    function test_no_heart_rate_is_dashes() {
        var h = make(1280, fourTiles())
        compare(h.shownValue(h.tiles[1]), "--")
    }

    function test_elapsed_under_an_hour_drops_hours() {
        var h = make(1280, fourTiles())
        compare(h.shownValue(h.tiles[3]), "12:34")
        compare(h.shownValue(tile("Elapsed", "1:02:03", "elapsed")), "1:02:03")
    }

    function test_values_fit_their_cells() {
        var h = make(390, [tile("Watt", "1888", "watt"), tile("Elapsed", "0:59:59", "elapsed"),
                           tile("Heart (bpm)", "188", "heart"), tile("Cadence (rpm)", "120", "cadence")])
        var c = cells(h)
        compare(c.length, 4)
        for (var i = 0; i < c.length; i++) {
            var v = heroValueOf(c[i])
            verify(v)
            verify(v.contentWidth <= c[i].width, "value wider than its cell: " + v.text)
        }
    }

    function test_screen_reader_reads_the_value() {
        var h = make(1280, fourTiles())
        var c = cells(h)
        verify(c[0].Accessible.name.indexOf("245") >= 0)
        verify(c[1].Accessible.name.indexOf("--") >= 0)
    }
}
