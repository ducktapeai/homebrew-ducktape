class Ducktape < Formula
  desc "AI-powered terminal tool for Apple Calendar, Reminders and Notes"
  homepage "https://github.com/DuckTapeAI/ducktape"
  version "0.1.5"
  url "https://github.com/DuckTapeAI/ducktape/archive/refs/tags/v#{version}.tar.gz"
  sha256 "3af5b639e074c7475bc5f2bf471f99a4e157d2b33a85bd729046f617662c7e28"
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