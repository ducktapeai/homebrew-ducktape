class Ducktape < Formula
  desc "AI-powered terminal tool for Apple Calendar, Reminders and Notes"
  homepage "https://github.com/DuckTapeAI/ducktape"
  version "0.1.5"
  url "https://github.com/DuckTapeAI/ducktape/archive/refs/tags/v#{version}.tar.gz"
  sha256 "3af5b639e074c7475bc5f2bf471f99a4e157d2b33a85bd729046f617662c7e28"
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