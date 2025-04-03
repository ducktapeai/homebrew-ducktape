class Ducktape < Formula
  desc "AI-powered terminal tool for Apple Calendar, Reminders and Notes"
  homepage "https://github.com/ducktapeai/ducktape"
  version "0.1.8"
  url "https://github.com/ducktapeai/ducktape/archive/refs/tags/v#{version}.tar.gz"
  sha256 "624169244f678860a80cee0135a3100f18e736d3280b1da6c54d4fe6261c48ea"
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