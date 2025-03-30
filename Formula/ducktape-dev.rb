class DucktapeDev < Formula
  desc "AI-powered terminal tool for Apple Calendar, Reminders and Notes (Development Version)"
  homepage "https://github.com/DuckTapeAI/ducktape"
  version "0.1.5"
  license "MIT"
  
  # For private development, we use the head approach pointing to local repository
  head do
    url "file:///Users/shaunstuart/RustroverProjects/ducktape"
  end
  
  # Provide a URL that points to your local repository
  # This is required by Homebrew even though we're building from local path
  url "file:///Users/shaunstuart/RustroverProjects/ducktape"
  sha256 "3af5b639e074c7475bc5f2bf471f99a4e157d2b33a85bd729046f617662c7e28"

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