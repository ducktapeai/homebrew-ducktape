class Ducktape < Formula
  desc "AI-powered terminal tool for Apple Calendar, Reminders and Notes"
  homepage "https://github.com/DuckTapeAI/ducktape"
  version "0.1.7"
  url "https://github.com/DuckTapeAI/ducktape/archive/refs/tags/v#{version}.tar.gz"
  sha256 "0019dfc4b32d63c1392aa264aed2253c1e0c2fb09216f8e2cc269bbfb8bb49b5" 
  license "MIT"
  
  depends_on "rust" => :build
  
  # Additional dependencies can be added here as needed
  # depends_on "openssl"

  def install
    # Build with release optimizations
    system "cargo", "build", "--release"
    
    # Install the binary
    bin.install "target/release/ducktape"
    
    # Install bash completion if it exists
    bash_completion.install "completions/ducktape.bash" if File.exist?("completions/ducktape.bash")
    
    # Install zsh completion if it exists
    zsh_completion.install "completions/_ducktape" if File.exist?("completions/_ducktape")
    
    # Install fish completion if it exists
    fish_completion.install "completions/ducktape.fish" if File.exist?("completions/ducktape.fish")
    
    # Install man page if it exists
    man1.install "man/ducktape.1" if File.exist?("man/ducktape.1")
  end

  test do
    # Verify the installation by checking version output
    assert_match /\d+\.\d+\.\d+/, shell_output("#{bin}/ducktape --version")
  end
end