class Wx < Formula
  desc "WebAssembly runtime written in Zig with basic WASI support"
  homepage "https://github.com/clpi/wx"
  version "0.1.0"
  license "MIT"

  if OS.mac? && Hardware::CPU.intel?
    url "https://github.com/clpi/wx/releases/download/v0.1.0/wx-macos-x86_64"
    sha256 "SKIP"  # Will be updated by release workflow
  elsif OS.mac? && Hardware::CPU.arm?
    url "https://github.com/clpi/wx/releases/download/v0.1.0/wx-macos-aarch64"
    sha256 "SKIP"  # Will be updated by release workflow
  elsif OS.linux?
    url "https://github.com/clpi/wx/releases/download/v0.1.0/wx-linux-x86_64"
    sha256 "SKIP"  # Will be updated by release workflow
  end

  def install
    bin.install Dir["*"].first => "wx"
  end

  test do
    system "#{bin}/wx", "--version"
  end
end
