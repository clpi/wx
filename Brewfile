cask "wx" do
  version "0.1.0"
  
  if Hardware::CPU.intel?
    sha256 "SKIP"  # Will be updated by release workflow
    url "https://github.com/clpi/wx/releases/download/v#{version}/wx-macos-x86_64"
  else
    sha256 "SKIP"  # Will be updated by release workflow
    url "https://github.com/clpi/wx/releases/download/v#{version}/wx-macos-aarch64"
  end

  name "wx"
  desc "WebAssembly runtime written in Zig with basic WASI support"
  homepage "https://github.com/clpi/wx"

  binary "wx-macos-#{Hardware::CPU.arch}", target: "wx"

  livecheck do
    url :url
    strategy :github_latest
  end
end

# vim: set ft=ruby:
