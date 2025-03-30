class Ducktape < Formula
    desc "AI-powered terminal tool for Apple Calendar, Reminders and Notes"
    homepage "https://github.com/ducktapeai/ducktape"
    url "https://github.com/ducktapeai/ducktape/archive/refs/tags/v0.1.5.tar.gz"
    sha256 "3af5b639e074c7475bc5f2bf471f99a4e157d2b33a85bd729046f617662c7e28"
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