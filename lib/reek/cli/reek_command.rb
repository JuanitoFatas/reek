require File.join(File.dirname(File.dirname(File.expand_path(__FILE__))), 'examiner')

module Reek
  module Cli

    #
    # A command to collect smells from a set of sources and write them out in
    # text report format.
    #
    class ReekCommand
      def self.create(sources, report_class, strategy = ActiveSmellsOnly)
        examiners = sources.map { |src| Examiner.new(src, strategy.new) }
        new(examiners, report_class)
      end

      def initialize(examiners, report_class)
        @examiners = examiners
        @report_class = report_class
      end

      def execute(view)
        had_smells = false
        @examiners.each do |examiner|
          rpt = @report_class.new(examiner)
          had_smells ||= examiner.smelly?
          view.output(rpt.report)
        end
        if had_smells
          view.report_smells
        else
          view.report_success
        end
      end
    end
  end
end
