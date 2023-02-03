# Zig Preopen Playground

## Testing

    zig test -target wasm32-wasi preopens.zig \
        --test-cmd wazero --test-cmd run --test-cmd \
        -mount=root/1/001:/ --test-cmd -mount=root/1/002:/tmp \
        --test-cmd-bin
