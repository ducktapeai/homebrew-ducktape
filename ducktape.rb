class Ducktape < Formula
    desc "AI-powered terminal tool for Apple Calendar, Reminders and Notes"
    homepage "https://github.com/ducktapeai/ducktape"
    url "https://github.com/ducktapeai/ducktape/archive/refs/tags/v0.1.3.tar.gz"
    sha256 "4004f7246788ea1c1f404fee07349bbaa54d0e7ec21a4a343e7076470eb2a83b"
    license "MIT"
  
    depends_on "rust" => :build
    depends_on :macos
  
    def install
      system "cargo", "install", "--locked", "--root", prefix, "--path", "."
    end
  
    test do
      # Basic test to check if the binary is functional
      assert_match "DuckTape", shell_output("#{bin}/ducktape --help", 0)
    end
  end