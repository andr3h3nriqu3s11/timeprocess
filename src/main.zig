const std = @import("std");
const mem = std.mem;
const expect = std.testing.expect;

const stderr = std.io.getStdErr().writer();

const dateFromStrErr = error{ WrongFormat, InvalidDate } || std.fmt.ParseIntError;
const timeFromStrErr = error{ WrongFormat, InvalidTime } || std.fmt.ParseIntError;

const DateTime = struct {
    date: Date,
    time: Time,

    //TODO: deal with time zone
    fn fromTimeStamp(time: u64) DateTime {
        var minute = time / 1000 / 60;
        var hour = @floatToInt(u64, std.math.floor(@intToFloat(f128, minute) / 60.0));
        minute = minute - hour * 60;
        var days = @floatToInt(u32, std.math.floor(@intToFloat(f128, hour) / 24.0));
        hour = hour - days * 24;

        var year: u32 = 1970;
        var month: u32 = 1;

        while (days > Date.getYearSize(year)) {
            days = days - Date.getYearSize(year);
            year += 1;
        }

        while (days > 1 and days - 1 > (Date.getMaxDays(month, year) catch unreachable)) {
            days = days - (Date.getMaxDays(month, year) catch unreachable);
            month += 1;
        }

        days += 1;

        return DateTime{ .time = Time{ .hour = @intCast(u32, hour), .minute = @intCast(u32, minute) }, .date = Date{ .day = days, .month = month, .year = year } };
    }
};

test "DateTime test" {
    var dateTime = DateTime.fromTimeStamp(0);

    try expect(dateTime.time.minute == 0 and dateTime.time.hour == 0 and dateTime.date.year == 1970 and dateTime.date.month == 1 and dateTime.date.day == 1);

    //For the 17-09-2021 10:55 - 1631876119823
    dateTime = DateTime.fromTimeStamp(1631876119823);

    try expect(dateTime.time.minute == 55 and dateTime.time.hour == 10 and dateTime.date.year == 2021 and dateTime.date.month == 9 and dateTime.date.day == 17);
}

const Date = struct {
    day: u32,
    month: u32,
    year: u32,

    fn isLeap(year: u32) bool {
        return year % 400 == 0 or (year % 100 != 0 and year % 4 == 0);
    }

    fn getYearSize(year: u32) u32 {
        return if (Date.isLeap(year)) @as(u32, 366) else @as(u32, 365);
    }

    fn getMaxDays(month: u32, year: u32) error{InvalidDate}!u32 {
        if (month > 12 or month < 0) return error.InvalidDate;
        if (month == 2) return if (Date.isLeap(year)) 29 else 28;
        if (month <= 7) return if (month % 2 == 0) 30 else 31;
        return if (month % 2 == 0) 31 else 30;
    }

    fn fromStr(date: []const u8) dateFromStrErr!Date {
        var dateSplit = std.mem.split(u8, date, "-");

        var dayS = dateSplit.next();
        var monthS = dateSplit.next();
        var yearS = dateSplit.next();

        if (nullOrEmpty(dayS) or nullOrEmpty(monthS) or nullOrEmpty(yearS)) {
            return error.WrongFormat;
        }

        var day = try std.fmt.parseInt(u32, dayS.?, 10);
        var month = try std.fmt.parseInt(u32, monthS.?, 10);
        var year = try std.fmt.parseInt(u32, yearS.?, 10);

        if (month > 12 or month < 0) return error.InvalidDate;
        if (day > (try Date.getMaxDays(month, year)) or day < 0) return error.InvalidDate;

        return Date{ .day = day, .month = month, .year = year };
    }

    fn cmp(self: *Date, target: Date) i64 {
        if (self.year == target.year and self.month == target.month and self.day == target.day) return 0;

        if (self.year == target.year and self.month == target.month) {
            return @intCast(i64, target.day) - @intCast(i64, self.day);
        }

        if (self.year == target.year) {
            var dayDiff: i64 = 0;
            if (self.month > target.month) {
                dayDiff = self.day + ((Date.getMaxDays(target.month, target.year) catch unreachable) - target.day);
            } else {
                dayDiff = target.day + ((Date.getMaxDays(target.month, target.year) catch unreachable) - self.day);
                dayDiff = -dayDiff;
            }

            if (self.month > target.month) {
                var m = self.month - 1;
                while (m > 0) : (m -= 1) {
                    dayDiff += Date.getMaxDays(m, self.year) catch unreachable;
                }

                m = target.month + 1;

                while (m < 13) : (m += 1) {
                    dayDiff += Date.getMaxDays(m, target.year) catch unreachable;
                }
            } else {
                var m = target.month - 1;

                while (m > 0) : (m -= 1) {
                    dayDiff -= Date.getMaxDays(m, target.year) catch unreachable;
                }

                m = self.month + 1;

                while (m < 13) : (m += 1) {
                    dayDiff -= Date.getMaxDays(m, self.year) catch unreachable;
                }
            }

            return dayDiff;
        }

        if (self.year > target.year or (self.year == target.year and self.month > target.month) or (self.year == target.year and self.month == target.month and self.day > self.month)) {
            var dayDiff: i64 = self.day + ((Date.getMaxDays(target.month, target.year) catch unreachable) - target.day);

            var m = self.month - 1;

            while (m > 0) : (m -= 1) {
                dayDiff += Date.getMaxDays(m, self.year) catch unreachable;
            }

            m = target.month + 1;

            while (m < 13) : (m += 1) {
                dayDiff += Date.getMaxDays(m, target.year) catch unreachable;
            }

            var y = self.year - 1;

            while (y > target.year) : (y -= 1) {
                dayDiff += if (!Date.isLeap(y)) @as(u32, 365) else @as(u32, 366);
            }

            return dayDiff;
        }

        var dayDiff: i64 = target.day + ((Date.getMaxDays(self.month, self.year) catch unreachable) - self.day);

        var m = target.month - 1;

        while (m > 0) : (m -= 1) {
            dayDiff += Date.getMaxDays(m, target.year) catch unreachable;
        }

        m = self.month + 1;

        while (m < 13) : (m += 1) {
            dayDiff += Date.getMaxDays(m, self.year) catch unreachable;
        }

        var y = target.year - 1;

        while (y > self.year) : (y -= 1) {
            dayDiff += if (!Date.isLeap(y)) @as(u32, 365) else @as(u32, 366);
        }

        return -dayDiff;
    }

    fn toStr(self: *Date, alocator: *std.mem.Allocator) anyerror![]u8 {
        return std.fmt.allocPrint(alocator, "{}-{}-{}", .{ self.day, self.month, self.year });
    }
};

test "Date from string" {
    var d = try Date.fromStr("13-09-2021");

    try expect(d.day == 13);
    try expect(d.month == 9);
    try expect(d.year == 2021);

    try expect((try Date.getMaxDays(12, 2020)) == 31);
    try expect((try Date.getMaxDays(1, 2020)) == 31);
    try expect((try Date.getMaxDays(2, 2020)) == 29);
    try expect((try Date.getMaxDays(2, 2019)) == 28);

    _ = Date.getMaxDays(13, 2019) catch |e| {
        try expect(e == error.InvalidDate);
    };

    _ = Date.fromStr("40-09-2021") catch |e| {
        try expect(e == error.InvalidDate);
    };
}

test "Date Compare" {
    var d1 = try Date.fromStr("13-09-2021");
    var d2 = try Date.fromStr("12-09-2021");

    try expect(d2.cmp(d1) == 1);

    d1 = try Date.fromStr("1-01-2020");
    d2 = try Date.fromStr("31-12-2019");

    try expect(d1.cmp(d2) == 1);

    d1 = try Date.fromStr("1-01-2020");
    d2 = try Date.fromStr("11-12-2019");

    try expect(d1.cmp(d2) == 21);

    d1 = try Date.fromStr("1-01-2020");
    d2 = try Date.fromStr("11-11-2019");

    try expect(d1.cmp(d2) == 51);

    d2 = try Date.fromStr("11-11-2018");

    try expect(d1.cmp(d2) == (365 + 51));

    d1 = try Date.fromStr("11-11-2018");
    d2 = try Date.fromStr("11-11-2018");

    try expect(d1.cmp(d2) == 0);
}

const Time = struct {
    hour: u32,
    minute: u32,

    fn fromStr(time: []const u8) timeFromStrErr!Time {
        var timeSplit = std.mem.split(u8, time, ":");

        var hourS = timeSplit.next();
        var minuteS = timeSplit.next();

        if (nullOrEmpty(hourS) or nullOrEmpty(minuteS)) return error.WrongFormat;

        var hour = try std.fmt.parseInt(u32, hourS.?, 10);
        var minute = try std.fmt.parseInt(u32, minuteS.?, 10);

        if (minute > 60 or minute < 0) return error.InvalidTime;

        if (minute == 60) {
            minute = 0;
            hour = hour + 1;
        }

        if (hour > 60 or hour < 0) return error.InvalidTime;

        return Time{ .hour = hour, .minute = minute };
    }

    fn cmp(self: *Time, target: Time) i64 {
        var hDiff: i64 = @as(i64, target.hour) - @as(i64, self.hour);
        var minDiff: i64 = @as(i64, target.minute) - @as(i64, self.minute);

        return hDiff * 60 + minDiff;
    }

    fn cmpDay(self: *Time, target: Time) i64 {
        var t = Time{ .hour = 24, .minute = 0 };
        return -t.cmp(self.*) + target.hour * 60 + target.minute;
    }
};

test "Time from string" {
    var t = try Time.fromStr("12:12");

    try expect(t.hour == 12);
    try expect(t.minute == 12);

    _ = Time.fromStr("25:00") catch |e| {
        try expect(e == error.InvalidTime);
    };

    _ = Time.fromStr("01:61") catch |e| {
        try expect(e == error.InvalidTime);
    };

    _ = Time.fromStr("24:60") catch |e| {
        try expect(e == error.InvalidTime);
    };

    t = try Time.fromStr("23:60");

    try expect(t.hour == 24);
    try expect(t.minute == 0);
}

test "Time cmp test" {
    var t1 = try Time.fromStr("00:00");
    var t2 = try Time.fromStr("01:00");

    try expect(t1.cmp(t2) == 60);

    t2 = try Time.fromStr("01:20");

    try expect(t1.cmp(t2) == 80);

    t1 = try Time.fromStr("00:20");

    try expect(t1.cmp(t2) == 60);

    t1 = try Time.fromStr("01:00");

    try expect(t1.cmp(t2) == 20);

    t1 = try Time.fromStr("01:40");

    try expect(t1.cmp(t2) == -20);

    t1 = try Time.fromStr("23:00");
    t2 = try Time.fromStr("01:00");

    try expect(t1.cmpDay(t2) == 120);
}

const inState = enum(u8) { IN, OUT, LEDGER };
const scan = enum { FILE, NONE, OPTIONS, LEDGERFILE, CLOCK };
const Line = struct { date: Date, time: Time, state: inState, name: []const u8, dif: u64 };

pub fn main() anyerror!void {
    var stdout = std.io.getStdOut();

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    var allocator = &arena.allocator;

    var args = std.process.args();
    defer args.deinit();

    var filePath: ?[]u8 = null;
    var ledgerFilePath: ?[]u8 = null;

    var status = scan.FILE;
    var tempStatus: ?scan = null;

    var ledgerFormat = false;
    var ledgerAppend = false;

    var rewrite = false;

    var clock = false;
    var clockName: ?[]u8 = null;

    // skips the 1st argument the path
    _ = args.skip();
    while (args.next(allocator)) |arg| {
        var s = try arg;
        defer allocator.free(s);
        if (std.mem.startsWith(u8, s, "-l")) {
            ledgerFormat = true;
            tempStatus = status;
            status = scan.OPTIONS;
            var rest = std.mem.trimLeft(u8, s, &[_]u8{ '-', 'f', 0 });
            var skip = false;
            for (rest) |a| {
                if (a == 'o') {
                    status = scan.LEDGERFILE;
                    rest = std.mem.trimLeft(u8, s, &[_]u8{ 'o', 0 });
                    skip = true;
                }
                if (a == 'a') {
                    ledgerAppend = true;
                    rest = std.mem.trimLeft(u8, s, &[_]u8{ 'a', 0 });
                }
            }
            if (skip)
                continue;
        } else if (mem.startsWith(u8, s, "-r")) {
            rewrite = true;
            continue;
        } else if (mem.startsWith(u8, s, "-c")) {
            try stderr.print("Warn: this is done with utc time not the local time\n", .{});
            clock = true;
            tempStatus = status;
            status = scan.CLOCK;
            continue;
        }

        if (status == scan.NONE) {
            try stderr.print("Can not understand the arg: {s}\n", .{s});
            return;
        }

        if (status == scan.FILE) {
            if (filePath != null) allocator.free(filePath.?);
            filePath = try std.fs.path.resolve(allocator, &[_][]u8{s});
            status = scan.NONE;
        } else if (status == scan.LEDGERFILE) {
            if (ledgerFilePath != null) allocator.free(ledgerFilePath.?);
            ledgerFilePath = try std.fs.path.resolve(allocator, &[_][]u8{s});
        } else if (status == scan.CLOCK) {
            if (clockName != null) allocator.free(clockName.?);
            clockName = try allocator.alloc(u8, s.len);
            mem.copy(u8, clockName.?, s);
        }

        status = tempStatus orelse status;
        tempStatus = null;
    }

    if (filePath == null) {
        try stderr.print("No file specified\n", .{});
        return;
    }

    var file = try std.fs.openFileAbsolute(filePath.?, .{ .write = true, .read = true });

    var r = try file.reader().readAllAlloc(allocator, 1024 * @sizeOf(u8));
    defer allocator.free(r);

    var split = std.mem.split(u8, r, "\n");

    var lineC: usize = 0;

    var list = std.ArrayList(Line).init(allocator);
    defer list.deinit();

    var ledgerList = std.ArrayList(Line).init(allocator);
    defer list.deinit();

    while (split.next()) |s| {
        lineC += 1;
        //std.log.info("line: {s}", .{s});
        if (std.mem.eql(u8, s, "")) continue;
        var line = std.mem.split(u8, s, " ");

        var rState = line.next();

        var state: ?inState = null;
        var name: ?[]const u8 = null;
        var dateS: ?[]const u8 = null;
        var timeS: ?[]const u8 = null;

        if (std.mem.eql(u8, rState orelse "", "->")) {
            state = inState.IN;
        } else if (std.mem.eql(u8, rState orelse "", "<-")) {
            state = inState.OUT;
        } else if (std.mem.eql(u8, rState orelse "", "LE")) {
            state = inState.LEDGER;
        } else {
            try stderr.print("Could not parse the line {} on the state token\n", .{lineC});
            return;
        }

        name = line.next();

        if (name == null or std.mem.eql(u8, name.?, "")) {
            try stderr.print("Could not find name in line {}\n", .{lineC});
            return;
        }

        dateS = line.next();

        if (dateS == null or std.mem.eql(u8, dateS.?, "")) {
            try stderr.print("Could not find date in line {}\n", .{lineC});
            return;
        }

        //var date =
        var date = try Date.fromStr(dateS.?);

        timeS = line.next();

        if (timeS == null or std.mem.eql(u8, timeS.?, "")) {
            try stderr.print("Could not find time in line {}\n", .{lineC});
            return;
        }

        var time = try Time.fromStr(timeS.?);

        var l = Line{ .date = date, .time = time, .state = state.?, .name = name.?, .dif = 0 };

        if (state == inState.LEDGER) {
            var difS = line.next();
            if (nullOrEmpty(difS)) {
                try stderr.print("Could not find difference in line {}\n", .{lineC});
                return;
            }

            l.dif = try std.fmt.parseInt(u64, difS.?, 10);

            try ledgerList.append(l);
            continue;
        }

        var listTemp = std.ArrayList(Line).init(allocator);
        //defer listTemp.deinit();

        var found = false;

        for (list.items) |item| {
            if (std.mem.eql(u8, l.name, item.name)) {
                //var dif = (item.date.cmp(l.date) * 24 * 60) + item.time.cmp(l.time);

                var dif: i64 = @as(Date, item.date).cmp(l.date) * 24 * 60;

                if (dif == 0) {
                    dif += @as(Time, item.time).cmp(l.time);
                } else dif += @as(Time, item.time).cmpDay(l.time);

                if (dif < 0) {
                    try stderr.print("Something is wrong! Line: {} resulted in a negative time\n", .{lineC});
                    return;
                }

                var difP: u64 = @intCast(u64, dif);

                //std.log.info("Name: {s}; Time: {}", .{ item.name, difP });

                try ledgerList.append(Line{ .date = item.date, .time = item.time, .name = item.name, .dif = difP, .state = inState.LEDGER });
                found = true;
            } else try listTemp.append(item);
        }

        if (!found and l.state == inState.OUT) {
            try stderr.print("Tryed to close and opened line! At line {}\n", .{lineC});
            return;
        }

        if (!found) try listTemp.append(l);

        list.deinit();
        list = listTemp;
    }

    if (clock) {
        std.log.info("clock: {s}", .{clockName});

        var dateTime = DateTime.fromTimeStamp(@intCast(u64, std.time.milliTimestamp()));

        var l = Line{ .date = dateTime.date, .time = dateTime.time, .state = inState.IN, .name = clockName.?, .dif = 0 };

        var listTemp = std.ArrayList(Line).init(allocator);
        //defer listTemp.deinit();

        var found = false;

        for (list.items) |item| {
            if (std.mem.eql(u8, l.name, item.name)) {
                //var dif = (item.date.cmp(l.date) * 24 * 60) + item.time.cmp(l.time);

                var dif: i64 = @as(Date, item.date).cmp(l.date) * 24 * 60;

                if (dif == 0) {
                    dif += @as(Time, item.time).cmp(l.time);
                } else dif += @as(Time, item.time).cmpDay(l.time);

                if (dif < 0) {
                    try stderr.print("Something is wrong! Line: {} resulted in a negative time\n", .{lineC});
                    return;
                }

                var difP: u64 = @intCast(u64, dif);

                //std.log.info("Name: {s}; Time: {}", .{ item.name, difP });

                try stderr.print("Clocking out for {s} at {}-{}-{} {}:{}\n", .{ l.name, l.date.day, l.date.month, l.date.year, l.time.hour, l.time.minute });

                try ledgerList.append(Line{ .date = item.date, .time = item.time, .name = item.name, .dif = difP, .state = inState.LEDGER });
                found = true;
            } else try listTemp.append(item);
        }

        if (!found) {
            try listTemp.append(l);
            try stderr.print("Clocking in for {s} at {}-{}-{} {}:{}\n", .{ l.name, l.date.day, l.date.month, l.date.year, l.time.hour, l.time.minute });
        }

        list.deinit();
        list = listTemp;
    }

    if (list.items.len > 0) try stderr.print("Incomplete:\n", .{});

    for (list.items) |item| {
        var str = try @as(Date, item.date).toStr(allocator);
        defer allocator.free(str);
        try stderr.print("\tItem: {s} {s}\n", .{ item.name, str });
    }

    if (ledgerFilePath != null) {
        stdout = blk: {
            std.fs.accessAbsolute(ledgerFilePath.?, .{}) catch |e| {
                if (e == error.FileNotFound) {
                    break :blk try std.fs.createFileAbsolute(ledgerFilePath.?, .{});
                }
                return e;
            };
            break :blk try std.fs.openFileAbsolute(ledgerFilePath.?, .{ .write = true, .read = true });
        };
        if (ledgerAppend) {
            std.log.info("ap", .{});
            try stdout.seekFromEnd(0);
        }
    }

    for (ledgerList.items) |item| {
        if (!ledgerFormat) {
            try stdout.writer().print("{s} {}\n", .{ item.name, item.dif });
        } else {
            try stdout.writer().print("{}-{}-{} {s} - {}:{}\n\ttime:all\t{} min\n\ttime:{s}\n\n", .{ item.date.year, item.date.month, item.date.day, item.name, item.time.hour, item.time.minute, item.dif, item.name });
        }
    }

    if (rewrite) {
        try file.setEndPos(0);
        try file.seekTo(0);
        var writer = file.writer();
        for (ledgerList.items) |item| {
            try writer.print("LE {s} {}-{}-{} {}:{} {}\n", .{ item.name, item.date.day, item.date.month, item.date.year, item.time.hour, item.time.minute, item.dif });
        }
        for (list.items) |item| {
            if (item.state == inState.IN) {
                try writer.print("-> {s} {}-{}-{} {}:{}\n", .{ item.name, item.date.day, item.date.month, item.date.year, item.time.hour, item.time.minute });
            } else if (item.state == inState.OUT) {
                try writer.print("<- {s} {}-{}-{} {}:{}\n", .{ item.name, item.date.day, item.date.month, item.date.year, item.time.hour, item.time.minute });
            }
        }
    }
}

fn nullOrEmpty(t: ?[]const u8) bool {
    return t == null or std.mem.eql(u8, t.?, "");
}
