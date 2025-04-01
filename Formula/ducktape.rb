class Ducktape < Formula
  desc "AI-powered terminal tool for Apple Calendar, Reminders and Notes"
  homepage "https://github.com/DuckTapeAI/ducktape"
  version "0.1.6"
  url "https://github.com/DuckTapeAI/ducktape/archive/refs/tags/v#{version}.tar.gz"
  sha256 "13a84536cc215e7bf096b6d2ba3197bcc64e378085d1bf73c451be3bcd199f0e"
  license "MIT"
  
  depends_on "rust" => :build

  def install
    system "cargo", "build", "--release"
    bin.install "target/release/ducktape"
  end

  test do
    system "#{bin}/ducktape", "--version"
  end
end