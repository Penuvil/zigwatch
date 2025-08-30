default:
    zig build -Doptimize=Debug

watch:
    ./scripts/zbw

test:
    zig build test -Doptimize=Debug

fmt:
    zig fmt .

debug:
    ./scripts/zdbg

run:
    zig build run -Doptimize=Debug
