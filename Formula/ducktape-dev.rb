class DucktapeDev < Formula
  desc "AI-powered terminal tool for Apple Calendar, Reminders and Notes (Development Version)"
  homepage "https://github.com/DuckTapeAI/ducktape"
  version "0.1.5"
  license "MIT"
  
  # For private development, we use a direct path to the repository
  head do
    url "file:///Users/shaunstuart/RustroverProjects/ducktape"
  end
  
  # Also provide a standard URL as required by Homebrew
  url "file:///Users/shaunstuart/RustroverProjects/ducktape", :using => :git
  
  depends_on "rust" => :build

  def install
    # Force a clean build to ensure proper versioning
    system "cargo", "clean"
    system "cargo", "build", "--release", "--locked"
    bin.install "target/release/ducktape"
  end

  test do
    system "#{bin}/ducktape", "version"
  end
end