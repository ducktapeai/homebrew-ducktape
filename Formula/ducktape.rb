class Ducktape < Formula
  desc "AI-powered terminal tool for Apple Calendar, Reminders and Notes"
  homepage "https://github.com/ducktapeai/ducktape"
  url "https://github.com/ducktapeai/ducktape/archive/refs/tags/v0.11.18.tar.gz"
  version "0.11.18"
  sha256 "6b04392f34413fdd96ac3ac9736361d830e4119861efcbbf15019b07f8b9526e"
  license "MIT"

  depends_on "rust" => :build

  def install
    system "cargo", "install", "--root", prefix, "--path", "."
    
    # Generate shell completions with error handling
    begin
      # Create an empty .env file to prevent the completions command from failing
      touch_path = File.join(buildpath, ".env")
      FileUtils.touch(touch_path) unless File.exist?(touch_path)
      
      output = Utils.safe_popen_read(bin/"ducktape", "completions")
      
      # Only write completions if output was successfully generated
      unless output.empty? || output.start_with?("Warning:")
        (bash_completion/"ducktape").write output
        (zsh_completion/"_ducktape").write output
        (fish_completion/"ducktape.fish").write output
      end
    rescue => e
      opoo "Shell completion generation failed: #{e.message}"
    end
    
    man1.install "man/ducktape.1" if File.exist?("man/ducktape.1")
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/ducktape --version")
    system "#{bin}/ducktape", "calendar", "list"
  end
end
