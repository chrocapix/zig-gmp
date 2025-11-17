const std = @import("std");
const gmp = @cImport(@cInclude("gmp.h"));

pub fn main() !void {
    var x : gmp.mpz_t = undefined;
    gmp.mpz_init(&x);
    gmp.mpz_set_ui(&x, 42);
    _ = gmp.gmp_printf("x = %Zd\n", &x);
}
