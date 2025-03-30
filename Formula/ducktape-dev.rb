class DucktapeDev < Formula
  desc "AI-powered terminal tool for Apple Calendar, Reminders and Notes (Development Version)"
  homepage "https://github.com/DuckTapeAI/ducktape"
  version "0.1.5"
  license "MIT"
  
  # For private development, we only use the head approach
  head do
    url "file:///Users/shaunstuart/RustroverProjects/ducktape"
  end

  depends_on "rust" => :build

  def install
    # Build directly from the local repository path
    cd "/Users/shaunstuart/RustroverProjects/ducktape" do
      system "cargo", "build", "--release", "--locked"
      bin.install "target/release/ducktape"
    end
  end

  test do
    system "#{bin}/ducktape", "version"
  end
end