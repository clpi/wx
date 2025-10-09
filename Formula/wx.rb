class Wx < Formula
  desc "High-performance WebAssembly runtime written in Zig"
  homepage "https://github.com/clpi/wx"
  url "https://github.com/clpi/wx/archive/refs/tags/0.1.0.tar.gz"
  sha256 "d5558cd419c8d46bdc958064cb97f963d1ea793866414c025906ec15033512ed"
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
