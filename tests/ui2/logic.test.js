// The logic of Bikemodo's screens, file by file. Dates are built from today so the tests do not
// age; a week starts on Monday (Format's default).
const Streak = ui2("goals/Streak.js")
const Fitness = ui2("progress/Fitness.js")
const Workout = ui2("train/Workout.js")
const Ftp = ui2("train/Ftp.js")
const Levels = ui2("train/Levels.js")
const Plans = ui2("train/Plans.js")
const Route = ui2("train/Route.js")
const Coach = ui2("today/Coach.js")
const Body = ui2("today/Body.js")
const Pro = ui2("progress/Analytics.js")
const Format = ui2("Format.js")
const Share = ui2("moments/Share.js")
const Moments = ui2("moments/Moments.js")

const dayMs = 86400000
const starts = [0.555, 0.755, 0.905, 1.055, 1.205, 1.505]
function midnight(daysAgo) {
    const d = new Date()
    d.setHours(0, 0, 0, 0)
    return d.getTime() - daysAgo * dayMs
}

// ---- Streak
test("streak: a week that meets the goal counts, a short one does not", () => {
    const monday = Format.weekStart(Date.now())
    const days = [
        { day: monday - 7 * dayMs, seconds: 3600, rides: 2 },
        { day: monday - 6 * dayMs, seconds: 3600, rides: 1 },
        { day: monday - 14 * dayMs, seconds: 600, rides: 1 }
    ]
    const weeks = Streak.perWeek(days)
    const last = weeks[Streak.weekKey(monday - 7 * dayMs)]
    assert.strictEqual(last.rides, 3)
    assert.ok(Streak.met(last, "minutes", 120))
    assert.ok(!Streak.met(weeks[Streak.weekKey(monday - 14 * dayMs)], "minutes", 120))
})

test("streak: run counts the goal weeks in a row", () => {
    const monday = Format.weekStart(Date.now())
    const days = []
    for (let w = 1; w <= 3; w++)
        days.push({ day: monday - w * 7 * dayMs + dayMs, seconds: 3 * 3600, rides: 3 })
    const r = Streak.run(Streak.perWeek(days), { kind: "minutes", goal: 120, rest: [], now: Date.now() })
    assert.ok(r.streak >= 3, "streak " + r.streak)
})

// ---- Fitness
test("fitness: a day a week of load raises CTL and the series has a day each", () => {
    const days = []
    for (let i = 60; i >= 0; i -= 2)
        days.push({ day: midnight(i), tss: 60 })
    const s = Fitness.series(days, midnight(60), Date.now())
    assert.ok(s.length >= 60)
    assert.ok(s[s.length - 1].ctl > 10)
})

// ---- Workout
test("workout: steps take the zone bands of the rider's FTP, rounded to 5 W", () => {
    const plan = Coach.threshold(1)
    const steps = Workout.steps(plan, 200, true, starts)
    const work = steps.filter(s => s.zone === 4)[0]
    assert.strictEqual(work.low % 5, 0)
    assert.ok(work.low >= 180 && work.high <= 215, work.low + "-" + work.high)
    assert.strictEqual(Workout.total(steps), plan.minutes * 60)
})

test("workout: without an FTP there are no watts, only how it should feel", () => {
    const steps = Workout.steps(Coach.threshold(1), 200, false, starts)
    assert.ok(steps.every(s => s.high === 0))
    assert.strictEqual(Workout.target(steps[0]), steps[0].words)
})

test("workout: at() finds the step and the time left in it", () => {
    const steps = Workout.steps(Coach.endurance(1, 30), 200, true, starts)
    const p = Workout.at(steps, 5 * 60 + 10)
    assert.strictEqual(p.index, 1)
    assert.ok(Workout.at(steps, Workout.total(steps) + 1).done)
})

// ---- FTP tests
test("ftp: the ramp starts low, climbs a step a minute to about twice the FTP", () => {
    const r = Ftp.rampPlan(70)
    const ramp = r.blocks.slice(r.testFrom, r.testTo + 1)
    assert.strictEqual(ramp[0][2], 50)
    assert.ok(ramp.length >= 15)
    assert.ok(ramp[ramp.length - 1][2] >= 140)
    for (let i = 1; i < ramp.length; i++)
        assert.ok(ramp[i][2] > ramp[i - 1][2])
})

test("ftp: results are 75% of the best minute and 95% of 20 minutes", () => {
    assert.strictEqual(Ftp.result("ramp", 300, 0), 225)
    assert.strictEqual(Ftp.result("twenty", 0, 200), 190)
    assert.strictEqual(Ftp.result("twenty", 0, 0), 0)
})

// ---- Levels
test("levels: three finished threshold workouts raise it, one left early lowers it", () => {
    const now = Date.now()
    let log = []
    for (let i = 0; i < 3; i++)
        log = Levels.add(log, { ms: now, id: "threshold", zone: 4, finished: true })
    assert.strictEqual(Levels.levels(log, now).threshold, 2.5)
    log = Levels.add(log, { ms: now, id: "threshold", zone: 4, finished: false })
    assert.strictEqual(Levels.levels(log, now).threshold, 2)
    assert.strictEqual(Coach.threshold(2.5).name, "Threshold 3x10")
})

test("levels: easy spins and tests do not count", () => {
    const now = Date.now()
    const log = [{ ms: now, id: "easy", zone: 2, finished: true }, { ms: now, id: "ramp", zone: 6, test: true, finished: true }]
    assert.deepStrictEqual(Levels.levels(log, now), { endurance: 1, tempo: 1, threshold: 1, vo2: 1 })
})

// ---- Plans
test("plans: every fourth week is easier, an event rests in its last week", () => {
    const p = { id: "event", startMs: Date.now(), weeks: 8 }
    assert.ok(Plans.easierWeek(p, 3))
    assert.ok(!Plans.easierWeek(p, 7))
    assert.strictEqual(Plans.week(p, 7, {})[1].name, "Openers")
})

test("plans: rides before the plan started do not count", () => {
    const p = { id: "habit", startMs: Date.now(), weeks: 8 }
    const before = [{ start: Date.now() - 3600000, duration: 1800 }]
    assert.strictEqual(Plans.now(p, before, Date.now(), {}).done, 0)
    const after = [{ start: Date.now() + 1000, duration: 1800 }]
    assert.strictEqual(Plans.now(p, after, Date.now() + 2000, {}).done, 1)
})

test("plans: first 40 km ends with the 40 km ride", () => {
    const p = { id: "first40", startMs: Date.now(), weeks: 6 }
    assert.strictEqual(Plans.week(p, 5, {})[2].name, "Your 40 km")
})

// ---- Routes
test("route: the long climb has its climb ahead, and watts rise with the gradient", () => {
    const climb = Route.library()[1]
    assert.strictEqual(Math.round(Route.total(climb)), 15)
    const next = Route.nextClimb(climb, 0)
    assert.ok(next && next.grade >= 5 && Math.abs(next.inKm - 5) < 0.2)
    assert.ok(Route.watts(6, 15, 75) > Route.watts(0, 15, 75))
    assert.ok(Route.at(climb, 99).done)
})

// ---- Readiness
test("body: a short night with low HRV says take it easy, a good one says go", () => {
    const key = (ms) => { const d = new Date(ms); return d.getFullYear() + "-" + String(d.getMonth() + 1).padStart(2, "0") + "-" + String(d.getDate()).padStart(2, "0") }
    const now = Date.now()
    const days = []
    for (let i = 30; i >= 1; i--)
        days.push({ day: key(now - i * dayMs), hrv: 50 + (i % 3), rhr: 56 + (i % 2), sleepMin: 420 })
    days.push({ day: key(now), hrv: 38, rhr: 62, sleepMin: 300 })
    assert.strictEqual(Body.today(days, now).state, "easy")
    days[days.length - 1] = { day: key(now), hrv: 58, rhr: 53, sleepMin: 480 }
    assert.strictEqual(Body.today(days, now).state, "good")
    assert.strictEqual(Body.today(days.slice(-3), now).state, "building")
    assert.strictEqual(Body.today([], now).state, "none")
})

// ---- Pro analytics
test("pro: critical power from a hard curve, none from an easy one", () => {
    const curve = [[180, 300], [240, 285], [300, 272], [420, 258], [600, 247], [900, 236], [1200, 230]]
        .map(p => ({ seconds: p[0], watts: p[1] }))
    const m = Pro.criticalPower(curve)
    assert.ok(m.cp > 200 && m.cp < 230, "cp " + m.cp)
    assert.ok(m.wprime > 10000 && m.wprime < 25000, "w' " + m.wprime)
    assert.strictEqual(Pro.criticalPower([[180, 80], [300, 79], [600, 78], [1200, 77]].map(p => ({ seconds: p[0], watts: p[1] }))), null)
})

test("pro: W′ balance falls above CP and comes back below it", () => {
    const p = []
    for (let i = 0; i < 600; i++)
        p.push(i < 130 ? 400 : 100)
    const w = Pro.wbal(p, 250, 20000)
    assert.ok(w.lowest < 2000)
    assert.ok(w.series[w.series.length - 1] > w.lowest / 1000)
})

test("pro: VO2 max only from a hard 5 minutes", () => {
    assert.strictEqual(Pro.vo2max(60, 75, true), null)
    const v = Pro.vo2max(300, 75, false)
    assert.ok(v.value > 45 && v.low < v.value && v.high > v.value)
})

test("pro: decoupling only on steady rides", () => {
    assert.ok(Pro.steady({ duration: 3600, avgPower: 200, np: 205 }))
    assert.ok(!Pro.steady({ duration: 3600, avgPower: 150, np: 220 }))
    assert.ok(!Pro.steady({ duration: 1200, avgPower: 200, np: 202 }))
})

// ---- Share card

test("share: a bar a minute, a bar per few minutes past two hours", () => {
    assert.strictEqual(Share.barCount(41 * 60), 41)
    assert.strictEqual(Share.minutesPerBar(41 * 60), 1)
    assert.strictEqual(Share.barCount(240 * 60), 120)
    assert.strictEqual(Share.minutesPerBar(240 * 60), 2)
})

test("share: before the ride is read, the 30 s zones make a bar a minute, the higher zone of each", () => {
    const bars = Share.zoneBars([1, 2, 3, 3, 5, 2], 3 * 60, true)
    assert.deepStrictEqual(bars.map(b => b.zone), [2, 3, 5])
    assert.deepStrictEqual(bars.map(b => b.watts), [2, 3, 5])
    // without an FTP the bars keep their lengths and take the tint
    assert.deepStrictEqual(Share.zoneBars([1, 2, 3, 3], 2 * 60, false).map(b => b.zone), [0, 0])
    assert.deepStrictEqual(Share.zoneBars([], 600, true), [])
})

test("share: zones only once the rider has set an FTP", () => {
    const zoneOf = (w, ftp) => (w >= ftp ? 4 : 2)
    assert.deepStrictEqual(Share.bars([100, 250], 200, true, zoneOf).map(b => b.zone), [2, 4])
    assert.deepStrictEqual(Share.bars([100, 250], 200, false, zoneOf).map(b => b.zone), [0, 0])
})

test("share: time, distance, power, calories, then load with an FTP or work without", () => {
    const ride = { elapsed: 2444, distance: 14.24, miles: false, avgPower: 58.4, calories: 311.6, tss: 29.2, kilojoules: 142, powerEstimated: true }
    const withFtp = Share.numbers(ride, true)
    assert.deepStrictEqual(withFtp.map(n => n.label), ["Time", "Distance", "Avg power", "Calories", "Load"])
    assert.deepStrictEqual(withFtp.map(n => n.value), ["40:44", "14.2", "58", "312", "29"])
    assert.strictEqual(withFtp[2].est, true)
    assert.strictEqual(Share.numbers(ride, false)[4].label, "Work")
    assert.strictEqual(Share.numbers(Object.assign({}, ride, { miles: true }), true)[1].unit, "mi")
    assert.strictEqual(Share.numbers(Object.assign({}, ride, { powerEstimated: false }), true)[2].est, false)
})

test("share: the card lights a new best and the weekly goal, two at most, nothing for a plain ride", () => {
    const records = Moments.recordMoments([1800], [{ seconds: 1800, watts: 62 }], [{ seconds: 1800, watts: 55 }])
    const goal = { kind: "streak", title: "Week closed", value: 3, unit: "weeks", tone: 5 }
    const lines = Share.achievements(records.concat([goal, { kind: "longest", title: "Your longest ride", tone: 3 }]))
    assert.deepStrictEqual(lines.map(l => l.text), ["New 30 minute best, 62 W", "Weekly goal met, 3 weeks in a row"])
    assert.deepStrictEqual(Share.achievements([{ kind: "kind", title: "Every ride adds up." }]), [])
})
