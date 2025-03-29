class Ducktape < Formula
  desc "AI-powered terminal tool for Apple Calendar, Reminders and Notes"
  homepage "https://github.com/DuckTapeAI/ducktape"
  version "0.1.4"
  url "https://github.com/DuckTapeAI/ducktape/archive/v#{version}.tar.gz"
  sha256 "0019dfc4b32d63c1392aa264aed2253c1e0c2fb09216f8e2cc269bbfb8bb49b5"
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