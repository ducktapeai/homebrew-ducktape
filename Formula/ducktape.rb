class Ducktape < Formula
  desc "AI-powered terminal tool for Apple Calendar, Reminders and Notes"
  homepage "https://github.com/DuckTapeAI/ducktape"
  version "0.1.4"
  url "https://github.com/DuckTapeAI/ducktape/archive/v#{version}.tar.gz"
  sha256 "6bcf3caa5867c4cdbed950773672653783c3fee63c68c51ccaa18d86c52469fd"
  license "MIT"
  
  # For local development
  head do
    url "file:///Users/shaunstuart/RustroverProjects/ducktape"
  end

  depends_on "rust" => :build

  def install
    system "cargo", "build", "--release", "--locked"
    bin.install "target/release/ducktape"
  end

  test do
    system "#{bin}/ducktape", "version"
  end
end