require 'active_support/core_ext/object/blank'
require 'active_support/core_ext/string/filters'
require 'rugged'
require 'rubocop'
require 'securerandom'
require 'pry'
require 'slack-notifier'
require 'platform-api'

require_relative 'patch'
require_relative 'logger'

module Ballercop
  class Autofix
    MAX_RUNS = 2

    def initialize(silent: false, path: nil)
      @path = path.presence || '.'
      @logger = Logger.new unless silent.present?
    end

    def ci_check
      ensure_working_dir
      
      @heroku = PlatformAPI.connect_oauth(ENV['PLATFORM_API_TOKEN'])
      env_vars = []
      patches = ci_get_patches
      patches.each do |patch|
        @logger&.log "Inspecting #{patch.file_path}", :info
        env_vars.concat(get_added_env_var(patch))
      end

      env_vars.uniq.map { |env_var| check_and_notify(env_var)}

      exit(0)
    rescue StandardError => e
      @logger&.log "#{e.message}, #{e.backtrace}", :error
      exit(1)
    end

    def run(unstaged: false, staged: false, base: nil, target_files: nil)
      ensure_working_dir

      runs = 1
      keep_running = true
      rerun_files = []
      all_patches = {}

      until runs > MAX_RUNS || !keep_running
        @logger&.log "\n———————— Second attempt ————————\n\n", :info if runs != 1
        
        patches = get_patches(unstaged, staged, base, runs == 1 ? target_files : rerun_files)
        keep_running = false
        runs += 1

        patches.each do |patch|
          @logger&.log "Inspecting #{patch.file_path}", :info
          all_patches[patch.file_path] = patch
          patch.fix
          if patch.fixes_applied # In some cases when fixes are applied, the fixes break new rule(s) so rerun
            keep_running = true
            rerun_files.append(patch.file_path)
          end
        end
      end

      log_result(all_patches.values)

      exit(0)
    rescue StandardError => e
      @logger&.log "#{e.message}, #{e.backtrace}", :error
      exit(1)
    end
    
    private

    def get_added_env_var(patch)
      patch.offenses
           .select {|offence| offence.cop_name.present? && offence.cop_name == 'CustomCops/EnvVarAccess'}
           .map {|offence| offence.highlighted_area.source.gsub(/[\[\]"']/, '[': '', ']': '', '"': '', '\'': '')}
    end

    def check_and_notify(env_var)
      apps_missing_in = []
      
      apps_missing_in.append('baller') if baller_env[env_var].blank?
      apps_missing_in.append('ballersupport') if baller_support_env[env_var].blank?
      apps_missing_in.append('ballertestflight') if baller_testflight_env[env_var].blank?
      apps_missing_in.append('ballerstreaming') if baller_streaming_env[env_var].blank?
      
      notify(env_var, apps_missing_in) if apps_missing_in.present?
    end

    def notify(env_var, apps)
      return unless ENV['BALLERCOP_SLACK_WEBHOOK_URL']
      notifier = Slack::Notifier.new ENV['BALLERCOP_SLACK_WEBHOOK_URL'], channel: '#eng-env-var-added', name: 'Ballercop'
      notifier.ping "🚨 #{env_var} merged to TF and missing in #{apps.join(', ')}\n<@U08DA5T9C> <@U0K2SLU1J> <@UN5QVTASJ>"
    end

    def baller_support_env
      @baller_support_env ||= @heroku.config_var.info_for_app('ballersupport')
    end
    
    def baller_testflight_env
      @baller_testflight_env ||= @heroku.config_var.info_for_app('ballertestflight')
    end
    
    def baller_env
      @baller_env ||= @heroku.config_var.info_for_app('baller')
    end
    
    def baller_streaming_env
      @baller_streaming_env ||= @heroku.config_var.info_for_app('ballerstreaming')
    end

    def ci_get_patches
      repo = Rugged::Repository.new(@path)
      head = repo.head.target

      added_files = []
      
      # Note: this flips lines added & deleted.
      # Lines added show up in patch as line deleted which affects Patch#patch_added_lines
      head.tree.diff(head.parents.first).map do |patch|
        file_path = patch.delta.new_file[:path]
        next if added_files.include?(file_path)
        next unless ruby_file?(corrected_file_path(file_path))

        added_files.append(file_path)
        Patch.new(patch, file_path, corrected_file_path(file_path), true)
      end.compact
    end

    def get_patches(unstaged, staged, base, target_files)
      repo = Rugged::Repository.new(@path)
      head = repo.head.target

      patches = []

      if !unstaged && !staged
        merge_base = repo.merge_base(base || 'origin/testflight', head)
        repo.diff(merge_base, head, nil).each {|p| patches.append(p) }
      end

      if unstaged || staged || target_files.present?
        head.diff(repo.index).each { |p| patches.append(p) } if staged || target_files.present?
        repo.index.diff.each { |p| patches.append(p) } if unstaged || target_files.present?
      end
      
      added_files = []
      patches.map do |patch|
        file_path = patch.delta.new_file[:path]
        next if added_files.include?(file_path)
        next unless ruby_file?(corrected_file_path(file_path))
        next if target_files.present? && !target_files.include?(file_path)

        added_files.append(file_path)
        Patch.new(patch, file_path, corrected_file_path(file_path))
      end.compact
    end
    
    def ruby_file?(path)
      rb_file?(path) ||
        rake_file?(path) ||
        gem_file?(path) ||
        ruby_executable?(path)
    end

    def rb_file?(path)
      File.extname(path) == '.rb'
    end

    def rake_file?(path)
      File.extname(path) == '.rake'
    end

    def gem_file?(path)
      File.basename(path) == 'Gemfile' || File.extname(path) == '.gemspec'
    end

    def ruby_executable?(path)
      return false if File.directory?(path)
      line = File.open(path, &:readline)
      line =~ /#!.*ruby/
    rescue ArgumentError, EOFError
      false
    end

    def ensure_working_dir
      wd = Dir.pwd.split('/').last
      return unless wd == 'ballercop'
      return unless @path.blank?
      raise StandardError.new("ERROR -- Must run outside of gem. Try --path=[path_to_repo]")
    end
    
    def corrected_file_path(path)
      return @path.end_with?('/') ? @path + path : @path + '/' + path if @path
      path
    end

    def log_result(patches)
      return unless patches.present?

      logger = @logger || Logger.new(:error)
      logger&.log "\nResult:", :info
      patches.each { |patch| patch.result_log(logger) }
    end
  end
end
