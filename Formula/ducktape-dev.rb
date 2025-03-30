class DucktapeDev < Formula
  desc "AI-powered terminal tool for Apple Calendar, Reminders and Notes (Development Version)"
  homepage "https://github.com/DuckTapeAI/ducktape"
  version "0.1.5"
  license "MIT"
  
  # For private development use, we use the head approach pointing to local repository
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