class Wx < Formula
  desc "High-performance WebAssembly runtime written in Zig"
  homepage "https://github.com/clpi/wx"
  url "https://github.com/clpi/wx/archive/refs/tags/v0.0.0.tar.gz"
  sha256 ""
  license "MIT"
  head "https://github.com/clpi/wx.git", branch: "main"

  depends_on "zig" => :build

  def install
    system "zig", "build", "-Doptimize=ReleaseFast"
    bin.install "zig-out/bin/wx"
  end

  test do
    assert_match "wx", shell_output("#{bin}/wx --help")
  end
end
