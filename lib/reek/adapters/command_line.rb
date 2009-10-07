require 'optparse'
require 'reek'
require 'reek/adapters/report'

module Reek
    
  # SMELL: Greedy Module
  # This creates the command-line parser AND invokes it. And for the
  # -v and -h options it also executes them. And it holds the config
  # options for the rest of the application.
  class Options

    CTX_SORT = '%m%c %w (%s)'
    SMELL_SORT = '%m[%s] %c %w'

    def initialize(argv)
      @argv = argv
      @parser = OptionParser.new
      @quiet = false
      @show_all = false
      @format = CTX_SORT
      set_options
    end

    def parse
      @parser.parse!(@argv)
      @argv
    end

    def set_options
      @parser.banner = <<EOB
Usage: #{@parser.program_name} [options] [files]

Examples:

#{@parser.program_name} lib/*.rb
#{@parser.program_name} -q -a lib
cat my_class.rb | #{@parser.program_name}

See http://wiki.github.com/kevinrutherford/reek for detailed help.

EOB

      @parser.separator "Common options:"

      @parser.on("-h", "--help", "Show this message") do
        puts @parser
        exit(EXIT_STATUS[:success])
      end
      @parser.on("-v", "--version", "Show version") do
        puts "#{@parser.program_name} #{Reek::VERSION}"
        exit(EXIT_STATUS[:success])
      end

      @parser.separator "\nReport formatting:"

      @parser.on("-a", "--[no-]show-all", "Show all smells, including those masked by config settings") do |opt|
        @show_all = opt
      end
      @parser.on("-q", "--quiet", "Suppress headings for smell-free source files") do
        @quiet = true
      end
      @parser.on('-f', "--format FORMAT", 'Specify the format of smell warnings') do |arg|
        @format = arg unless arg.nil?
      end
      @parser.on('-c', '--context-first', "Sort by context; sets the format string to \"#{CTX_SORT}\"") do
        @format = CTX_SORT
      end
      @parser.on('-s', '--smell-first', "Sort by smell; sets the format string to \"#{SMELL_SORT}\"") do
        @format = SMELL_SORT
      end
    end

    def create_report(sniffers)
      @quiet ? QuietReport.new(sniffers, @format, @show_all) : FullReport.new(sniffers, @format, @show_all)
    end
  end
end
