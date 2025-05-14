export CC=emcc
export CFLAGS=-O3

export BIN=wx.wasm
export BINWAT=wx.wat
export OUT=src
export SRC=example

bz:
	zig build -freference-trace


cw:
	@rm -rf $(OUT)/$(BIN)
	@mkdir -p $(OUT)


bw: cw
	$(CC) -o $(OUT)/$(BIN) $(SRC)/main.c $(CFLAGS)

rw: bw
	wasmer $(OUT)/$(BIN)
	wasmtime $(OUT)/$(BIN)

r:
	./zig-out/bin/wx

b:
	zig build


wasm2wat: b
	echo "$(wasm2wat $(OUT)/$(BIN))" >> $(OUT)/$(BINWAT)



all: w

# .PHONY: c b r w
