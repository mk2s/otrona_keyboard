const std = @import("std");
const microzig = @import("microzig");

const rp2040 = microzig.hal;
const time = rp2040.time;
const gpio = rp2040.gpio;
const clocks = rp2040.clocks;

const led = gpio.num(25);
const uart = rp2040.uart.num(0);
const baud_rate = 115200;
const uart_tx_pin = gpio.num(0);
const uart_rx_pin = gpio.num(1);

const kb_out = gpio.num(22);
const kb_clk_in = gpio.num(9);

const button = gpio.num(6);

pub fn panic(message: []const u8, _: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    std.log.err("panic: {s}", .{message});
    @breakpoint();
    while (true) {}
}

pub const microzig_options = .{
    .log_level = .debug,
    .logFn = rp2040.uart.log,
};

// pull output to high to signal keyboard input, sometime later(in the order of 13ms)
// the first pulse(5.4us) will arrive and we transition the output to the LSB.  Then
// the clock will arrive 18us later, and we advance toward msb.  This repeates 8 times
// and after that upon the next pulse we output low to signal done.
fn send_byte(b: u8) void {
    // output high
    kb_out.put(1);

    var significantbit: u8 = 1;
    for(0..8) |i| {
        _ = i;
        // wait for clock to go low
        while (kb_clk_in.read() == 1) {
            //time.sleep_us(2);
        }
        // ouput bit - active low
        if (b & significantbit > 0) {
            kb_out.put(0);
        } else {
            kb_out.put(1);
        }
        
        // wait 5.4us to make sure we pass the pulse
        time.sleep_us(5);
        significantbit = significantbit << 1;
    }
    // wait for last pulse
    while (kb_clk_in.read() == 1) {
        //time.sleep_us(2);
    }
    // output high
    kb_out.put(0);
}

pub fn main() !void {
    led.set_function(.sio);
    led.set_direction(.out);

    button.set_direction(.in);
    button.set_pull(.up);

    kb_out.set_function(.sio);
    kb_out.set_direction(.out);
    // high is the idle state
    kb_out.put(1);

    kb_clk_in.set_direction(.in);
    kb_clk_in.set_pull(.up);

    led.put(1);

    uart.apply(.{
        .baud_rate = baud_rate,
        .tx_pin = uart_tx_pin,
        .rx_pin = uart_rx_pin,
        .clock_config = rp2040.clock_config,
    });

    rp2040.uart.init_logger(uart);

    led.put(0);
    while (true) {
        // wait until button press
        while (button.read() == 1) {
            time.sleep_ms(1);
        }

        led.put(1);

        send_byte(0x24);  // D
        time.sleep_ms(1000);
        send_byte(0x29);  // I
        time.sleep_ms(1000);
        send_byte(0x32);  // R
        time.sleep_ms(1000);
        send_byte(0x05);  // <cr>

        led.put(0);
    }


    // var i: u32 = 0;
    // while (true) : (i += 1) {
    //     led.put(1);
    //     std.log.info("what {}", .{ button.read() });
    //     time.sleep_ms(500);

    //     led.put(0);
    //     time.sleep_ms(500);
    // }


}
