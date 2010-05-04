module HasGlobalSession
  module Configuration
    def self.[](key)
      return @config[RAILS_ENV][key] if @config
      @config ||= YAML.load(File.read(File.join(RAILS_ROOT, 'config', 'global_session.yml')))
      validate
      return @config[RAILS_ENV][key]
    end

    def self.validate
      #TODO
    end
  end  
end