const std = @import("std");

const Config = struct {
    num_rows: usize,
    start_timestamp: i64, // Unix timestamp
    end_timestamp: i64,   // Unix timestamp
};

const first_names = [_][]const u8{
    "James",     "Mary",      "John",      "Patricia",  "Robert",
    "Jennifer",  "Michael",   "Linda",     "William",   "Barbara",
    "David",     "Elizabeth", "Richard",   "Susan",     "Joseph",
    "Jessica",   "Thomas",    "Sarah",     "Charles",   "Karen",
    "Christopher", "Nancy",   "Daniel",    "Lisa",      "Matthew",
    "Betty",     "Anthony",   "Margaret",  "Mark",      "Sandra",
    "Donald",    "Ashley",    "Steven",    "Kimberly",  "Paul",
    "Emily",     "Andrew",    "Donna",     "Joshua",    "Michelle",
    "Kenneth",   "Carol",     "Kevin",     "Amanda",    "Brian",
    "Melissa",   "George",    "Deborah",   "Edward",    "Stephanie",
};

const last_names = [_][]const u8{
    "Smith",     "Johnson",   "Williams",  "Brown",     "Jones",
    "Garcia",    "Miller",    "Davis",     "Rodriguez", "Martinez",
    "Hernandez", "Lopez",     "Gonzalez",  "Wilson",    "Anderson",
    "Thomas",    "Taylor",    "Moore",     "Jackson",   "Martin",
    "Lee",       "Perez",     "Thompson",  "White",     "Harris",
    "Sanchez",   "Clark",     "Ramirez",   "Lewis",     "Robinson",
    "Walker",    "Young",     "Allen",     "King",      "Wright",
    "Scott",     "Torres",    "Nguyen",    "Hill",      "Flores",
    "Green",     "Adams",     "Nelson",    "Baker",     "Hall",
    "Rivera",    "Campbell",  "Mitchell",  "Carter",    "Roberts",
};

fn generateRandomData(allocator: std.mem.Allocator, config: Config) !void {
    var prng = std.Random.DefaultPrng.init(blk: {
        var seed: u64 = undefined;
        try std.posix.getrandom(std.mem.asBytes(&seed));
        break :blk seed;
    });
    const rand = prng.random();

    // Print CREATE TABLE statement
    std.debug.print(
        \\CREATE TABLE IF NOT EXISTS users (
        \\  ID INT AUTO_INCREMENT NOT NULL PRIMARY KEY,
        \\  firstname VARCHAR(50) NOT NULL,
        \\  lastname VARCHAR(50) NOT NULL,
        \\  email VARCHAR(150) NOT NULL,
        \\  date_created DATETIME NOT NULL,
        \\  date_updated DATETIME NOT NULL
        \\);
        \\
        \\
    , .{});

    // Generate INSERT statements
    std.debug.print("INSERT INTO users (firstname, lastname, email, date_created, date_updated) VALUES\n", .{});

    for (0..config.num_rows) |i| {
        const first_name = first_names[rand.intRangeAtMost(usize, 0, first_names.len - 1)];
        const last_name = last_names[rand.intRangeAtMost(usize, 0, last_names.len - 1)];

        // Generate random timestamps
        const created_timestamp = rand.intRangeAtMost(i64, config.start_timestamp, config.end_timestamp);
        const updated_timestamp = rand.intRangeAtMost(i64, created_timestamp, config.end_timestamp);

        // Format email
        const email = try std.fmt.allocPrint(
            allocator,
            "{s}.{s}@example.com",
            .{ first_name, last_name },
        );
        defer allocator.free(email);

        // Convert timestamps to datetime strings
        const created_datetime = try formatDateTime(allocator, created_timestamp);
        defer allocator.free(created_datetime);

        const updated_datetime = try formatDateTime(allocator, updated_timestamp);
        defer allocator.free(updated_datetime);

        // Print the INSERT value
        if (i == config.num_rows - 1) {
            // Last row - end with semicolon
            std.debug.print("  ('{s}', '{s}', '{s}', '{s}', '{s}');\n", .{
                first_name,
                last_name,
                email,
                created_datetime,
                updated_datetime,
            });
        } else {
            // Not last row - end with comma
            std.debug.print("  ('{s}', '{s}', '{s}', '{s}', '{s}'),\n", .{
                first_name,
                last_name,
                email,
                created_datetime,
                updated_datetime,
            });
        }
    }
}

fn formatDateTime(allocator: std.mem.Allocator, timestamp: i64) ![]u8 {
    const epoch_seconds: std.time.epoch.EpochSeconds = .{ .secs = @intCast(timestamp) };
    const day_seconds = epoch_seconds.getDaySeconds();
    const year_day = epoch_seconds.getEpochDay().calculateYearDay();
    const month_day = year_day.calculateMonthDay();

    return std.fmt.allocPrint(
        allocator,
        "{d:0>4}-{d:0>2}-{d:0>2} {d:0>2}:{d:0>2}:{d:0>2}",
        .{
            year_day.year,
            month_day.month.numeric(),
            month_day.day_index + 1,
            day_seconds.getHoursIntoDay(),
            day_seconds.getMinutesIntoHour(),
            day_seconds.getSecondsIntoMinute(),
        },
    );
}

fn parseDate(date_str: []const u8) !i64 {
    // Expected format: YYYY-MM-DD
    var parts = std.mem.splitScalar(u8, date_str, '-');

    const year_str = parts.next() orelse return error.InvalidDate;
    const month_str = parts.next() orelse return error.InvalidDate;
    const day_str = parts.next() orelse return error.InvalidDate;

    const year = try std.fmt.parseInt(i32, year_str, 10);
    const month = try std.fmt.parseInt(i32, month_str, 10);
    const day = try std.fmt.parseInt(i32, day_str, 10);

    if (month < 1 or month > 12) return error.InvalidDate;
    if (day < 1 or day > 31) return error.InvalidDate;

    // Simple Unix timestamp calculation
    // Days since 1970-01-01
    const days_per_month = [12]i32{ 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 };

    var days: i64 = 0;

    // Years
    var y: i32 = 1970;
    while (y < year) : (y += 1) {
        if (isLeapYear(y)) {
            days += 366;
        } else {
            days += 365;
        }
    }

    // Months
    var m: i32 = 1;
    while (m < month) : (m += 1) {
        days += days_per_month[@intCast(m - 1)];
        if (m == 2 and isLeapYear(year)) {
            days += 1; // Leap year February
        }
    }

    // Days
    days += day - 1;

    return days * 86400; // Convert to seconds
}

fn isLeapYear(year: i32) bool {
    return (@rem(year, 4) == 0 and @rem(year, 100) != 0) or (@rem(year, 400) == 0);
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len != 4) {
        std.debug.print("Usage: {s} <num_rows> <start_date> <end_date>\n", .{args[0]});
        std.debug.print("Example: {s} 1000 2020-01-01 2024-12-31\n", .{args[0]});
        std.process.exit(1);
    }

    const num_rows = try std.fmt.parseInt(usize, args[1], 10);
    const start_timestamp = try parseDate(args[2]);
    const end_timestamp = try parseDate(args[3]);

    if (start_timestamp >= end_timestamp) {
        std.debug.print("Error: start_date must be before end_date\n", .{});
        std.process.exit(1);
    }

    const config = Config{
        .num_rows = num_rows,
        .start_timestamp = start_timestamp,
        .end_timestamp = end_timestamp,
    };

    try generateRandomData(allocator, config);
}
