module HasGlobalSession
  module Configuration
    mattr_accessor :config_file
    mattr_accessor :environment
    mattr_accessor :logger
    
    def self.[](key)
      get(key, true)
    end

    def self.validate
      ['attributes/signed', 'integrated', 'cookie/name', 'cookie/domain'].each do |path|
        elements = path.split '/'
        object = get(elements.shift, false)
        elements.each do |element|
          object = object[element]
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
         @config[environment].respond_to?(:has_key?) &&
         @config[environment].has_key?(key)
        return @config[environment][key]
      else
        @config['common'][key]
      end
    end
  end  
end