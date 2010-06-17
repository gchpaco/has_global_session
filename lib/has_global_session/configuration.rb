module HasGlobalSession
  module Configuration
    def self.environment; @environment; end
    def self.environment=(value); @environment = value; end

    def self.config_file; @config_file; end
    def self.config_file=(value); @config_file= value; end

    def self.[](key)
      get(key, true)
    end

    def self.validate
      ['attributes/signed', 'integrated', 'cookie/name', 'cookie/domain', 'timeout'].each do |path|
        elements = path.split '/'
        object = get(elements.shift, false)
        elements.each do |element|
          object = object[element] if object
          if object.nil?
            msg = "#{File.basename(config_file)} does not specify required element #{elements.map { |x| "['#{x}']"}.join('')}"
            raise MissingConfiguration, msg
          end
        end
      end
    end

    private
    def self.get(key, validated)
      unless @config
        raise MissingConfiguration, "config_file is nil; cannot read configuration" unless config_file
        raise MissingConfiguration, "environment is nil; must be specified" unless environment
        @config = YAML.load(File.read(config_file))
        raise TypeError, "#{config_file} must contain a Hash!" unless Hash === @config
        validate if validated
      end
      if @config.has_key?(environment) &&
         @config[environment].has_key?(key)
        return @config[environment][key]
      else
        @config['common'][key]
      end
    rescue NoMethodError
      raise MissingConfiguration, "Configuration key '#{key}' not found"
    end
  end  
end