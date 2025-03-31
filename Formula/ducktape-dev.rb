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

  def   brew unlink ducktape-dev && brew link ducktapeinstall
    # Force a clean build to ensure proper versioning
    system "cargo", "clean"
    # Remove the --locked flag to allow Cargo to update the lock file if needed
    system "cargo", "build", "--release"
    bin.install "target/release/ducktape"
  end

  test do
    system "#{bin}/ducktape", "version"
  end
end