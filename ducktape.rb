class Ducktape < Formula
  desc "AI-powered terminal tool for Apple Calendar, Reminders and Notes"
  homepage "https://github.com/ducktapeai/ducktape"
  
  # For local testing while the repository is private
  url "file:///tmp/ducktape-0.1.2.tar.gz"
  # Will use this URL when repository becomes public:
  # url "https://github.com/ducktapeai/ducktape/archive/refs/tags/v0.1.2.tar.gz"
  
  # Calculate the SHA for the local archive
  sha256 `shasum -a 256 /tmp/ducktape-0.1.2.tar.gz`.split.first
  license "MIT"
  
  # Repository is currently private - formula is for testing only
  
  depends_on "rust" => :build
  depends_on :macos

  def install
    # Following Ducktape Rust project standards for installation
    system "cargo", "install", "--locked", "--root", prefix, "--path", "."
    
    # Install documentation
    prefix.install "README.md"
    prefix.install "CHANGELOG.md" if File.exist?("CHANGELOG.md")
    
    # Install completion scripts if they exist
    bash_completion.install "completions/ducktape.bash" if File.exist?("completions/ducktape.bash")
    zsh_completion.install "completions/ducktape.zsh" if File.exist?("completions/ducktape.zsh")
    fish_completion.install "completions/ducktape.fish" if File.exist?("completions/ducktape.fish")
  end

  test do
    # Basic test to check if the binary is functional
    assert_match "DuckTape", shell_output("#{bin}/ducktape --help")
  end
end