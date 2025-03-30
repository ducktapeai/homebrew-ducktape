class DucktapeDev < Formula
  desc "AI-powered terminal tool for Apple Calendar, Reminders and Notes (Development Version)"
  homepage "https://github.com/DuckTapeAI/ducktape"
  version "0.1.5"
  license "MIT"
  
  # For private development, use a direct path to the repository
  # Specify main branch explicitly
  url "file:///Users/shaunstuart/RustroverProjects/ducktape", 
      :using => :git, 
      :branch => "main"
  
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