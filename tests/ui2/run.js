// Runs the tests of the ui2 JavaScript (tests/ui2/*.test.js) in Node: each .pragma library file is
// loaded as QML loads it (its .import lines become the modules they name), with qsTr and
// String.arg as Qt gives them. No QML engine is needed.
//   node tests/ui2/run.js
"use strict"
const fs = require("fs")
const path = require("path")
const assert = require("assert")

const ui2 = path.join(__dirname, "..", "..", "src", "ui2")
const cache = {}

// %1, %2 ... replaced in order, the lowest first, as QString::arg does
String.prototype.arg = function (value) {
    const s = this.toString()
    let lowest = null
    for (let i = 1; i <= 99; i++) {
        if (s.indexOf("%" + i) >= 0) {
            lowest = i
            break
        }
    }
    return lowest === null ? s : s.split("%" + lowest).join(String(value))
}
global.qsTr = function (s) { return s }

function load(file) {
    const full = path.resolve(file)
    if (cache[full])
        return cache[full]
    const lines = fs.readFileSync(full, "utf8").split("\n")
    const imports = {}
    const body = []
    for (const line of lines) {
        const t = line.trim()
        if (t.startsWith(".pragma"))
            continue
        if (t.startsWith(".import")) {
            // .import "../Format.js" as Format
            const first = t.indexOf("\"")
            const second = t.indexOf("\"", first + 1)
            const name = t.substring(t.lastIndexOf(" as ") + 4).trim()
            imports[name] = load(path.join(path.dirname(full), t.substring(first + 1, second)))
            body.push("")
            continue
        }
        body.push(line)
    }
    // what a module gives: its top level functions and vars
    const names = []
    for (const line of body) {
        let name = null
        if (line.startsWith("function "))
            name = line.substring(9, line.indexOf("("))
        else if (line.startsWith("var ")) {
            // the name runs up to the first space, = or ;
            name = ""
            for (const c of line.substring(4)) {
                if (c === " " || c === "=" || c === ";")
                    break
                name += c
            }
        }
        if (name && names.indexOf(name.trim()) < 0)
            names.push(name.trim())
    }
    const factory = new Function(...Object.keys(imports), body.join("\n") + "\nreturn {" + names.join(",") + "}")
    const out = factory(...Object.values(imports))
    cache[full] = out
    return out
}

global.ui2 = function (rel) { return load(path.join(ui2, rel)) }

let passed = 0
let failed = 0
global.test = function (name, fn) {
    try {
        fn()
        passed++
    } catch (e) {
        failed++
        console.log("FAIL " + name + "\n  " + (e && e.message ? e.message : e))
    }
}
global.assert = assert

for (const f of fs.readdirSync(__dirname).filter(n => n.endsWith(".test.js")).sort()) {
    require(path.join(__dirname, f))
}
console.log(passed + " passed, " + failed + " failed")
process.exit(failed > 0 ? 1 : 0)
