class Ducktape < Formula
  desc "AI-powered terminal tool for Apple Calendar, Reminders and Notes"
  homepage "https://github.com/ducktapeai/ducktape"
  version "0.1.9"
  url "https://github.com/ducktapeai/ducktape/archive/refs/tags/v#{version}.tar.gz"
  sha256 "12194d3e475d14a84a327dd4383a2a27ffe0870ac6c756ebd14138152f3779e3"
  license "MIT"
  
  depends_on "rust" => :build

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