require 'pry'

module Ballercop
  class Patch
    def initialize(patch, file_path, logger)
      @patch = patch
      @file_path = file_path
      @logger = logger || Logger.new(true)
    end
    
    def fix
      offense = fixable_offenses.last

      while offense.present?
        File.write(@file_path, offense.corrector.rewrite)
        offense = fixable_offenses.last
      end

      unfixable_offenses.each do |each_offense|
        @logger.log "Can not fix #{each_offense.message} at line #{each_offense.line}"
      end
    end
    
    def offensive?
      offenses.any?
    end
    
    private

    def rubocop_registry
      @rubocop_registry ||= RuboCop::Cop::Registry.new(RuboCop::Cop::Cop.all) #TODO: grab cops from .rubocop
    end

    def rubocop_team(config)
      @rubocop_team ||= RuboCop::Cop::Team.new(rubocop_registry, config)
    end

    def rubocop_report
      config = RuboCop::ConfigStore.new.for(@file_path)
      processed_source = RuboCop::ProcessedSource.from_file(@file_path, config.target_ruby_version)
      rubocop_team(config).investigate(processed_source)
    end

    def offenses
      added_lines = patch_added_lines(@patch)
      report = rubocop_report
      report.offenses.sort
            .reject(&:disabled?)
            .select {|offense| added_lines.include?(offense.line) }
    end

    def fixable_offenses
      offenses.reject {|offense| offense.corrector == nil || offense.status == :unsupported}
    end

    def unfixable_offenses
      offenses.select {|offense| offense.corrector == nil || offense.status == :unsupported}
    end

    def patch_added_lines(patch)
      added_lines = []
      patch.each_hunk do |hunk|
        added_lines.concat(hunk.lines.select(&:addition?).map(&:new_lineno))
      end
      added_lines
    end
  end
end